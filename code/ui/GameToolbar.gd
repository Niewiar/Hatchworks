extends Control

@export var map_manager: MapManager
@export var tooltip_controller: TooltipController
@export var build_button_group: ButtonGroup

const BUILD_CHOICE = preload("res://scenes/ui/build_choice.tscn")

@onready var _building_buttons_content: HBoxContainer = %BuildingButtons
@onready var _base_buttons_content: HBoxContainer = %BaseButtons
@onready var _gather_buttons_content: HBoxContainer = %GatherButtons
@onready var _build_cost: RichTextLabel = $VBoxContainer/BuildCost
@onready var _sculpt_buttons_content: HBoxContainer = %SculptButtons

var _mode: MapManager.MODE = MapManager.MODE.NONE
var _fence_cost := 0
var _fence_resource: int = ResourceInventory.KIND.WOOD
var _presented_items: Dictionary[StringName,bool] = {}
var _rewards: Node

func _ready() -> void:
	_setup_building_buttons()
	map_manager.new_content.changed.connect(_refresh_badges)
	_rewards = get_parent().get_node_or_null("Rewards")
	if _rewards != null:
		_rewards.connect("item_arrived",_on_item_arrived)
		_rewards.connect("presentation_reset",_on_presentation_reset)
	for button: CheckButton in _base_buttons_content.get_children():
		button.pressed.connect(_on_base_button_toggled.bind(button,int(button.get_meta("mode"))))
	for button: CheckButton in _sculpt_buttons_content.get_children():
		button.pressed.connect(_on_sculpt_selected.bind(int(button.get_meta("sculpt_tool"))))
	for button: CheckButton in _gather_buttons_content.get_children():
		button.pressed.connect(_on_gather_selected.bind(int(button.get_meta("harvest_tool"))))
	for container in [_building_buttons_content,_base_buttons_content,_sculpt_buttons_content,_gather_buttons_content]:
		for button: CheckButton in container.get_children():
			button.mouse_entered.connect(_on_button_hovered.bind(button))
			button.mouse_exited.connect(tooltip_controller.hide_text.bind(button))
	map_manager.fances_controller.preview_cost_changed.connect(_on_fence_cost_changed)
	map_manager.mode_changed.connect(_on_mode_changed)
	map_manager.inventory.changed.connect(_on_inventory_changed)
	map_manager.items.changed.connect(_refresh_building_cost)
	map_manager.planting_controller.preview_changed.connect(_refresh_building_cost)
	map_manager.discoveries.discovered.connect(_on_discovered)
	map_manager.building_controller.preview_changed.connect(_on_build_preview_changed)
	map_manager.building_controller.selection_changed.connect(_on_building_selection_changed)
	_refresh_unlocks()
	_on_mode_changed(MapManager.MODE.NONE)
	_refresh_badges()

func _setup_building_buttons() -> void:
	for index in map_manager.database.buildings.size():
		var data := map_manager.database.buildings[index]
		var button := _build_choice(data.display_name,data.icon)
		button.set_meta("building_index",index)
		button.pressed.connect(_on_building_selected.bind(index))
	for index in map_manager.database.construction.fances.size():
		var data := map_manager.database.construction.fances[index]
		var button := _build_choice(data.display_name,data.ui_icon)
		button.set_meta("fence_index",index)
		button.pressed.connect(_on_fence_selected.bind(index))

func _build_choice(title: String, icon: Texture2D) -> CheckButton:
	var button := BUILD_CHOICE.instantiate() as CheckButton
	button.name = title.to_pascal_case()
	button.button_group = build_button_group
	button.set_meta("tooltip_title",title)
	button.get_node("TextureRect").texture = icon
	_building_buttons_content.add_child(button)
	return button

func _on_base_button_toggled(button: CheckButton, mode: MapManager.MODE) -> void:
	if not button.button_pressed:
		map_manager.set_mode(MapManager.MODE.NONE)
	elif mode == MapManager.MODE.BUILD and _mode == MapManager.MODE.FANCE:
		map_manager.set_mode(MapManager.MODE.FANCE)
	else:
		map_manager.set_mode(mode)

