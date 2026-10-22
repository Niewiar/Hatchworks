@tool
extends EditorPlugin

const CreatorWindow = preload("atlas_creator_window.tscn")
var _window: Window


func _enter_tree() -> void:
	add_tool_menu_item("Atlas Creator", _open_window)


func _exit_tree() -> void:
	remove_tool_menu_item("Atlas Creator")
	if is_instance_valid(_window):
		_window.queue_free()
	_window = null


func _open_window() -> void:
	if not is_instance_valid(_window):
		_window = CreatorWindow.instantiate()
		_window.connect("asset_saved", _on_asset_saved)
		get_editor_interface().get_base_control().add_child(_window)
	_window.popup_centered_clamped(Vector2i(820, 700), 0.85)


func _on_asset_saved(path: String) -> void:
	if ProjectSettings.localize_path(path).begins_with("res://"):
		get_editor_interface().get_resource_filesystem().scan()
