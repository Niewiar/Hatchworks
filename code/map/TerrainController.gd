class_name TerrainController
extends MeshInstance3D

@export var terrain_shader: Shader
@export_group("Terrain appearance")
@export var terrain_seed := 17
@export_range(0.5, 3.0, 0.1) var terrain_scale := 1.0
@export_range(0.0, 1.0, 0.05) var terrain_detail := 0.65
@export_range(0.0, 6.0, 0.25) var edge_roughness := 2.5
@export_range(0.0, 24.0, 0.5) var transition_width := 10.0

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
	var plane := PlaneMesh.new()
	plane.size = world_size
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	var old_body := get_node_or_null("GroundBody")
	if old_body != null:
		remove_child(old_body)
		old_body.queue_free()
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(world_size.x, 0.1, world_size.y)
	collision.shape = shape
	collision.position.y = -0.05
	body.add_child(collision)
	return true

func _queue_upload() -> void:
	if not _upload_pending:
		_upload_pending = true
		_upload_paint_texture.call_deferred()

func _upload_paint_texture() -> void:
	_paint_texture.update(_paint_tex)
	_upload_pending = false

func contains_mask_point(mask_position: Vector2) -> bool:
	return Rect2(Vector2.ZERO, Vector2(_map_size)).has_point(mask_position)

func contains_world_point(world_position: Vector3) -> bool:
	return contains_mask_point(_world_to_mask(world_position))

func _world_to_mask(world_position: Vector3) -> Vector2:
	var local := to_local(world_position)
	return Vector2(local.x, local.z) * pixels_per_unit + Vector2(_map_size) * 0.5

func mask_to_world(mask_position: Vector2) -> Vector3:
	var local := (mask_position - Vector2(_map_size) * 0.5) / pixels_per_unit
	return to_global(Vector3(local.x, 0, local.y))

func end_stroke() -> void:
	_has_previous_stamp = false

func paint(material_index: int, world_position: Vector3, radius: float, hardness: float) -> void:
	var point := _world_to_mask(world_position)
	if not contains_mask_point(point):
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
