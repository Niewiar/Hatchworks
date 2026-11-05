class_name MapOverlayController
extends MeshInstance3D

enum VIEW { NORMAL, NOISE, REGIONS }

signal view_changed(view: VIEW)
signal regions_updated
signal noise_updated

const OVERLAY_SHADER = preload("res://code/map/map_overlay.gdshader")

var view: VIEW = VIEW.NORMAL
var sources: Array[Dictionary] = []
var region_points: Dictionary[int,Vector3] = {}
var _map: MapManager
var _material: ShaderMaterial
var _region_texture: ImageTexture
var _noise_texture: ImageTexture
var _noise_image: Image
var _noise_size := Vector2i.ZERO
var _noise_extent := Vector2.ZERO
var _noise_points := PackedVector3Array()
var _noise_levels := PackedFloat32Array()
var _noise_dirty_bounds := Rect2()
var _region_origins: Dictionary[int,Vector3] = {}
var _regions_dirty := true
var _anchors_dirty := true
var _points_dirty := true
var _height_area_pending := false
var _highlighted_region := 0
var _elapsed := 0.0

func initialize(map: MapManager) -> void:
	_map = map
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = OVERLAY_SHADER
	_material.render_priority = 3
	material_override = _material
	_material.set_shader_parameter("world_size",map.terrain_controller.world_size)
	_noise_size = Vector2i((map.terrain_controller.world_size/0.5).ceil())
	_noise_extent = map.terrain_controller.world_size/Vector2(_noise_size)
	_noise_levels.resize(_noise_size.x*_noise_size.y)
	map.regions_controller.regions_changed.connect(_regions_changed)
	map.terrain_controller.height_area_changed.connect(_height_area_changed)
	map.terrain_controller.height_changed.connect(_surface_changed)
	map.water_controller.water_level_changed.connect(_water_changed)
	map.modal_changed.connect(_modal_changed)
	_surface_changed()
	_water_changed()
	_modal_changed(map.modal_active)
	set_process(false)

func set_view(value: VIEW) -> void:
	if value == view:
		return
	view = value
	_material.set_shader_parameter("view_mode",view)
	highlight_region(0)
	_elapsed = 0.15
	_modal_changed(_map.modal_active)
	if view == VIEW.REGIONS:
		_refresh_regions()
	elif view == VIEW.NOISE:
		_refresh_noise()
	view_changed.emit(view)

func highlight_region(id: int) -> void:
	if id == _highlighted_region:
		return
	_highlighted_region = id
	_material.set_shader_parameter("highlighted_region",id)

static func region_color(id: int) -> Color:
	return Color.from_hsv(fposmod(id*0.61803398875,1.0),0.53,0.92)

func _modal_changed(active: bool) -> void:
	visible = view != VIEW.NORMAL and not active
	set_process(visible)

func _regions_changed() -> void:
	_regions_dirty = true

func _surface_changed() -> void:
	mesh = _map.terrain_controller.mesh
	transform = _map.terrain_controller.transform
	if _height_area_pending:
		_height_area_pending = false
	else:
		_points_dirty = true
	_anchors_dirty = true
	extra_cull_margin = maxf(0.1,_map.water_controller.water_level-mesh.get_aabb().position.y)

func _height_area_changed(bounds: Rect2) -> void:
	_height_area_pending = true
	if not bounds.has_area():
		_points_dirty = true
		return
	_noise_dirty_bounds = _noise_dirty_bounds.merge(bounds) if _noise_dirty_bounds.has_area() else bounds

func _water_changed() -> void:
	_anchors_dirty = true
	extra_cull_margin = maxf(0.1,_map.water_controller.water_level-mesh.get_aabb().position.y)
	_material.set_shader_parameter("water_level",_map.terrain_controller.to_local(_map.water_controller.global_position).y)
	_points_dirty = true

func _process(delta: float) -> void:
	_elapsed -= delta
	if view == VIEW.REGIONS and _regions_dirty:
		_refresh_regions()
	elif view == VIEW.REGIONS and _anchors_dirty:
		_refresh_anchors()
	if _elapsed > 0.0:
		return
	_elapsed = 0.15
	if view == VIEW.NOISE:
		_refresh_noise()

