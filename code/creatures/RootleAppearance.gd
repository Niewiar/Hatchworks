class_name RootleAppearance
extends Node3D

const FEMALE_MODEL = preload("res://assets/creatures/rootle/rootle_female.glb")
static var _female_mesh: Mesh
static var _female_skin: Skin
var _sex := 0
var _body: MeshInstance3D
var _male_mesh: Mesh
var _male_skin: Skin

func _ready() -> void:
	var player := find_child("AnimationPlayer",true,false) as AnimationPlayer
	if player != null:
		for name in player.get_animation_list():
			player.get_animation(name).loop_mode = Animation.LOOP_NONE if name == "Land" else Animation.LOOP_LINEAR
		if not player.has_animation_library(&"behaviour"):
			var library := AnimationLibrary.new()
			for name in [&"Rest",&"Call"]:
				if player.has_animation(name):
					library.add_animation(name,player.get_animation(name))
			player.add_animation_library(&"behaviour",library)
	apply_sex(_sex)

func apply_sex(value: int) -> void:
	_sex = value
	if _body == null:
		_body = find_child("Rootle",true,false) as MeshInstance3D
		if _body == null:
			return
		_male_mesh = _body.mesh
		_male_skin = _body.skin
	if value == 1:
		if _female_mesh == null:
			var variant := FEMALE_MODEL.instantiate()
			var body := variant.find_child("Rootle",true,false) as MeshInstance3D
			if body != null:
				_female_mesh = body.mesh
				_female_skin = body.skin
			variant.free()
		if _female_mesh != null:
			_body.mesh = _female_mesh
			_body.skin = _female_skin
	else:
		_body.mesh = _male_mesh
		_body.skin = _male_skin
	for surface in _body.mesh.get_surface_count():
		var material := _body.mesh.surface_get_material(surface) as BaseMaterial3D
		if material != null:
			material.vertex_color_use_as_albedo = true
			material.vertex_color_is_srgb = false
