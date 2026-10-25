extends Control

@export var map_manager : MapManager

@onready var _paint_buttons_content: HBoxContainer = %PaintButtons

func _ready() -> void:
	_paint_buttons_content.hide()
	_setup_paint_buttons()

func _on_paint_button_toggled(toggled_on: bool) -> void:
	map_manager.active_painting_mode(toggled_on)
	if toggled_on:
		_on_paint_buttons_show()
		_paint_buttons_content.show()
	else:
		_paint_buttons_content.hide()

func _on_paint_buttons_show():
	var i : int = 0
	for child in _paint_buttons_content.get_children(false):
		var b = child as CheckButton
		b.button_pressed = map_manager.selected_material == i
		i = i + 1

func _setup_paint_buttons():
	var i : int = 0
	for child in _paint_buttons_content.get_children(false):
		var b := child as CheckButton
		b.pressed.connect(_on_change_paint.bind(i))
		i = i + 1

func _on_change_paint(index: int):
	map_manager.selected_material = index
	_on_paint_buttons_show()
