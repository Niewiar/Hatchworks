extends Control

@export var map_manager : MapManager

@onready var _paint_buttons_content: HBoxContainer = %PaintButtons
@onready var _base_buttons_content: HBoxContainer = %BaseButtons
@onready var _constructions_buttons_content: HBoxContainer = %ConstructionsButtons

func _ready() -> void:
	_paint_buttons_content.hide()
	_constructions_buttons_content.hide()
	_setup_base_buttons()
	_setup_paint_buttons()
	_setup_fence_buttons()

func _setup_base_buttons():
	var i: int = 1
	for ch in _base_buttons_content.get_children():
		var b = ch as CheckButton
		b.pressed.connect(_on_base_button_toggled.bind(b,i))
		i = i + 1

func _on_base_button_toggled(b: CheckButton, mode: MapManager.MODE) -> void:
	var active := b.button_pressed
	if active:
		map_manager.set_mode(mode)
		match mode:
			MapManager.MODE.PAINT:
				_on_paint_buttons_show()
				_paint_buttons_content.show()
				_constructions_buttons_content.hide()
			MapManager.MODE.FANCE:
				_paint_buttons_content.hide()
				_constructions_buttons_content.show()
	else:
		map_manager.set_mode(MapManager.MODE.NONE)
		_paint_buttons_content.hide()
		_constructions_buttons_content.hide()
	
	for ch in _base_buttons_content.get_children():
		var b1 := ch as CheckButton
		b1.set_pressed_no_signal(active and b1 == b)

func _setup_fence_buttons() -> void:
	for child in _constructions_buttons_content.get_children():
		var button := child as CheckButton
		if button == null or not button.has_meta("fence_index"):
			continue
		var index: int = button.get_meta("fence_index")
		button.pressed.connect(_on_fence_selected.bind(index))

func _on_fence_selected(index: int) -> void:
	map_manager.select_fence(index)
	for child in _constructions_buttons_content.get_children():
		var button := child as CheckButton
		if button != null:
			button.set_pressed_no_signal(int(button.get_meta("fence_index", -1)) == index)

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
