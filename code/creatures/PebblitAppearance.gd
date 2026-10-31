@tool
class_name PebblitAppearance
extends Node3D

@export var female := false

const FEMALE_MATERIALS = {
	"Basalt": preload("res://resources/creatures/pebblit_female_stone.tres"),
	"Charcoal": preload("res://resources/creatures/pebblit_female_skin.tres"),
	"Ivory": preload("res://resources/creatures/pebblit_female_ivory.tres"),
	"Amber": preload("res://resources/creatures/pebblit_female_eyes.tres"),
	"Sandlid": preload("res://resources/creatures/pebblit_female_eyelid.tres"),
	"Mouth": preload("res://resources/creatures/pebblit_female_mouth.tres"),
	"Sandgrain": preload("res://resources/creatures/pebblit_female_grain.tres")
}

const MATERIALS = {
	"Basalt": preload("res://resources/creatures/pebblit_stone.tres"),
	"Charcoal": preload("res://resources/creatures/pebblit_skin.tres"),
	"Ivory": preload("res://resources/creatures/pebblit_ivory.tres"),
	"Amber": preload("res://resources/creatures/pebblit_eyes.tres"),
	"Mouth": preload("res://resources/creatures/pebblit_mouth.tres"),
	"Obsidian": preload("res://resources/creatures/pebblit_black.tres"),
	"Drawn": preload("res://resources/creatures/pebblit_glint.tres")
}

func _ready() -> void:
	var materials: Dictionary = MATERIALS.merged(FEMALE_MATERIALS, true) if female else MATERIALS
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface)
			if original == null:
				continue
			for prefix: String in materials:
				if original.resource_name.begins_with(prefix):
					mesh.set_surface_override_material(surface, materials[prefix])
					break
	if Engine.is_editor_hint():
		return
	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		for clip in [&"Idle", &"Ride", &"Walk", &"Rub", &"HeldIdle", &"Fall", &"Rest", &"Call", &"Eat", &"Swim"]:
			if player.has_animation(clip):
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
