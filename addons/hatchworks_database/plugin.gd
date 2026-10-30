@tool
extends EditorPlugin

const PANEL := preload("res://addons/hatchworks_database/database_panel.tscn")
var _panel: Control

func _enter_tree() -> void:
	_panel = PANEL.instantiate()
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_panel.configure(get_undo_redo())
	_panel.hide()
	add_tool_menu_item("Hatchworks Database",_open_database)
	add_tool_menu_item("Discovery Graph",_open_graph)

func _exit_tree() -> void:
	remove_tool_menu_item("Hatchworks Database")
	remove_tool_menu_item("Discovery Graph")
	if is_instance_valid(_panel):
		_panel.queue_free()

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if is_instance_valid(_panel):
		_panel.visible = visible

func _get_plugin_name() -> String:
	return "Database"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("FileList","EditorIcons")

func _open_database() -> void:
	EditorInterface.set_main_screen_editor("Database")

func _save_external_data() -> void:
	if is_instance_valid(_panel):
		_panel.save_all()

func _open_graph() -> void:
	_open_database()
	_panel.open_discovery_graph()
