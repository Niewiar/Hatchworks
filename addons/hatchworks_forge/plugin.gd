@tool
extends EditorPlugin

const WINDOW := preload("res://addons/hatchworks_forge/forge_window.tscn")
const ANIMATION_VIEWER := preload("res://addons/hatchworks_forge/creatures/animation_viewer.tscn")

var _window: Window
var _animation_viewer: Window

func _enter_tree() -> void:
	_window = WINDOW.instantiate()
	EditorInterface.get_base_control().add_child(_window)
	add_tool_menu_item("Hatchworks Forge",_open_forge)
	add_tool_menu_item("Hatchworks Animation Viewer",_open_animation_viewer)

func _exit_tree() -> void:
	remove_tool_menu_item("Hatchworks Forge")
	remove_tool_menu_item("Hatchworks Animation Viewer")
	if is_instance_valid(_window):
		_window.hide()
		_window.persist_draft()
		_window.queue_free()
	if is_instance_valid(_animation_viewer):
		_animation_viewer.hide()
		_animation_viewer.queue_free()

func _open_forge() -> void:
	if is_instance_valid(_window):
		_window.open_forge()

func _open_animation_viewer() -> void:
	if not is_instance_valid(_animation_viewer):
		_animation_viewer = ANIMATION_VIEWER.instantiate()
		EditorInterface.get_base_control().add_child(_animation_viewer)
	_animation_viewer.open_viewer()

func _save_external_data() -> void:
	if is_instance_valid(_window):
		_window.persist_draft()
