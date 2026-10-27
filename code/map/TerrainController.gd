class_name TerrainController
extends MeshInstance3D

signal terrain_changed
signal height_changed

enum SCULPT_TOOL { RAISE, LOWER, SMOOTH, FLATTEN }


@export var terrain_shader: Shader
@export_group("Terrain appearance")
@export var terrain_seed := 17
@export_range(0.5, 3.0, 0.1) var terrain_scale := 1.0
@export_range(0.0, 1.0, 0.05) var terrain_detail := 0.65
@export_range(0.0, 6.0, 0.25) var edge_roughness := 2.5
@export_range(0.0, 24.0, 0.5) var transition_width := 10.0

@export_group("Terrain shape")
@export_range(0.25, 1.0, 0.25) var height_spacing := 0.5
@export_range(0.1, 4.0, 0.1) var sculpt_speed := 1.0
@export var minimum_height := -4.0
@export var maximum_height := 6.0
@export_range(10.0, 60.0, 1.0) var maximum_sculpt_slope := 40.0

const TARGET_WEIGHTS := [Color(0,0,0,0), Color(1,0,0,0), Color(0,1,0,0), Color(0,0,1,0), Color(0,0,0,1)]

var pixels_per_unit := 32.0
var world_size := Vector2.ZERO
var _map_size := Vector2i.ZERO
var _paint_tex: Image
var _paint_texture: ImageTexture
var _terrain_mat: ShaderMaterial
var _upload_pending := false
var _has_previous_stamp := false
var _last_paint_position := Vector2.ZERO
var _last_material := -1

var _height_size := Vector2i.ZERO
var _height_cell := Vector2.ZERO
var _heights := PackedFloat32Array()
var _collision_heights := PackedFloat32Array()
var _height_texture: ImageTexture
var _ground_shape: HeightMapShape3D
var _mesh_arrays: Array
var _vertex_indices := PackedInt32Array()
var _height_dirty := Rect2i()
var _height_upload_pending := false
var _sculpt_active := false
var _sculpt_tool: SCULPT_TOOL = SCULPT_TOOL.RAISE
var _sculpt_target := Vector3.ZERO
var _sculpt_radius := 48.0
var _sculpt_hardness := 0.7
var _flatten_height := 0.0
var _sculpt_elapsed := 0.0
var _previous_sculpt_point := Vector2.INF

func initialize(map_size: Vector2i, pixel_density: float = 32.0) -> bool:
	if map_size.x <= 0 or map_size.y <= 0 or pixel_density <= 0.0 or terrain_shader == null:
		push_error("Assign a terrain shader, a positive map size and pixel density.")
		return false
	end_stroke()
	_map_size = map_size
	pixels_per_unit = pixel_density
	world_size = Vector2(map_size) / pixels_per_unit
	_paint_tex = Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	_paint_tex.fill(TARGET_WEIGHTS[0])
	_paint_texture = ImageTexture.create_from_image(_paint_tex)
	_create_height_surface()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = terrain_shader
	_terrain_mat.set_shader_parameter("paint_map", _paint_texture)
	_terrain_mat.set_shader_parameter("map_size", Vector2(map_size))
	_terrain_mat.set_shader_parameter("world_size", world_size)
	_terrain_mat.set_shader_parameter("terrain_seed", float(terrain_seed))
	_terrain_mat.set_shader_parameter("terrain_scale", terrain_scale)
	_terrain_mat.set_shader_parameter("detail_strength", terrain_detail)
	_terrain_mat.set_shader_parameter("edge_roughness", edge_roughness)
	_terrain_mat.set_shader_parameter("transition_width", transition_width)
	material_override = _terrain_mat
	_create_ground_collision()
	return true

func _queue_upload() -> void:
	if not _upload_pending:
		_upload_pending = true
		_upload_paint_texture.call_deferred()

func _upload_paint_texture() -> void:
	_paint_texture.update(_paint_tex)
	_upload_pending = false
	terrain_changed.emit()

func _contains_mask_point(mask_position: Vector2) -> bool:
	return Rect2(Vector2.ZERO, Vector2(_map_size)).has_point(mask_position)

func contains_world_point(world_position: Vector3) -> bool:
	return _contains_mask_point(_world_to_mask(world_position))

