class_name PebblitAppearance
extends Node3D

const FEMALE_STONE = preload("res://assets/creatures/pebblit/pebblit_female_albedo.png")
const MALE_STONE = preload("res://assets/creatures/pebblit/pebblit_male_albedo.png")
const STONE_NORMAL = preload("res://assets/creatures/pebblit/pebblit_normal.png")
const STONE_ROUGHNESS = preload("res://assets/creatures/pebblit/pebblit_roughness.png")

var _sex := 0
var _originals: Dictionary[MeshInstance3D,Array] = {}
var _female_materials: Dictionary[Material,Material] = {}

func _ready() -> void:
	var player := find_child("AnimationPlayer",true,false) as AnimationPlayer
	if player != null:
		for clip in [&"Idle",&"Walk",&"Eat",&"HeldIdle",&"Swim",&"Rest",&"Call",&"Roll"]:
			if player.has_animation(clip):
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		if not player.has_animation_library(&"behaviour"):
			var library := AnimationLibrary.new()
			for clip in [&"Rest",&"Call"]:
				if player.has_animation(clip):
					library.add_animation(clip,player.get_animation(clip))
			player.add_animation_library(&"behaviour",library)
		if player.has_animation(&"Idle"):
			player.play(&"Idle")
	apply_sex(_sex)

func apply_sex(value: int) -> void:
	_sex = value
	for node in find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.name.begins_with("Male_"):
			mesh.visible = value == 0
		elif mesh.name.begins_with("Female_"):
			mesh.visible = value == 1
		if not _originals.has(mesh):
			var materials: Array = []
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface)
				if material is BaseMaterial3D:
					material.vertex_color_use_as_albedo = true
					material.vertex_color_is_srgb = false
					if material.resource_name.begins_with("PebblitStone"):
						material.albedo_texture = MALE_STONE
						material.normal_enabled = true
						material.normal_texture = STONE_NORMAL
						material.normal_scale = 0.45
						material.roughness_texture = STONE_ROUGHNESS
						material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				materials.append(material)
			_originals[mesh] = materials
		for surface in _originals[mesh].size():
			var original := _originals[mesh][surface] as Material
			if original == null:
				continue
			if value == 0:
				mesh.set_surface_override_material(surface,original)
				continue
			if not _female_materials.has(original):
				var material := original.duplicate() as StandardMaterial3D
				if material == null:
					_female_materials[original] = original
					continue
				if original.resource_name.begins_with("PebblitStone"):
					material.albedo_texture = FEMALE_STONE
				elif original.resource_name.begins_with("AmberEyes"):
					material.albedo_color = Color(0.28,0.76,0.64)
					material.emission = Color(0.12,0.44,0.36)
				_female_materials[original] = material
			mesh.set_surface_override_material(surface,_female_materials[original])
