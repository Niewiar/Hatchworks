class_name TuftlingAppearance
extends Node3D

const FEMALE_SHADER = preload("res://code/creatures/tuftling_female.gdshader")

var _sex := 0
var _body: MeshInstance3D
var _male_material: BaseMaterial3D
var _female_material: ShaderMaterial

func _ready() -> void:
	apply_sex(_sex)

func apply_sex(value: int) -> void:
	_sex = value
	var crown := get_node_or_null("Mossling_Rig/Skeleton3D/FemaleCrown") as Node3D
	if crown != null:
		crown.visible = value == 1
	if _body == null:
		_body = find_child("Mossling",true,false) as MeshInstance3D
		if _body != null:
			_male_material = _body.get_active_material(0) as BaseMaterial3D
	if _body == null or _male_material == null:
		return
	if value == 1 and _female_material == null:
		_female_material = ShaderMaterial.new()
		_female_material.shader = FEMALE_SHADER
		_female_material.set_shader_parameter("albedo_texture",_male_material.get_texture(BaseMaterial3D.TEXTURE_ALBEDO))
		_female_material.set_shader_parameter("normal_texture",_male_material.get_texture(BaseMaterial3D.TEXTURE_NORMAL))
		_female_material.set_shader_parameter("roughness_texture",_male_material.get_texture(BaseMaterial3D.TEXTURE_ROUGHNESS))
		_female_material.set_shader_parameter("albedo_color",_male_material.albedo_color)
		_female_material.set_shader_parameter("normal_strength",_male_material.normal_scale)
		_female_material.set_shader_parameter("roughness_factor",_male_material.roughness)
		_female_material.set_shader_parameter("specular_amount",_male_material.metallic_specular)
	_body.set_surface_override_material(0,_female_material if value == 1 else _male_material)