func _world_to_mask(world_position: Vector3) -> Vector2:
	var local := to_local(world_position)
	return Vector2(local.x, local.z) * pixels_per_unit + Vector2(_map_size) * 0.5

func sample_coverage(sample_size: Vector2i) -> Image:
	var sample := _paint_tex.duplicate() as Image
	sample.resize(sample_size.x, sample_size.y, Image.INTERPOLATE_TRILINEAR)
	return sample

func end_stroke() -> void:
	_has_previous_stamp = false

func paint(material_index: int, world_position: Vector3, radius: float, hardness: float) -> void:
	var point := _world_to_mask(world_position)
	if not _contains_mask_point(point):
		end_stroke()
		return
	if _has_previous_stamp and _last_material == material_index:
		var spacing := maxf(1.0, radius * 0.35)
		var steps := maxi(1, ceili(_last_paint_position.distance_to(point) / spacing))
		for step in range(1, steps + 1):
			_paint_stamp(_last_paint_position.lerp(point, float(step) / steps), material_index, radius, hardness)
	else:
		_paint_stamp(point, material_index, radius, hardness)
	_last_paint_position = point
	_last_material = material_index
	_has_previous_stamp = true
	_queue_upload()

func _paint_stamp(brush_pos: Vector2, material_index: int, radius: float, hardness: float) -> void:
	var min_x := maxi(0, floori(brush_pos.x - radius))
	var max_x := mini(_map_size.x - 1, ceili(brush_pos.x + radius))
	var min_y := maxi(0, floori(brush_pos.y - radius))
	var max_y := mini(_map_size.y - 1, ceili(brush_pos.y + radius))
	var target: Color = TARGET_WEIGHTS[clampi(material_index, 0, TARGET_WEIGHTS.size() - 1)]
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var distance := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(brush_pos)
			if distance >= radius:
				continue
			var amount := 1.0 - smoothstep(radius * clampf(hardness, 0.0, 0.99), radius, distance)
			_paint_tex.set_pixel(x, y, _paint_tex.get_pixel(x, y).lerp(target, amount))

func _create_height_surface() -> void:
	_height_size = Vector2i(ceil(world_size / height_spacing)) + Vector2i.ONE
	_height_cell = world_size / Vector2(_height_size - Vector2i.ONE)
	_heights.resize(_height_size.x * _height_size.y)
	_heights.fill(0)
	_collision_heights = _heights.duplicate()
	var plane := PlaneMesh.new()
	plane.size = world_size
	plane.subdivide_width = _height_size.x - 2
	plane.subdivide_depth = _height_size.y - 2
	_mesh_arrays = plane.get_mesh_arrays()
	_vertex_indices.resize(_heights.size())
	var vertices: PackedVector3Array = _mesh_arrays[Mesh.ARRAY_VERTEX]
	for index in vertices.size():
		var point := Vector2(vertices[index].x, vertices[index].z)
		var cell := Vector2i(((point + world_size * 0.5) / _height_cell).round())
		_vertex_indices[cell.y * _height_size.x + cell.x] = index
	var surface := ArrayMesh.new()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _mesh_arrays)
	mesh = surface
	var image := Image.create_from_data(_height_size.x, _height_size.y, false, Image.FORMAT_RF, _heights.to_byte_array())
	_height_texture = ImageTexture.create_from_image(image)
	set_physics_process(false)

func _create_ground_collision() -> void:
	var previous := get_node_or_null("GroundBody")
	if previous != null:
		remove_child(previous)
		previous.queue_free()
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var collision := CollisionShape3D.new()
	_ground_shape = HeightMapShape3D.new()
	_ground_shape.map_width = _height_size.x
	_ground_shape.map_depth = _height_size.y
	_ground_shape.map_data = _collision_heights
	collision.shape = _ground_shape
	collision.scale = Vector3(_height_cell.x, _height_cell.x, _height_cell.y)
	body.add_child(collision)

func create_surface_mesh() -> PlaneMesh:
	var plane := PlaneMesh.new()
	plane.size = world_size
	plane.subdivide_width = _height_size.x - 2
	plane.subdivide_depth = _height_size.y - 2
	return plane

