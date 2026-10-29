extends Node

func _ready() -> void:
	InputManager.on_esc.connect(_on_esc)
	
func _on_esc():
	var scene := get_tree().current_scene
	var map := scene.get_node_or_null("Map") as MapManager if scene != null else null
	if map == null or not map.cancel_action():
		get_tree().quit()
