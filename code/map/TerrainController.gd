class_name TerrainController
extends MeshInstance3D

signal terrain_changed
signal height_changed

enum SCULPT_TOOL { RAISE, LOWER, SMOOTH, FLATTEN }
enum GROUND_TYPE { GRASS = 0, SOIL = 1, SAND = 3, ROCK = 4 }


@export var terrain_shader: Shader
@export_group("Terrain appearance")
@export var terrain_seed := 17
@export_range(0.5, 3.0, 0.1) var terrain_scale := 1.0
@export_range(0.0, 1.0, 0.05) var terrain_detail := 0.65
@export_range(0.0, 6.0, 0.25) var edge_roughness := 2.5
@export_range(0.0, 24.0, 0.5) var transition_width := 10.0

@export_group("Terrain shape")
@export_range(0.25, 1.0, 0.25) var height_spacing := 0.5
var sculpt_speed := 1.0
@export var minimum_height := -4.0
@export var maximum_height := 6.0
var maximum_sculpt_slope := 40.0

@export_group("Terrain generation")
@export var generate_on_start := false
@export var generation_seed := 0
var starting_height_variation := 1.8
var terrain_wavelength := 22.0
var spawn_clearing_radius := 2.5

const TARGET_WEIGHTS := [Color(0,0,0,0), Color(1,0,0,0), Color(0,1,0,0), Color(0,0,1,0), Color(0,0,0,1)]

var starting_pond_radius := 2.4
var starting_pond_offset := Vector2(0, 5.5)
var starting_water_level := -0.35
var surface_water_level := -1000.0

var world_seed := 0
var _natural_image: Image
var _natural_texture: ImageTexture
var _ground_influence: Image
var _ground_influence_texture: ImageTexture
var pixels_per_unit := 32.0
var world_size := Vector2.ZERO
var _map_size := Vector2i.ZERO
var _ground_image: Image
var _ground_texture: ImageTexture
var _terrain_mat: ShaderMaterial
var _upload_pending := false

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

func initialize(map_size: Vector2i, pixel_density: float = 32.0, natural_start: bool = false) -> bool:
	if map_size.x <= 0 or map_size.y <= 0 or pixel_density <= 0.0 or terrain_shader == null:
		push_error("Assign a terrain shader, a positive map size and pixel density.")
		return false
	_map_size = map_size
	pixels_per_unit = pixel_density
	world_size = Vector2(map_size) / pixels_per_unit
	_ground_image = Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	_ground_image.fill(TARGET_WEIGHTS[0] if natural_start else TARGET_WEIGHTS[1])
	_ground_texture = ImageTexture.create_from_image(_ground_image)
	world_seed = generation_seed if generation_seed != 0 else randi_range(1,2147483647)
	_natural_image = null
	_natural_texture = ImageTexture.create_from_image(Image.create(1,1,false,Image.FORMAT_RGBA8))
	_ground_influence = Image.create(map_size.x,map_size.y,false,Image.FORMAT_R8)
	if not natural_start:
		_ground_influence.fill(Color(1,0,0,1))
	_ground_influence_texture = ImageTexture.create_from_image(_ground_influence)
	_create_height_surface()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = terrain_shader
	_terrain_mat.set_shader_parameter("ground_map", _ground_texture)
	_terrain_mat.set_shader_parameter("ground_influence", _ground_influence_texture)
	_terrain_mat.set_shader_parameter("nature_map", _natural_texture)
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
		_upload_ground_texture.call_deferred()

