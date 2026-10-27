class_name WaterController
extends MeshInstance3D

@export var water_level := -0.35:
	set(value):
		water_level = value
		_apply_level()
@export var water_shader: Shader
@export_group("Water appearance")
@export_color_no_alpha var shallow_color := Color(0.23, 0.49, 0.43)
@export_color_no_alpha var deep_color := Color(0.08, 0.28, 0.32)
@export_color_no_alpha var foam_color := Color(0.80, 0.87, 0.69)
@export_range(0.05, 0.5, 0.01) var shore_width := 0.20
@export_range(0.0, 0.05, 0.001) var wave_height := 0.018

var _terrain: TerrainController
var _water_material: ShaderMaterial

func initialize(terrain: TerrainController) -> void:
	_terrain = terrain
	mesh = terrain.create_surface_mesh()
	global_transform = terrain.global_transform
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = wave_height * 2.0
	_water_material = ShaderMaterial.new()
	_water_material.shader = water_shader
	_water_material.render_priority = -20
	_water_material.set_shader_parameter("shallow_color", shallow_color)
	_water_material.set_shader_parameter("deep_color", deep_color)
	_water_material.set_shader_parameter("foam_color", foam_color)
	_water_material.set_shader_parameter("shore_width", shore_width)
	_water_material.set_shader_parameter("wave_height", wave_height)
	terrain.bind_height_material(_water_material)
	material_override = _water_material
	_apply_level()

func _apply_level() -> void:
	if _terrain == null or _water_material == null:
		return
	global_position = _terrain.to_global(Vector3(0, water_level, 0))
	_water_material.set_shader_parameter("water_level", water_level)
	var ground_material := _terrain.material_override as ShaderMaterial
	if ground_material != null:
		ground_material.set_shader_parameter("water_level", water_level)
