extends Node3D

func _enter_tree() -> void:
	var map := get_node("Map") as MapManager
	if map.database == null:
		map.database = load(GameDatabase.DEFAULT_PATH) as GameDatabase
	if GameManager.validate_database(map.database):
		return
	for child: Node in get_children():
		remove_child(child)
		child.free()
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