func _upload_ground_texture() -> void:
	_ground_texture.update(_ground_image)
	_ground_influence_texture.update(_ground_influence)
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
	var sample := _ground_image.duplicate() as Image
	sample.resize(sample_size.x, sample_size.y, Image.INTERPOLATE_TRILINEAR)
	if _natural_image == null:
		return sample
	var natural := _natural_image.duplicate() as Image
	natural.resize(sample_size.x,sample_size.y,Image.INTERPOLATE_BILINEAR)
	var influence := _ground_influence.duplicate() as Image
	influence.resize(sample_size.x,sample_size.y,Image.INTERPOLATE_TRILINEAR)
	var data := sample.get_data()
	var base := natural.get_data()
	var strengths := influence.get_data()
	for index in strengths.size():
		var amount := 1.0-float(strengths[index])/255.0
		for channel in 4:
			var offset := index*4+channel
			data[offset] = clampi(roundi(data[offset]+base[offset]*amount),0,255)
	return Image.create_from_data(sample_size.x,sample_size.y,false,Image.FORMAT_RGBA8,data)

func set_natural_coverage(coverage: Image) -> void:
	if _natural_image != null and _natural_image.get_size() == coverage.get_size() and _natural_image.get_data() == coverage.get_data():
		return
	_natural_image = coverage.duplicate() as Image
	var display := coverage.duplicate() as Image
	display.resize(coverage.get_width()*2,coverage.get_height()*2,Image.INTERPOLATE_CUBIC)
	if _natural_texture.get_size() != Vector2(display.get_size()):
		_natural_texture = ImageTexture.create_from_image(display)
		_terrain_mat.set_shader_parameter("nature_map",_natural_texture)
	else:
		_natural_texture.update(display)
	terrain_changed.emit()

func _coverage_at_pixel(x: int, y: int) -> Color:
	return _ground_image.get_pixel(x,y)+_nature_at_pixel(x,y)*(1.0-_ground_influence.get_pixel(x,y).r)

func _nature_at_pixel(x: int, y: int) -> Color:
	if _natural_image == null:
		return Color(0,0,0,0)
	var size := _natural_image.get_size()
	var grid := ((Vector2(x,y)+Vector2(0.5,0.5))/Vector2(_map_size)*Vector2(size)-Vector2(0.5,0.5)).clamp(Vector2.ZERO,Vector2(size-Vector2i.ONE))
	var first := Vector2i(grid.floor())
	var last := (first+Vector2i.ONE).min(size-Vector2i.ONE)
	var fraction := grid-Vector2(first)
	var back := _natural_image.get_pixel(first.x,first.y).lerp(_natural_image.get_pixel(last.x,first.y),fraction.x)
	var front := _natural_image.get_pixel(first.x,last.y).lerp(_natural_image.get_pixel(last.x,last.y),fraction.x)
	return back.lerp(front,fraction.y)

func _ground_weight(coverage: Color, material_index: int) -> float:
	if material_index == 0:
		return maxf(0.0,1.0-coverage.r-coverage.g-coverage.b-coverage.a)
	return maxf(0.0,coverage[material_index-1])

func grow_grass(world_position: Vector3, radius: float) -> float:
	if radius <= 0.0 or not contains_world_point(world_position):
		return 0.0
	var center := _world_to_mask(world_position)
	var pixel_radius := radius*pixels_per_unit
	var first := Vector2i((center-Vector2.ONE*pixel_radius).floor()).max(Vector2i.ZERO)
	var last := Vector2i((center+Vector2.ONE*pixel_radius).ceil()).min(_map_size-Vector2i.ONE)
	var area := 0.0
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var pixel := Vector2(x,y)+Vector2(0.5,0.5)
			var distance := pixel.distance_to(center)
			if distance >= pixel_radius:
				continue
			var position_2d := (pixel-Vector2(_map_size)*0.5)/pixels_per_unit
			if _sample_height(position_2d) <= surface_water_level+0.015:
				continue
			var before := _coverage_at_pixel(x,y)
			if _ground_weight(before,GROUND_TYPE.SOIL)+_ground_weight(before,GROUND_TYPE.GRASS) < 0.55:
				continue
			var amount := 1.0-smoothstep(pixel_radius*0.55,pixel_radius,distance)
			_ground_image.set_pixel(x,y,_ground_image.get_pixel(x,y).lerp(TARGET_WEIGHTS[GROUND_TYPE.GRASS],amount))
			var influence := _ground_influence.get_pixel(x,y).r
			_ground_influence.set_pixel(x,y,Color(lerpf(influence,1.0,amount),0,0,1))
			area += maxf(0.0,_ground_weight(_coverage_at_pixel(x,y),GROUND_TYPE.GRASS)-_ground_weight(before,GROUND_TYPE.GRASS))/(pixels_per_unit*pixels_per_unit)
	if area > 0.0:
		_queue_upload()
	return area

