class_name BrushController
extends MeshInstance3D

@export var brush_shader: Shader
@export var paint_surface: TerrainController
@export_range(2, 192, 1) var brush_radius := 18
@export_range(2, 192, 1) var brush_max_radius := 50
@export_range(0.1, 0.95, 0.05) var brush_hardness := 0.7

var _brush_material: ShaderMaterial
var _sculpting := false
var _paint_radius := 18
var _sculpt_radius := 48

func _ready() -> void:
	hide()
	set_process(false)
	if brush_shader == null:
		push_error("Assign a brush preview shader.")
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_brush_material = ShaderMaterial.new()
	_brush_material.shader = brush_shader
	material_override = _brush_material

func configure_surface() -> void:
	paint_surface.bind_height_material(_brush_material)
	extra_cull_margin = maxf(absf(paint_surface.minimum_height),absf(paint_surface.maximum_height))

func set_sculpting(active: bool) -> void:
	if active == _sculpting:
		return
	if active:
		_paint_radius = brush_radius
		brush_radius = _sculpt_radius
	else:
		_sculpt_radius = brush_radius
		brush_radius = _paint_radius
	_sculpting = active

func activate(active: bool) -> void:
	visible = active
	set_process(active)

func change_size(direction: int) -> void:
	brush_radius = clampi(brush_radius + direction * 4, 32 if _sculpting else 2, 160 if _sculpting else brush_max_radius)

func _process(_delta: float) -> void:
	if not is_instance_valid(paint_surface) or get_viewport().gui_get_hovered_control() != null:
		hide()
		return
	var camera := get_viewport().get_camera_3d()
	var point = GroundPicker3D.from_screen(camera, get_viewport().get_mouse_position(), paint_surface)
	if point == null or not paint_surface.contains_world_point(point):
		hide()
		return
	show()
	var screen_origin := camera.unproject_position(point)
	var screen_x := camera.unproject_position(point + paint_surface.global_basis.x / paint_surface.pixels_per_unit)
	var screen_z := camera.unproject_position(point + paint_surface.global_basis.z / paint_surface.pixels_per_unit)
	var screen_scale := maxf(minf(screen_origin.distance_to(screen_x), screen_origin.distance_to(screen_z)), 0.001)
	var diameter := 2.0 * (brush_radius + 4.0 / screen_scale)
	var world_diameter := diameter / paint_surface.pixels_per_unit
	global_transform = Transform3D(paint_surface.global_basis.scaled(Vector3(world_diameter, 1, world_diameter)), point + paint_surface.global_basis.y.normalized() * 0.018)
	_brush_material.set_shader_parameter("brush_radius", float(brush_radius))
	_brush_material.set_shader_parameter("brush_hardness", brush_hardness)
	_brush_material.set_shader_parameter("brush_diameter", diameter)
