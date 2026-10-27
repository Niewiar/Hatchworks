extends Control

@export var map_manager: MapManager
@export var tooltip_controller: TooltipController
@export var region_tooltip: RegionTooltip

@onready var _paint_buttons_content: HBoxContainer = %PaintButtons
@onready var _base_buttons_content: HBoxContainer = %BaseButtons
@onready var _constructions_buttons_content: HBoxContainer = %ConstructionsButtons
@onready var _sculpt_buttons_content: HBoxContainer = %SculptButtons

func _ready() -> void:
	_paint_buttons_content.hide()
	_constructions_buttons_content.hide()
	_sculpt_buttons_content.hide()
	_setup_base_buttons()
	_setup_paint_buttons()
	_setup_fence_buttons()
	_setup_sculpt_buttons()
	map_manager.regions_controller.region_hovered.connect(_on_region_hovered)
	for container in [_base_buttons_content, _paint_buttons_content, _constructions_buttons_content, _sculpt_buttons_content]:
		for button: CheckButton in container.get_children():
			button.mouse_entered.connect(_on_button_hovered.bind(button))
			button.mouse_exited.connect(tooltip_controller.hide_text)

func _setup_base_buttons() -> void:
	for button: CheckButton in _base_buttons_content.get_children():
		var mode: MapManager.MODE = button.get_meta("mode")
		button.pressed.connect(_on_base_button_toggled.bind(button, mode))

func _on_base_button_toggled(button: CheckButton, mode: MapManager.MODE) -> void:
	var active := button.button_pressed
	map_manager.set_mode(mode if active else MapManager.MODE.NONE)
	_paint_buttons_content.visible = active and mode == MapManager.MODE.PAINT
	_constructions_buttons_content.visible = active and mode == MapManager.MODE.FANCE
	_sculpt_buttons_content.visible = active and mode == MapManager.MODE.SCULPT
	if _paint_buttons_content.visible:
		_on_paint_buttons_show()
	for other: CheckButton in _base_buttons_content.get_children():
		other.set_pressed_no_signal(active and other == button)

func _setup_fence_buttons() -> void:
	for button: CheckButton in _constructions_buttons_content.get_children():
		var index: int = button.get_meta("fence_index")
		button.pressed.connect(_on_fence_selected.bind(index))

func _on_fence_selected(index: int) -> void:
	map_manager.select_fence(index)
	for button: CheckButton in _constructions_buttons_content.get_children():
		button.set_pressed_no_signal(int(button.get_meta("fence_index", -1)) == index)

func _on_paint_buttons_show() -> void:
	for index in _paint_buttons_content.get_child_count():
		var button := _paint_buttons_content.get_child(index) as CheckButton
		button.set_pressed_no_signal(map_manager.selected_material == index)

func _setup_paint_buttons() -> void:
	for index in _paint_buttons_content.get_child_count():
		var button := _paint_buttons_content.get_child(index) as CheckButton
		button.pressed.connect(_on_change_paint.bind(index))

func _on_change_paint(index: int) -> void:
	map_manager.selected_material = index
	_on_paint_buttons_show()

func _on_button_hovered(button: CheckButton) -> void:
	tooltip_controller.show_text(button.get_meta("tooltip_title", button.name))

func _on_region_hovered(region: Region) -> void:
	if region == null:
		tooltip_controller.hide_tooltip(region_tooltip)
		return
	region_tooltip.set_region(region)
	tooltip_controller.show_tooltip(region_tooltip)

func _setup_sculpt_buttons() -> void:
	for button: CheckButton in _sculpt_buttons_content.get_children():
		var index: TerrainController.SCULPT_TOOL = button.get_meta("sculpt_tool")
		button.pressed.connect(_on_sculpt_selected.bind(index))

func _on_sculpt_selected(index: TerrainController.SCULPT_TOOL) -> void:
	map_manager.select_sculpt_tool(index)