func _create_height_surface() -> void:
	_height_size = Vector2i(ceil(world_size / height_spacing)) + Vector2i.ONE
	_height_cell = world_size / Vector2(_height_size - Vector2i.ONE)
	_heights.resize(_height_size.x * _height_size.y)
	_heights.fill(0)
	_generate_starting_heights()
	_collision_heights = _heights.duplicate()
	var plane := PlaneMesh.new()
	plane.size = world_size
	plane.subdivide_width = _height_size.x - 2
	plane.subdivide_depth = _height_size.y - 2
	_mesh_arrays = plane.get_mesh_arrays()
	_vertex_indices.resize(_heights.size())
	var vertices: PackedVector3Array = _mesh_arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = _mesh_arrays[Mesh.ARRAY_NORMAL]
	for index in vertices.size():
		var point := Vector2(vertices[index].x, vertices[index].z)
		var cell := Vector2i(((point + world_size * 0.5) / _height_cell).round())
		var height_index := cell.y * _height_size.x + cell.x
		_vertex_indices[height_index] = index
		var vertex := vertices[index]
		vertex.y = _heights[height_index]
		vertices[index] = vertex
		normals[index] = _height_normal(cell)
		_collision_heights[height_index] = _heights[height_index] / _height_cell.x
	_mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
	_mesh_arrays[Mesh.ARRAY_NORMAL] = normals
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
	var first := _heights[index]
	var right := _heights[index+1]
	var front := _heights[index+_height_size.x]
	if fraction.x + fraction.y <= 1.0:
		return first + (right-first)*fraction.x + (front-first)*fraction.y
	var last := _heights[index+_height_size.x+1]
	return last + (front-last)*(1.0-fraction.x) + (right-last)*(1.0-fraction.y)

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
			normals[vertex_index] = _height_normal(Vector2i(x,y))
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

func _generate_starting_heights() -> void:
	if not generate_on_start:
		return
	var random := RandomNumberGenerator.new()
	random.seed = world_seed
	var hills := FastNoiseLite.new()
	hills.seed = random.randi_range(1,2147483647)
	hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hills.frequency = 1.0 / terrain_wavelength
	hills.fractal_type = FastNoiseLite.FRACTAL_FBM
	hills.fractal_octaves = 3
	hills.fractal_gain = 0.42
	var basins := FastNoiseLite.new()
	basins.seed = random.randi_range(1,2147483647)
	basins.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	basins.frequency = 0.65 / terrain_wavelength
	basins.fractal_octaves = 2
	var offset := Vector2(random.randf_range(-1000,1000),random.randf_range(-1000,1000))
	for y in _height_size.y:
		for x in _height_size.x:
			var point := Vector2(x,y) * _height_cell - world_size * 0.5
			var sample_point := point + offset
			var height := (hills.get_noise_2dv(sample_point) * 1.45 + basins.get_noise_2dv(sample_point) * 0.45) * starting_height_variation + 0.05
			if spawn_clearing_radius > 0.0:
				height *= smoothstep(spawn_clearing_radius*0.35,spawn_clearing_radius*1.75,point.length())
			if starting_pond_radius > 0.0:
				var distance := point.distance_to(starting_pond_offset)
				var pond := 1.0-smoothstep(starting_pond_radius*0.3,starting_pond_radius,distance)
				height = lerpf(height,starting_water_level-0.65,pond)
			_heights[y * _height_size.x + x] = clampf(height,minimum_height,maximum_height)

