class_name BrushController
extends Sprite2D

@export var brush_shader: Shader
@export var paint_surface: Sprite2D
@export_range(2, 96, 1) var brush_radius: int = 18
@export_range(0.1, 0.95, 0.05) var brush_hardness: float = 0.7

var _brush_material: ShaderMaterial


func _ready() -> void:
	hide()
	set_process(false)
	if brush_shader == null:
		push_error("Assign a brush preview shader.")
		return
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	texture = ImageTexture.create_from_image(image)
	_brush_material = ShaderMaterial.new()
	_brush_material.shader = brush_shader
	material = _brush_material


func is_ready_to_draw() -> bool:
	return _brush_material != null


func change_size(direction: int) -> void:
	brush_radius = clampi(brush_radius + direction * 4, 2, 96)


func activate_brush(enabled: bool = true) -> void:
	set_process(enabled and is_ready_to_draw() and is_instance_valid(paint_surface) and paint_surface.texture != null)
	if is_processing():
		_update_preview()
	else:
		hide()


func _process(_delta: float) -> void:
	_update_preview()


func _update_preview() -> void:
	if not is_instance_valid(paint_surface) or paint_surface.texture == null:
		activate_brush(false)
		return
	var rect := paint_surface.get_rect()
	var local_position := paint_surface.get_local_mouse_position()
	visible = paint_surface.is_visible_in_tree() and rect.has_point(local_position)
	if not visible:
		return
	# Follow the pointer in world space, preserving the terrain's pixel scale.
	var mask_transform := paint_surface.global_transform
	mask_transform.origin = paint_surface.to_global(local_position)
	var pixel_scale := rect.size / paint_surface.texture.get_size()
	mask_transform.x *= pixel_scale.x
	mask_transform.y *= pixel_scale.y
	# Keep enough transparent padding for the outline, including when zoomed out.
	var screen_transform := get_viewport().canvas_transform * mask_transform
	var screen_scale := maxf(minf(screen_transform.x.length(), screen_transform.y.length()), 0.001)
	var diameter := (float(brush_radius) + 4.0 / screen_scale) * 2.0
	global_transform = mask_transform.scaled_local(Vector2(diameter, diameter))
	_brush_material.set_shader_parameter("brush_radius", float(brush_radius))
	_brush_material.set_shader_parameter("brush_hardness", brush_hardness)
	_brush_material.set_shader_parameter("brush_diameter", diameter)
