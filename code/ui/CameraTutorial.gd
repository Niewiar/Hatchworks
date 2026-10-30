class_name CameraTutorial
extends MarginContainer

@export var map_manager: MapManager

var step := 0
var _focused := false
var _movement := 0.0
var _rotation := 0.0

func _ready() -> void:
	if map_manager == null or map_manager.camera_controller == null:
		hide()
		return
	map_manager.camera_controller.moved.connect(_on_moved)
	map_manager.camera_controller.rotated.connect(_on_rotated)
	map_manager.mode_changed.connect(_on_mode_changed)
	map_manager.modal_changed.connect(_on_modal_changed)
	map_manager.camera_controller.focus_changed.connect(_on_focus_changed)
	_refresh()

func restore_step(value: int) -> void:
	step = clampi(value,0,2)
	_movement = 0.0
	_rotation = 0.0
	_refresh()

func _on_moved(distance: float) -> void:
	if step != 0:
		return
	_movement += distance
	if _movement >= 0.8:
		step = 1
		_refresh()

func _on_rotated(angle: float) -> void:
	if step != 1:
		return
	_rotation += absf(angle)
	if _rotation >= 0.25:
		step = 2
		_refresh()

func _on_mode_changed(_mode: MapManager.MODE) -> void:
	_refresh()

func _on_modal_changed(_active: bool) -> void:
	_refresh()

func _on_focus_changed(active: bool) -> void:
	_focused = active
	_refresh()

func _refresh() -> void:
	visible = step < 2 and not _focused and map_manager != null and not map_manager.modal_active
	$Panel/Padding/Steps/Move.visible = step == 0
	$Panel/Padding/Steps/Rotate.visible = step == 1