func _height_normal(cell: Vector2i) -> Vector3:
	var left := maxi(0,cell.x-1)
	var right := mini(_height_size.x-1,cell.x+1)
	var back := maxi(0,cell.y-1)
	var front := mini(_height_size.y-1,cell.y+1)
	var dx := (_heights[cell.y*_height_size.x+left]-_heights[cell.y*_height_size.x+right]) / ((right-left)*_height_cell.x)
	var dz := (_heights[back*_height_size.x+cell.x]-_heights[front*_height_size.x+cell.x]) / ((front-back)*_height_cell.y)
	return Vector3(dx,1,dz).normalized()

func ground_weight(world_position: Vector3, material_index: int) -> float:
	var point := Vector2i(_world_to_mask(world_position).floor())
	if point.x < 0 or point.y < 0 or point.x >= _map_size.x or point.y >= _map_size.y:
		return 0.0
	return _ground_weight(_coverage_at_pixel(point.x,point.y),material_index)

func slope_at(world_position: Vector3) -> float:
	var point := to_local(world_position)
	var xz := Vector2(point.x,point.z)
	var dx := _sample_height(xz+Vector2(0.25,0))-_sample_height(xz-Vector2(0.25,0))
	var dz := _sample_height(xz+Vector2(0,0.25))-_sample_height(xz-Vector2(0,0.25))
	return Vector2(dx,dz).length()/0.5

func has_submerged_ground(water_level: float) -> bool:
	for height in _heights:
		if global_position.y+height*global_basis.y.y < water_level-0.02:
			return true
	return false

func rocky_impact(world_position: Vector3, radius: float, strength: float) -> float:
	if radius <= 0.0 or strength <= 0.0 or not contains_world_point(world_position):
		return 0.0
	var local := to_local(world_position)
	var point := Vector2(local.x,local.z)
	var center := (point+world_size*0.5)/_height_cell
	var padding := Vector2.ONE*radius/_height_cell
	var first := Vector2i((center-padding).floor()).max(Vector2i.ZERO)
	var last := Vector2i((center+padding).ceil()).min(_height_size-Vector2i.ONE)
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var distance := (Vector2(x,y)*_height_cell-world_size*0.5).distance_to(point)/radius
			if distance >= 1.0:
				continue
			var ripple := sin(distance*TAU-PI*0.5)*(1.0-smoothstep(0.45,1.0,distance))
			var index := y*_height_size.x+x
			_heights[index] = clampf(_heights[index]+ripple*strength,minimum_height,maximum_height)
			_collision_heights[index] = _heights[index]/_height_cell.x
	var changed := Rect2i(first,last-first+Vector2i.ONE)
	_height_dirty = _height_dirty.merge(changed) if _height_dirty.has_area() else changed
	if not _height_upload_pending:
		_height_upload_pending = true
		_upload_height_surface.call_deferred()
	var mask_center := _world_to_mask(world_position)
	var mask_radius := radius*pixels_per_unit
	var mask_first := Vector2i((mask_center-Vector2.ONE*mask_radius).floor()).max(Vector2i.ZERO)
	var mask_last := Vector2i((mask_center+Vector2.ONE*mask_radius).ceil()).min(_map_size-Vector2i.ONE)
	var area := 0.0
	for y in range(mask_first.y,mask_last.y+1):
		for x in range(mask_first.x,mask_last.x+1):
			var distance := (Vector2(x,y)+Vector2(0.5,0.5)).distance_to(mask_center)/mask_radius
			if distance >= 1.0:
				continue
			var amount := 1.0-smoothstep(0.5,1.0,distance)
			var before := _ground_weight(_coverage_at_pixel(x,y),GROUND_TYPE.ROCK)
			_ground_image.set_pixel(x,y,_ground_image.get_pixel(x,y).lerp(TARGET_WEIGHTS[GROUND_TYPE.ROCK],amount))
			_ground_influence.set_pixel(x,y,Color(1,0,0,1))
			area += maxf(0.0,_ground_weight(_coverage_at_pixel(x,y),GROUND_TYPE.ROCK)-before)/(pixels_per_unit*pixels_per_unit)
	_queue_upload()
	return area
