class_name TerrainController
extends Sprite2D

@export var terrain_shader: Shader

@export_group("Terrain appearance")
@export var terrain_seed: int = 17
@export_range(0.5, 3.0, 0.1) var terrain_scale: float = 1.0
@export_range(0.0, 1.0, 0.05) var terrain_detail: float = 0.65
@export_range(0.0, 6.0, 0.25) var edge_roughness: float = 2.5
@export_range(0.0, 24.0, 0.5) var transition_width: float = 10.0

const TARGET_WEIGHTS := [
	Color(0.0, 0.0, 0.0, 0.0),
	Color(1.0, 0.0, 0.0, 0.0),
	Color(0.0, 1.0, 0.0, 0.0),
	Color(0.0, 0.0, 1.0, 0.0),
	Color(0.0, 0.0, 0.0, 1.0),
]

var _paint_tex: Image
var _paint_texture: ImageTexture
var _terrain_mat: ShaderMaterial
var _upload_pending := false
var _has_previous_stamp := false
var _last_paint_position := Vector2.ZERO
var _last_material := -1


func initialize(map_size: Vector2i) -> bool:
	if map_size.x <= 0 or map_size.y <= 0 or terrain_shader == null:
		push_error("Assign a terrain shader and a positive map size.")
		return false
	end_stroke()

	# Keep editable pixels in CPU memory and one matching texture on the GPU.
	_paint_tex = Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	_paint_tex.fill(TARGET_WEIGHTS[0])
	_paint_texture = ImageTexture.create_from_image(_paint_tex)
	texture = _paint_texture

	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED

	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = terrain_shader
	_terrain_mat.set_shader_parameter("paint_map", _paint_texture)
	_terrain_mat.set_shader_parameter("map_size", Vector2(map_size))
	_terrain_mat.set_shader_parameter("terrain_seed", float(terrain_seed))
	_terrain_mat.set_shader_parameter("terrain_scale", terrain_scale)
	_terrain_mat.set_shader_parameter("detail_strength", terrain_detail)
	_terrain_mat.set_shader_parameter("edge_roughness", edge_roughness)
	_terrain_mat.set_shader_parameter("transition_width", transition_width)
	material = _terrain_mat
	return true


func _queue_upload() -> void:
	if _upload_pending:
		return
	_upload_pending = true
	_upload_paint_texture.call_deferred()


func _upload_paint_texture() -> void:
	_paint_texture.update(_paint_tex)
	_upload_pending = false


func is_ready_to_paint() -> bool:
	return _paint_tex != null


func contains_mask_point(mask_position: Vector2) -> bool:
	return is_ready_to_paint() and Rect2(Vector2.ZERO, Vector2(_paint_tex.get_size())).has_point(mask_position)


func _world_to_mask(world_position: Vector2) -> Vector2:
	# World positions already include the camera; undo the sprite transform only.
	var local := to_local(world_position)
	var rect := get_rect()
	return (local - rect.position) / rect.size * Vector2(_paint_tex.get_size())


func end_stroke() -> void:
	_has_previous_stamp = false


func paint(material_index: int, world_position: Vector2, radius: float, hardness: float) -> void:
	if not is_ready_to_paint() or radius <= 0.0:
		end_stroke()
		return
	var point := _world_to_mask(world_position)
	if not contains_mask_point(point):
		end_stroke()
		return
	if _has_previous_stamp and _last_material == material_index:
		var spacing := maxf(1.0, radius * 0.35)
		var steps := maxi(1, ceili(_last_paint_position.distance_to(point) / spacing))
		for step in range(1, steps + 1):
			_paint_stamp(_last_paint_position.lerp(point, float(step) / float(steps)), material_index, radius, hardness)
	else:
		_paint_stamp(point, material_index, radius, hardness)
	_last_paint_position = point
	_last_material = material_index
	_has_previous_stamp = true
	# Coalesce the stamps from an input batch into one deferred GPU upload.
	_queue_upload()


func _paint_stamp(brush_pos: Vector2, material_index: int, radius: float, hardness: float) -> void:
	var map_size := _paint_tex.get_size()
	var min_x := maxi(0, floori(brush_pos.x - radius))
	var max_x := mini(map_size.x - 1, ceili(brush_pos.x + radius))
	var min_y := maxi(0, floori(brush_pos.y - radius))
	var max_y := mini(map_size.y - 1, ceili(brush_pos.y + radius))
	var target: Color = TARGET_WEIGHTS[clampi(material_index, 0, TARGET_WEIGHTS.size() - 1)]

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var distance := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(brush_pos)
			if distance >= radius:
				continue
			var amount := 1.0 - smoothstep(radius * clampf(hardness, 0.0, 0.99), radius, distance)
			var previous := _paint_tex.get_pixel(x, y)
			var next := previous.lerp(target, amount)
			_paint_tex.set_pixel(x, y, next)