func bind_height_material(material: ShaderMaterial) -> void:
	material.set_shader_parameter("height_map", _height_texture)
	material.set_shader_parameter("height_size", Vector2(_height_size))
	material.set_shader_parameter("height_world_size", world_size)
	material.set_shader_parameter("ground_to_world", global_transform)
	material.set_shader_parameter("world_to_ground", global_transform.affine_inverse())

func surface_position(world_position: Vector3) -> Vector3:
	var local := to_local(world_position)
	local.y = _sample_height(Vector2(local.x, local.z))
	return to_global(local)

func _sample_height(point: Vector2) -> float:
	var grid := ((point + world_size * 0.5) / _height_cell).clamp(Vector2.ZERO, Vector2(_height_size - Vector2i.ONE))
	var cell := Vector2i(grid.floor()).min(_height_size - Vector2i(2,2))
	var fraction := grid - Vector2(cell)
	var index := cell.y * _height_size.x + cell.x
	return lerpf(lerpf(_heights[index], _heights[index + 1], fraction.x), lerpf(_heights[index + _height_size.x], _heights[index + _height_size.x + 1], fraction.x), fraction.y)

func intersect_ray(world_origin: Vector3, world_direction: Vector3) -> Variant:
	var origin := to_local(world_origin)
	var direction := global_basis.inverse() * world_direction
	var lower := Vector3(-world_size.x * 0.5, minimum_height - 0.1, -world_size.y * 0.5)
	var upper := Vector3(world_size.x * 0.5, maximum_height + 0.1, world_size.y * 0.5)
	var first := 0.0
	var last := 1000.0
	for axis in 3:
		if absf(direction[axis]) < 0.000001:
			if origin[axis] < lower[axis] or origin[axis] > upper[axis]:
				return null
		else:
			var entry := (lower[axis] - origin[axis]) / direction[axis]
			var exit := (upper[axis] - origin[axis]) / direction[axis]
			first = maxf(first, minf(entry, exit))
			last = minf(last, maxf(entry, exit))
	if first > last:
		return null
	var step := minf(_height_cell.x, _height_cell.y) * 0.4 / maxf(maxf(absf(direction.x), absf(direction.z)), 0.1)
	var previous := first
	var at := first
	while at <= last:
		var point := origin + direction * at
		var difference := point.y - _sample_height(Vector2(point.x, point.z))
		if difference <= 0:
			if at == first and difference < -0.001:
				return null
			var left := previous
			var right := at
			for division in 14:
				var middle := (left + right) * 0.5
				var sample_point := origin + direction * middle
				if sample_point.y > _sample_height(Vector2(sample_point.x, sample_point.z)):
					left = middle
				else:
					right = middle
			return to_global(origin + direction * ((left + right) * 0.5))
		previous = at
		if at == last:
			break
		at = minf(last, at + step)
	return null

func begin_sculpt(tool: SCULPT_TOOL, world_position: Vector3, radius: float, hardness: float) -> void:
	if not contains_world_point(world_position):
		return
	_sculpt_tool = tool
	_sculpt_target = world_position
	_sculpt_radius = radius / pixels_per_unit
	_sculpt_hardness = hardness
	_flatten_height = to_local(surface_position(world_position)).y
	_sculpt_elapsed = 0
	_previous_sculpt_point = Vector2.INF
	_sculpt_active = true
	set_physics_process(true)

func update_sculpt_target(world_position: Variant, radius: float, hardness: float) -> void:
	if world_position == null:
		_previous_sculpt_point = Vector2.INF
		set_physics_process(false)
		return
	set_physics_process(_sculpt_active)
	_sculpt_target = world_position
	_sculpt_radius = radius / pixels_per_unit
	_sculpt_hardness = hardness

func end_sculpt() -> void:
	_sculpt_active = false
	_previous_sculpt_point = Vector2.INF
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not _sculpt_active:
		return
	_sculpt_elapsed += delta
	if _sculpt_elapsed < 1.0 / 30.0:
		return
	var elapsed := minf(_sculpt_elapsed, 0.1)
	_sculpt_elapsed = 0
	var local := to_local(_sculpt_target)
	var point := Vector2(local.x, local.z)
	var steps := 1 if _previous_sculpt_point == Vector2.INF else maxi(1, ceili(_previous_sculpt_point.distance_to(point) / maxf(_sculpt_radius * 0.3, height_spacing)))
	for index in steps:
		var stamp := point if _previous_sculpt_point == Vector2.INF else _previous_sculpt_point.lerp(point, float(index + 1) / steps)
		_sculpt_stamp(stamp, elapsed / steps)
	_previous_sculpt_point = point
	if _height_dirty.has_area() and not _height_upload_pending:
		_height_upload_pending = true
		_upload_height_surface.call_deferred()