func _refresh_regions() -> void:
	if not _regions_dirty:
		if _anchors_dirty:
			_refresh_anchors()
		return
	var layout := _map.regions_controller.layout_snapshot()
	if not layout.ready:
		return
	var dimensions: Vector2i = layout.size
	var ids: PackedInt32Array = layout.ids
	var bytes := PackedByteArray()
	bytes.resize(ids.size()*4)
	var extent := _map.terrain_controller.world_size/Vector2(dimensions)
	var half := _map.terrain_controller.world_size*0.5
	var centers: Dictionary[int,Vector2] = {}
	var nearest: Dictionary[int,float] = {}
	var closest: Dictionary[int,int] = {}
	for region: Region in layout.regions:
		var center := _map.terrain_controller.to_local(region.center)
		centers[region.id] = (Vector2(center.x,center.z)+half)/extent-Vector2(0.5,0.5)
		nearest[region.id] = INF
	for index in ids.size():
		var id := maxi(0,ids[index])
		bytes[index*4] = id%256
		bytes[index*4+1] = (id/256)%256
		bytes[index*4+2] = id/65536
		bytes[index*4+3] = 255
		if id <= 0:
			continue
		var cell := Vector2(index%dimensions.x,index/dimensions.x)
		var distance := cell.distance_squared_to(centers[id])
		if distance < nearest[id]:
			nearest[id] = distance
			closest[id] = index
	var image := Image.create_from_data(dimensions.x,dimensions.y,false,Image.FORMAT_RGBA8,bytes)
	if _region_texture == null:
		_region_texture = ImageTexture.create_from_image(image)
		_material.set_shader_parameter("region_map",_region_texture)
	else:
		_region_texture.update(image)
	region_points.clear()
	_region_origins.clear()
	for id: int in closest:
		var index := closest[id]
		var local := (Vector2(index%dimensions.x,index/dimensions.x)+Vector2(0.5,0.5))*extent-half
		_region_origins[id] = Vector3(local.x,0,local.y)
	_regions_dirty = false
	_refresh_anchors()

func _refresh_anchors() -> void:
	for id: int in _region_origins:
		var point := _map.terrain_controller.surface_position(_map.terrain_controller.to_global(_region_origins[id]))
		point.y = maxf(point.y,_map.water_controller.global_position.y)+0.12
		region_points[id] = point
	_anchors_dirty = false
	regions_updated.emit()

func _refresh_noise_points() -> void:
	var initialized := _noise_points.size() == _noise_size.x*_noise_size.y
	var bounds := Rect2i(Vector2i.ZERO,_noise_size)
	var half := _map.terrain_controller.world_size*0.5
	if initialized and not _points_dirty:
		if not _noise_dirty_bounds.has_area():
			return
		var padding := Vector2i((Vector2.ONE*_map.terrain_controller.height_spacing/_noise_extent).ceil()).max(Vector2i.ONE)
		var first := (Vector2i(((_noise_dirty_bounds.position+half)/_noise_extent).floor())-padding).max(Vector2i.ZERO)
		var last := (Vector2i(((_noise_dirty_bounds.end+half)/_noise_extent).ceil())+padding).min(_noise_size)
		bounds = Rect2i(first,(last-first).max(Vector2i.ZERO))
	if not initialized:
		_noise_points.resize(_noise_size.x*_noise_size.y)
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var local := (Vector2(x,y)+Vector2(0.5,0.5))*_noise_extent-half
			var point := _map.terrain_controller.surface_position(_map.terrain_controller.to_global(Vector3(local.x,0,local.y)))
			point.y = maxf(point.y,_map.water_controller.global_position.y)
			_noise_points[y*_noise_size.x+x] = point
	_points_dirty = false
	_noise_dirty_bounds = Rect2()

func _refresh_noise() -> void:
	var next_sources := _map.noise.active_sources()
	if next_sources == sources and _noise_texture != null and (sources.is_empty() or (not _points_dirty and not _noise_dirty_bounds.has_area())):
		return
	sources = next_sources
	_noise_levels.fill(0.0)
	if not sources.is_empty() and (_points_dirty or _noise_dirty_bounds.has_area()):
		_refresh_noise_points()
	for data: Dictionary in sources:
		var origin := _map.terrain_controller.to_local(data.point)
		var center := (Vector2(origin.x,origin.z)+_map.terrain_controller.world_size*0.5)/_noise_extent-Vector2(0.5,0.5)
		var radius := Vector2.ONE*float(data.radius)/_noise_extent
		var first := Vector2i((center-radius).floor()).max(Vector2i.ZERO)
		var last := Vector2i((center+radius).ceil()).min(_noise_size-Vector2i.ONE)
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var index := y*_noise_size.x+x
				var weight := clampf(1.0-_noise_points[index].distance_to(data.point)/float(data.radius),0.0,1.0)
				_noise_levels[index] += float(data.strength)*weight*weight
	var bytes := _noise_levels.to_byte_array()
	if _noise_image == null:
		_noise_image = Image.create_from_data(_noise_size.x,_noise_size.y,false,Image.FORMAT_RF,bytes)
	else:
		_noise_image.set_data(_noise_size.x,_noise_size.y,false,Image.FORMAT_RF,bytes)
	if _noise_texture == null:
		_noise_texture = ImageTexture.create_from_image(_noise_image)
		_material.set_shader_parameter("noise_map",_noise_texture)
	else:
		_noise_texture.update(_noise_image)
	noise_updated.emit()
