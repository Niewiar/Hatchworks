extends Control

@export var map_manager: MapManager
@export var tooltip_controller: TooltipController

@onready var _building_buttons_content: HBoxContainer = %BuildingButtons
@onready var _base_buttons_content: HBoxContainer = %BaseButtons
@onready var _constructions_buttons_content: HBoxContainer = %ConstructionsButtons
@onready var _gather_buttons_content: HBoxContainer = %GatherButtons
@onready var _build_cost: Label = $VBoxContainer/BuildCost
@onready var _sculpt_buttons_content: HBoxContainer = %SculptButtons

var _mode: MapManager.MODE = MapManager.MODE.NONE
var _unread_discoveries: Array[DiscoveryDefinition] = []

func _ready() -> void:
	_building_buttons_content.hide()
	_constructions_buttons_content.hide()
	_sculpt_buttons_content.hide()
	_gather_buttons_content.hide()
	_build_cost.hide()
	_setup_base_buttons()
	_setup_building_buttons()
	_setup_fence_buttons()
	_setup_sculpt_buttons()
	_setup_gather_buttons()
	map_manager.fances_controller.preview_cost_changed.connect(_on_fence_cost_changed)
	map_manager.mode_changed.connect(_on_mode_changed)
	map_manager.inventory.changed.connect(_on_inventory_changed)
	map_manager.items.changed.connect(_refresh_building_cost)
	map_manager.discoveries.discovered.connect(_on_discovered)
	map_manager.building_controller.preview_changed.connect(_on_build_preview_changed)
	map_manager.building_controller.selection_changed.connect(_on_building_selection_changed)
	_refresh_unlocks()
	_on_mode_changed(MapManager.MODE.NONE)
	if map_manager.discoveries.knows(&"soil"):
		_on_discovered(map_manager.database.discovery(&"soil"))
	for container in [_building_buttons_content, _base_buttons_content, _constructions_buttons_content, _sculpt_buttons_content, _gather_buttons_content]:
		for button: CheckButton in container.get_children():
			button.mouse_entered.connect(_on_button_hovered.bind(button))
			button.mouse_exited.connect(tooltip_controller.hide_text.bind(button))

func _setup_base_buttons() -> void:
	for button: CheckButton in _base_buttons_content.get_children():
		var mode: MapManager.MODE = button.get_meta("mode")
		button.pressed.connect(_on_base_button_toggled.bind(button, mode))

func _on_base_button_toggled(button: CheckButton, mode: MapManager.MODE) -> void:
	map_manager.set_mode(mode if button.button_pressed else MapManager.MODE.NONE)

func _on_mode_changed(mode: MapManager.MODE) -> void:
	_mode = mode
	if mode == MapManager.MODE.DISCOVERIES:
		_unread_discoveries.clear()
		$DiscoveryFlash.stop()
		%DiscoveriesButton.modulate = Color.WHITE
	_building_buttons_content.visible = mode == MapManager.MODE.BUILD
	_constructions_buttons_content.visible = mode == MapManager.MODE.FANCE
	_sculpt_buttons_content.visible = mode == MapManager.MODE.SCULPT
	_gather_buttons_content.visible = mode == MapManager.MODE.HARVEST
	_build_cost.visible = mode == MapManager.MODE.FANCE or mode == MapManager.MODE.BUILD
	for other: CheckButton in _base_buttons_content.get_children():
		other.set_pressed_no_signal(int(other.get_meta("mode")) == mode)
	if mode == MapManager.MODE.BUILD:
		_refresh_building_cost()
	elif mode == MapManager.MODE.FANCE:
		_build_cost.text = "Draw a fence to see its cost"
		_build_cost.modulate = Color.WHITE

func _setup_building_buttons() -> void:
	var entries := map_manager.database.buildings
	var template := _building_buttons_content.get_child(0) as CheckButton
	while _building_buttons_content.get_child_count() < entries.size():
		_building_buttons_content.add_child(template.duplicate())
	for index in _building_buttons_content.get_child_count():
		var button := _building_buttons_content.get_child(index) as CheckButton
		button.visible = index < entries.size()
		if index < entries.size():
			button.set_meta("building_index",index)
			button.set_meta("tooltip_title",entries[index].display_name)
			button.get_node("TextureRect").texture = entries[index].icon
			button.pressed.connect(_on_building_selected.bind(index))
			button.set_pressed_no_signal(index == map_manager.building_controller.selected_building)

func _on_building_selected(index: int) -> void:
	map_manager.building_controller.select_building(index)

func _on_building_selection_changed(index: int) -> void:
	for button: CheckButton in _building_buttons_content.get_children():
		button.set_pressed_no_signal(int(button.get_meta("building_index",-1)) == index)
	_refresh_building_cost()

func _on_inventory_changed(_kind: int, _amount: float) -> void:
	_refresh_building_cost()

func _on_build_preview_changed(_valid: bool, _reason: String) -> void:
	_refresh_building_cost()

func _refresh_building_cost() -> void:
	if _mode != MapManager.MODE.BUILD:
		return
	var data := map_manager.building_controller.definition()
	if data == null:
		_build_cost.text = "No building selected"
		return
	var parts := PackedStringArray()
	for kind: int in data.costs():
		var cost: int = data.costs()[kind]
		if cost > 0:
			parts.append("%s: %d needed / %s available" % [map_manager.inventory.resource_name(kind),cost,map_manager.inventory.quantity_text(kind)])
	_build_cost.text = "Construction kit: %d available" % map_manager.items.amount(data.kit_item) if map_manager.building_controller.has_kit(data) else " · ".join(parts)
	if not map_manager.building_controller.preview_error.is_empty():
		_build_cost.text += "\n"+map_manager.building_controller.preview_error
	_build_cost.modulate = Color.WHITE if map_manager.building_controller.has_kit(data) or map_manager.inventory.can_afford_costs(data.costs()) else Color(1,0.48,0.35)

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

func _on_button_hovered(button: CheckButton) -> void:
	var title: String = button.get_meta("tooltip_title",button.name)
	tooltip_controller.show_text(title,button)

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

func _on_fence_cost_changed(kind: int, cost: int, affordable: bool) -> void:
	if _mode != MapManager.MODE.FANCE:
		return
	_build_cost.text = "Draw a fence to see its cost" if cost == 0 else "%s: %d needed · %s available" % [map_manager.inventory.resource_name(kind),cost,map_manager.inventory.quantity_text(kind)]
	_build_cost.modulate = Color.WHITE if affordable or cost == 0 else Color(1,0.48,0.35)

func _refresh_unlocks() -> void:
	for button: CheckButton in _building_buttons_content.get_children():
		var index: int = button.get_meta("building_index",-1)
		if index >= 0 and index < map_manager.database.buildings.size():
			button.disabled = not map_manager.building_controller.unlocked(map_manager.database.buildings[index])
			button.modulate = Color(0.65,0.65,0.65,1) if button.disabled else Color.WHITE
	_refresh_building_cost()

func _on_discovered(entry: DiscoveryDefinition) -> void:
	_refresh_unlocks()
	if _mode == MapManager.MODE.DISCOVERIES or entry == null:
		return
	if not _unread_discoveries.has(entry):
		_unread_discoveries.append(entry)
	$DiscoveryFlash.play(&"new_discovery")
