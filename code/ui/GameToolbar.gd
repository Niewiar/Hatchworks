extends Control

@export var map_manager : MapManager

@onready var _paint_buttons_content: HBoxContainer = %PaintButtons
@onready var _base_buttons_content: HBoxContainer = %BaseButtons


func _ready() -> void:
	_paint_buttons_content.hide()
	_setup_base_buttons()
	_setup_paint_buttons()

func _setup_base_buttons():
	var i: int = 1
	for ch in _base_buttons_content.get_children():
		var b = ch as CheckButton
		b.pressed.connect(_on_base_button_toggled.bind(b,i))
		i = i + 1

func _on_base_button_toggled(b: CheckButton, mode: MapManager.MODE) -> void:
	if b.button_pressed:
		map_manager.set_mode(mode)
		match mode:
			MapManager.MODE.PAINT:
				_on_paint_buttons_show()
				_paint_buttons_content.show()
			MapManager.MODE.BUILD:
				_paint_buttons_content.hide()
	else:
		map_manager.set_mode(MapManager.MODE.NONE)
		_paint_buttons_content.hide()
	
	for ch in _base_buttons_content.get_children():
		var b1 := ch as CheckButton
		b1.button_pressed = b1 == b

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