func _on_mode_changed(mode: MapManager.MODE) -> void:
	_mode = mode
	if mode == MapManager.MODE.DISCOVERIES:
		$DiscoveryFlash.stop()
		%DiscoveriesButton.modulate = Color.WHITE
	_building_buttons_content.visible = mode in [MapManager.MODE.BUILD,MapManager.MODE.FANCE]
	_sculpt_buttons_content.visible = mode == MapManager.MODE.SCULPT
	_gather_buttons_content.visible = mode == MapManager.MODE.HARVEST
	var base_mode := MapManager.MODE.BUILD if mode in [MapManager.MODE.FANCE,MapManager.MODE.PLANT] else mode
	for other: CheckButton in _base_buttons_content.get_children():
		other.set_pressed_no_signal(int(other.get_meta("mode")) == base_mode)
	_sync_building_selection()
	_refresh_building_cost()
	_refresh_badges()

func _on_building_selected(index: int) -> void:
	map_manager.new_content.mark_building_seen(map_manager.database.buildings[index].id)
	map_manager.building_controller.select_building(index)
	map_manager.set_mode(MapManager.MODE.BUILD)

func _on_fence_selected(index: int) -> void:
	if not map_manager.fances_controller.unlocked(index):
		return
	map_manager.new_content.mark_fence_seen(map_manager.database.construction.fances[index].id)
	map_manager.select_fence(index)
	map_manager.set_mode(MapManager.MODE.FANCE)

func _on_building_selection_changed(_index: int) -> void:
	_sync_building_selection()
	_refresh_building_cost()

func _sync_building_selection() -> void:
	for button: CheckButton in _building_buttons_content.get_children():
		var selected := false
		if button.has_meta("fence_index"):
			selected = _mode == MapManager.MODE.FANCE and int(button.get_meta("fence_index")) == map_manager.fances_controller.selected_fance
		else:
			selected = _mode != MapManager.MODE.FANCE and int(button.get_meta("building_index")) == map_manager.building_controller.selected_building
		button.set_pressed_no_signal(selected and button.visible)

func _on_inventory_changed(_kind: int, _amount: float) -> void:
	_refresh_building_cost()

func _on_build_preview_changed(_valid: bool, _reason: String) -> void:
	_refresh_building_cost()

func _refresh_building_cost() -> void:
	if _mode == MapManager.MODE.PLANT and map_manager.planting_controller.selected != null:
		var plant := map_manager.planting_controller.selected
		_set_build_cost("%d/1 %s" % [map_manager.items.amount(plant.sapling_item),plant.display_name])
		return
	if _mode == MapManager.MODE.FANCE:
		_set_build_cost(_resource_cost(_fence_resource,_fence_cost) if _fence_cost > 0 else "")
		return
	if _mode != MapManager.MODE.BUILD:
		_set_build_cost("")
		return
	var data := map_manager.building_controller.definition()
	if data == null or not map_manager.building_controller.unlocked(data):
		_set_build_cost("")
		return
	var parts := PackedStringArray()
	var costs := data.costs()
	for kind: int in costs:
		if costs[kind] > 0:
			parts.append(_resource_cost(kind,costs[kind]))
	_set_build_cost("   ".join(parts) if not parts.is_empty() else tr("Free"))

func _resource_cost(kind: int, cost: int) -> String:
	var color := "#ffffff" if map_manager.inventory.can_afford(kind,cost) else "#f45e4b"
	return "[color=%s]%s/%d %s[/color]" % [color,map_manager.inventory.quantity_text(kind),cost,map_manager.inventory.resource_name(kind)]

func _set_build_cost(text: String) -> void:
	_build_cost.text = text
	_build_cost.visible = not text.is_empty()

func _on_fence_cost_changed(kind: int, cost: int, _affordable: bool) -> void:
	_fence_resource = kind
	_fence_cost = cost
	if _mode == MapManager.MODE.FANCE:
		_refresh_building_cost()