func _sculpt_stamp(point: Vector2, elapsed: float) -> void:
	var center := (point + world_size * 0.5) / _height_cell
	var padding := Vector2.ONE * _sculpt_radius / _height_cell
	var first := Vector2i((center - padding).floor()).max(Vector2i.ZERO)
	var last := Vector2i((center + padding).ceil()).min(_height_size - Vector2i.ONE)
	var source := _heights.duplicate() if _sculpt_tool == SCULPT_TOOL.SMOOTH else PackedFloat32Array()
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var position_2d := Vector2(x, y) * _height_cell - world_size * 0.5
			var distance := point.distance_to(position_2d)
			if distance >= _sculpt_radius:
				continue
			var influence := 1.0 - smoothstep(_sculpt_radius * clampf(_sculpt_hardness * 0.3,0.05,0.3), _sculpt_radius, distance)
			var index := y * _height_size.x + x
			var height := _heights[index]
			var amount := sculpt_speed * elapsed * influence
			match _sculpt_tool:
				SCULPT_TOOL.RAISE:
					height += amount
				SCULPT_TOOL.LOWER:
					height -= amount
				SCULPT_TOOL.FLATTEN:
					height = move_toward(height, _flatten_height, amount)
				SCULPT_TOOL.SMOOTH:
					var sum := 0.0
					var count := 0
					for row in range(maxi(0,y-1),mini(_height_size.y-1,y+1)+1):
						for column in range(maxi(0,x-1),mini(_height_size.x-1,x+1)+1):
							sum += source[row * _height_size.x + column]
							count += 1
					height = lerpf(height, sum / count, minf(1,amount * 5.0))
			height = clampf(height, minimum_height, maximum_height)
			var gradient := tan(deg_to_rad(maximum_sculpt_slope))
			for row in range(maxi(0,y-1),mini(_height_size.y-1,y+1)+1):
				for column in range(maxi(0,x-1),mini(_height_size.x-1,x+1)+1):
					if row == y and column == x:
						continue
					var limit := (Vector2(column-x,row-y) * _height_cell).length() * gradient
					var neighbor := _heights[row * _height_size.x + column]
					height = clampf(height, neighbor-limit, neighbor+limit)
			if absf(height-_heights[index]) > 0.00001:
				_heights[index] = height
				_collision_heights[index] = height / _height_cell.x
				var changed := Rect2i(x,y,1,1)
				_height_dirty = changed if not _height_dirty.has_area() else _height_dirty.merge(changed)

func _upload_height_surface() -> void:
	var bounds := _height_dirty.grow(1).intersection(Rect2i(Vector2i.ZERO,_height_size))
	_height_dirty = Rect2i()
	var vertices: PackedVector3Array = _mesh_arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = _mesh_arrays[Mesh.ARRAY_NORMAL]
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var index := y * _height_size.x + x
			var vertex_index := _vertex_indices[index]
			var vertex := vertices[vertex_index]
			vertex.y = _heights[index]
			vertices[vertex_index] = vertex
			var left := _heights[y * _height_size.x + maxi(0,x-1)]
			var right := _heights[y * _height_size.x + mini(_height_size.x-1,x+1)]
			var back := _heights[maxi(0,y-1) * _height_size.x + x]
			var front := _heights[mini(_height_size.y-1,y+1) * _height_size.x + x]
			normals[vertex_index] = Vector3((left-right)/(_height_cell.x*2),1,(back-front)/(_height_cell.y*2)).normalized()
	_mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
	_mesh_arrays[Mesh.ARRAY_NORMAL] = normals
	var surface := ArrayMesh.new()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_mesh_arrays)
	mesh = surface
	_ground_shape.map_data = _collision_heights
	var image := Image.create_from_data(_height_size.x,_height_size.y,false,Image.FORMAT_RF,_heights.to_byte_array())
	_height_texture.update(image)
	_height_upload_pending = false
	height_changed.emit()
