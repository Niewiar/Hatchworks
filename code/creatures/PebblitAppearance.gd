@tool
class_name PebblitAppearance
extends CreatureCelAppearance

@export var female := false
@export_range(0.01, 5.0, 0.001) var run_distance := 0.24276

func _ready() -> void:
	super._ready()
	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return
	for clip in player.get_animation_list():
		player.get_animation(clip).loop_mode = Animation.LOOP_NONE if clip in [&"Headbutt", &"Land", &"ShakeSand", &"Attack", &"Work"] else Animation.LOOP_LINEAR