func _on_button_hovered(button: CheckButton) -> void:
	var title := str(button.get_meta("tooltip_title",button.name))
	if button.has_meta("building_index"):
		title = map_manager.database.buildings[int(button.get_meta("building_index"))].display_name
	elif button.has_meta("fence_index"):
		title = map_manager.database.construction.fances[int(button.get_meta("fence_index"))].display_name
	if button.has_meta("building_index"):
		map_manager.new_content.mark_building_seen(map_manager.database.buildings[int(button.get_meta("building_index"))].id)
	elif button.has_meta("fence_index"):
		map_manager.new_content.mark_fence_seen(map_manager.database.construction.fances[int(button.get_meta("fence_index"))].id)
	elif button.has_meta("sculpt_tool"):
		map_manager.new_content.mark_tool_seen(MapManager.MODE.SCULPT,int(button.get_meta("sculpt_tool")))
	elif button.has_meta("harvest_tool"):
		map_manager.new_content.mark_tool_seen(MapManager.MODE.HARVEST,int(button.get_meta("harvest_tool")))
	tooltip_controller.show_text(tr(title),button)

func _on_sculpt_selected(index: TerrainController.SCULPT_TOOL) -> void:
	map_manager.new_content.mark_tool_seen(MapManager.MODE.SCULPT,index)
	map_manager.select_sculpt_tool(index)

func _on_gather_selected(tool: HarvestController.TOOL) -> void:
	map_manager.new_content.mark_tool_seen(MapManager.MODE.HARVEST,tool)
	map_manager.select_harvest_tool(tool)

func _refresh_unlocks() -> void:
	for button: CheckButton in _building_buttons_content.get_children():
		if button.has_meta("fence_index"):
			button.visible = map_manager.fances_controller.unlocked(int(button.get_meta("fence_index")))
		else:
			button.visible = map_manager.building_controller.unlocked(map_manager.database.buildings[int(button.get_meta("building_index"))])
	_sync_building_selection()
	_refresh_building_cost()

func _on_discovered(_entry: DiscoveryDefinition) -> void:
	_refresh_unlocks()
	_refresh_badges()

func backpack_anchor() -> Control:
	return %InventoryButton.get_node("TextureRect")

func _on_item_arrived(id: StringName) -> void:
	_presented_items[id] = true
	_refresh_badges()

func _on_presentation_reset() -> void:
	_presented_items.clear()
	_refresh_badges()

func _refresh_badges() -> void:
	for button: CheckButton in _base_buttons_content.get_children():
		var mode: MapManager.MODE = int(button.get_meta("mode"))
		var count := map_manager.new_content.unread_count(mode)
		if mode == MapManager.MODE.BACKPACK:
			for id: StringName in map_manager.new_content.unread_item_ids():
				if _rewards != null and _rewards.item_in_transit(id) and not _presented_items.has(id):
					count -= 1
		button.get_node("NewContent").set_count(count)
	for button: CheckButton in _building_buttons_content.get_children():
		var unread := map_manager.new_content.fence_is_unread(map_manager.database.construction.fances[int(button.get_meta("fence_index"))].id) if button.has_meta("fence_index") else map_manager.new_content.building_is_unread(map_manager.database.buildings[int(button.get_meta("building_index"))].id)
		button.get_node("NewContent").set_count(1 if unread and button.visible else 0)
	for button: CheckButton in _sculpt_buttons_content.get_children():
		button.get_node("NewContent").set_count(1 if map_manager.new_content.tool_is_unread(MapManager.MODE.SCULPT,int(button.get_meta("sculpt_tool"))) else 0)
	for button: CheckButton in _gather_buttons_content.get_children():
		button.get_node("NewContent").set_count(1 if map_manager.new_content.tool_is_unread(MapManager.MODE.HARVEST,int(button.get_meta("harvest_tool"))) else 0)
	if map_manager.new_content.unread_count(MapManager.MODE.DISCOVERIES) > 0 and _mode != MapManager.MODE.DISCOVERIES:
		if not $DiscoveryFlash.is_playing():
			$DiscoveryFlash.play(&"new_discovery")
	else:
		$DiscoveryFlash.stop()
		%DiscoveriesButton.modulate = Color.WHITE

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_building_cost()
