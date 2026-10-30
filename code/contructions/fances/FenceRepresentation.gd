extends MeshInstance3D

var state: FenceSpanState
var data: FanceData
var start_point := Vector2.ZERO
var end_point := Vector2.ZERO
var preview_mode := false
var _pixels_per_unit := 32.0
var _geometry_key := 0
var _body: StaticBody3D
var _shape: CollisionShape3D
var _terrain: TerrainController
var _start_height := 0.0
var _end_height := 0.0

func configure(span: FenceSpanState, start: Vector2, end: Vector2, pixels_per_unit: float = 32.0, terrain: TerrainController = null) -> void:
	state = span
	data = span.data
	_pixels_per_unit = pixels_per_unit
	_terrain = terrain
	start_point = start
	end_point = end
	if start_point.x > end_point.x or (start_point.x == end_point.x and start_point.y > end_point.y):
		var swap := start_point
		start_point = end_point
		end_point = swap
	var first_height := _ground_height(start_point)
	var last_height := _ground_height(end_point)
	var center_height := (first_height + last_height) * 0.5
	_start_height = first_height - center_height
	_end_height = last_height - center_height
	var center := (start_point + end_point) * 0.5
	position = Vector3(center.x / pixels_per_unit, center_height, center.y / pixels_per_unit)
	var seed_value := 0 if preview_mode else hash([start_point.snapped(Vector2(0.25, 0.25)), end_point.snapped(Vector2(0.25, 0.25)), data.id])
	var delta := end_point - start_point
	var key := hash([data.id, delta.snapped(Vector2(0.001,0.001)), state.integrity(), seed_value, pixels_per_unit, snappedf(_end_height-_start_height,0.0001)])
	if key != _geometry_key or mesh == null:
		mesh = FenceGeometry.build_span(data,start_point-center,end_point-center,state.integrity(),seed_value,pixels_per_unit,_start_height*pixels_per_unit,_end_height*pixels_per_unit)
		_geometry_key = key
		if not preview_mode:
			_update_collision()
	if not preview_mode:
		material_override = FenceGeometry.material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if preview_mode else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func refresh() -> void:
	configure(state,start_point,end_point,_pixels_per_unit,_terrain)

func _ground_height(point: Vector2) -> float:
	if _terrain == null:
		return 0.0
	var world := get_parent_node_3d().to_global(Vector3(point.x,0,point.y)/_pixels_per_unit)
	return get_parent_node_3d().to_local(_terrain.surface_position(world)).y

func _update_collision() -> void:
	if _body == null:
		_body = StaticBody3D.new()
		_body.collision_layer = 2
		_body.collision_mask = 0
		add_child(_body)
		_shape = CollisionShape3D.new()
		_shape.shape = ConvexPolygonShape3D.new()
		_body.add_child(_shape)
	var center := (start_point + end_point) * 0.5
	var direction := (end_point - start_point).normalized()
	var normal := Vector2(-direction.y,direction.x) * data.thickness * 0.5 / _pixels_per_unit
	var points := PackedVector3Array()
	for index in 2:
		var point := ((start_point if index == 0 else end_point) - center) / _pixels_per_unit
		var height := _start_height if index == 0 else _end_height
		for side in [-1,1]:
			for top in [0.0,data.height/_pixels_per_unit]:
				points.append(Vector3(point.x+normal.x*side,height+top,point.y+normal.y*side))
	(_shape.shape as ConvexPolygonShape3D).points = points

func inspection_bounds() -> AABB:
	return mesh.get_aabb().grow(0.1) if mesh != null else AABB(Vector3.ZERO,Vector3.ONE)

func structure_condition() -> float:
	return state.integrity() if state != null else 0.0

func structure_title() -> String:
	return tr("%s span") % state.data.display_name if state != null else tr("Fence")

func damage_structure(amount: float) -> bool:
	var network := get_parent().get_parent() as FenceController
	return network.damage_span(state.id,amount) if network != null and state != null and not preview_mode else false

func repair_structure() -> bool:
	var network := get_parent().get_parent() as FenceController
	return network.repair_span(state.id) if network != null and state != null and not preview_mode else false
