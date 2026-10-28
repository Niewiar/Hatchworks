extends Control

@export var map_manager: MapManager
@export var tooltip_controller: TooltipController
@export var region_tooltip: RegionTooltip

@onready var _paint_buttons_content: HBoxContainer = %PaintButtons
@onready var _base_buttons_content: HBoxContainer = %BaseButtons
@onready var _constructions_buttons_content: HBoxContainer = %ConstructionsButtons
@onready var _gather_buttons_content: HBoxContainer = %GatherButtons
@onready var _build_cost: Label = $VBoxContainer/BuildCost
@onready var _sculpt_buttons_content: HBoxContainer = %SculptButtons

func _ready() -> void:
	_paint_buttons_content.hide()
	_constructions_buttons_content.hide()
	_sculpt_buttons_content.hide()
	_gather_buttons_content.hide()
	_build_cost.hide()
	_setup_base_buttons()
	_setup_paint_buttons()
	_setup_fence_buttons()
	_setup_sculpt_buttons()
	_setup_gather_buttons()
	map_manager.inventory.changed.connect(_on_resource_changed)
	map_manager.fances_controller.preview_cost_changed.connect(_on_fence_cost_changed)
	_refresh_amounts()
	map_manager.regions_controller.region_hovered.connect(_on_region_hovered)
	for container in [_base_buttons_content, _paint_buttons_content, _constructions_buttons_content, _sculpt_buttons_content, _gather_buttons_content]:
		for button: CheckButton in container.get_children():
			button.mouse_entered.connect(_on_button_hovered.bind(button))
			button.mouse_exited.connect(tooltip_controller.hide_text.bind(button))

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
	_gather_buttons_content.visible = active and mode == MapManager.MODE.HARVEST
	_build_cost.visible = active and mode == MapManager.MODE.FANCE
	if _paint_buttons_content.visible:
		_on_paint_buttons_show()
	for other: CheckButton in _base_buttons_content.get_children():
		other.set_pressed_no_signal(active and other == button)

func _setup_fence_buttons() -> void:
	var entries := map_manager.database.construction.fances
	var template := _constructions_buttons_content.get_child(0) as CheckButton
	while _constructions_buttons_content.get_child_count() < entries.size():
		_constructions_buttons_content.add_child(template.duplicate())
	for index in _constructions_buttons_content.get_child_count():
		var button := _constructions_buttons_content.get_child(index) as CheckButton
		button.visible = index < entries.size()
		if index < entries.size():
			button.set_meta("fence_index",index)
			button.set_meta("tooltip_title",entries[index].display_name)
			button.get_node("TextureRect").texture = entries[index].ui_icon
	for button: CheckButton in _constructions_buttons_content.get_children():
		var index: int = button.get_meta("fence_index")
		button.pressed.connect(_on_fence_selected.bind(index))

func _on_fence_selected(index: int) -> void:
	map_manager.select_fence(index)
	for button: CheckButton in _constructions_buttons_content.get_children():
		button.set_pressed_no_signal(int(button.get_meta("fence_index", -1)) == index)

func _on_paint_buttons_show() -> void:
	for button: CheckButton in _paint_buttons_content.get_children():
		button.set_pressed_no_signal(map_manager.selected_material == int(button.get_meta("material_index")))

func _setup_paint_buttons() -> void:
	for button: CheckButton in _paint_buttons_content.get_children():
		var data := map_manager.inventory.definition(int(button.get_meta("material_index")))
		if data != null:
			button.set_meta("tooltip_title",data.display_name)
			button.get_node("TextureRect").texture = data.icon
		button.pressed.connect(_on_change_paint.bind(int(button.get_meta("material_index"))))

func _on_change_paint(index: int) -> void:
	map_manager.selected_material = index
	_on_paint_buttons_show()

func _on_button_hovered(button: CheckButton) -> void:
	var title: String = button.get_meta("tooltip_title",button.name)
	if button.get_parent() == _paint_buttons_content:
		title += " · %s m² available" % map_manager.inventory.quantity_text(int(button.get_meta("material_index")))
	tooltip_controller.show_text(title,button)

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

func _setup_gather_buttons() -> void:
	for button: CheckButton in _gather_buttons_content.get_children():
		button.pressed.connect(_on_gather_selected.bind(int(button.get_meta("harvest_tool"))))

func _on_gather_selected(tool: HarvestController.TOOL) -> void:
	map_manager.select_harvest_tool(tool)

func _on_resource_changed(_kind: int, _amount: float) -> void:
	_refresh_amounts()

func _refresh_amounts() -> void:
	for button: CheckButton in _paint_buttons_content.get_children():
		var index: int = button.get_meta("material_index")
		var amount := button.get_node("Amount") as Label
		amount.text = map_manager.inventory.quantity_text(index)
		amount.modulate = Color(1,0.48,0.35) if map_manager.inventory.amount(index) < 0.05 else Color.WHITE

func _on_fence_cost_changed(kind: int, cost: int, affordable: bool) -> void:
	_build_cost.text = "Draw a fence to see its cost" if cost == 0 else "%s: %d needed · %s available" % [map_manager.inventory.resource_name(kind),cost,map_manager.inventory.quantity_text(kind)]
	_build_cost.modulate = Color.WHITE if affordable or cost == 0 else Color(1,0.48,0.35)
