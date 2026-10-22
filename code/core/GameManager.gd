extends Node

func _ready() -> void:
	InputManager.on_esc.connect(_on_esc)
	
func _on_esc():
	get_tree().quit()
