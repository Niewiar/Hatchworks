class_name InventoryPanel
extends Control

@export var map_manager: MapManager
@export var tooltip_controller: TooltipController

const SLOT = preload("res://scenes/ui/inventory_slot.tscn")

func _ready() -> void:
	hide()
	map_manager.mode_changed.connect(_mode_changed)
	map_manager.items.changed.connect(_refresh)
	map_manager.inventory.changed.connect(func(_kind,_amount): _refresh())

func _mode_changed(mode: MapManager.MODE) -> void:
	visible = mode == MapManager.MODE.INVENTORY
	if visible:
		_refresh()
	else:
		tooltip_controller.hide_tooltip()

func _refresh() -> void:
	if not visible:
		return
	tooltip_controller.hide_tooltip()
	for child in %Grid.get_children():
		%Grid.remove_child(child)
		child.queue_free()
	for resource: ResourceDefinition in map_manager.database.resources:
		_add_slot(resource.display_name,map_manager.inventory.quantity_text(resource.kind),resource.icon,resource.description)
	for egg: EggDefinition in map_manager.database.eggs:
		var count: int = map_manager.items.amount(egg.id)
		if count > 0:
			var info: Dictionary = map_manager.database.item_info(egg.id)
			_add_slot(info.name,str(count),info.icon,info.description)
	for building: BuildingDefinition in map_manager.database.buildings:
		if not building.kit_item.is_empty():
			var count: int = map_manager.items.amount(building.kit_item)
			if count > 0:
				var info: Dictionary = map_manager.database.item_info(building.kit_item)
				_add_slot(info.name,str(count),info.icon,info.description)

func _add_slot(title: String, quantity: String, icon: Texture2D, description: String) -> void:
	var slot := SLOT.instantiate() as PanelContainer
	slot.get_node("Content/Header/Icon").texture = icon
	slot.get_node("Content/Header/Quantity").text = quantity
	slot.get_node("Content/Name").text = title
	slot.mouse_entered.connect(func(): tooltip_controller.show_hint(title+"\n"+description,slot))
	slot.mouse_exited.connect(tooltip_controller.hide_text.bind(slot))
	%Grid.add_child(slot)
