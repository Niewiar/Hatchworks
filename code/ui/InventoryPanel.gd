class_name InventoryPanel
extends Control

@export var map_manager: MapManager
@export var tooltip_controller: TooltipController

const SLOT = preload("res://scenes/ui/inventory_slot.tscn")

func _ready() -> void:
	hide()
	map_manager.mode_changed.connect(_mode_changed)
	map_manager.items.changed.connect(_refresh)
	map_manager.new_content.changed.connect(_refresh_badges)

func _mode_changed(mode: MapManager.MODE) -> void:
	visible = mode == MapManager.MODE.BACKPACK
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
	var ids: Array[StringName] = []
	for id: StringName in map_manager.items._amounts:
		if map_manager.items.amount(id) > 0:
			ids.append(id)
	ids.sort_custom(func(first: StringName, second: StringName): return str(map_manager.database.item_info(first).name).naturalnocasecmp_to(str(map_manager.database.item_info(second).name)) < 0)
	for id in ids:
		var info := map_manager.database.item_info(id)
		var slot := _add_slot(id,info.name,str(map_manager.items.amount(id)),info.icon,info.description)
		var data := map_manager.database.sapling(id)
		if data != null:
			var use := slot.get_node("Content/Use") as Button
			use.show()
			use.pressed.connect(_use_sapling.bind(data,id))
	%Empty.visible = ids.is_empty()
	%Scroll.visible = not ids.is_empty()

func _add_slot(id: StringName, title: String, quantity: String, icon: Texture2D, description: String) -> PanelContainer:
	var slot := SLOT.instantiate() as PanelContainer
	slot.set_meta("item_id",id)
	slot.get_node("Content/Header/Icon").texture = icon
	slot.get_node("Content/Header/Quantity").text = quantity
	slot.get_node("Content/Header/New").visible = map_manager.new_content.item_is_unread(id)
	slot.get_node("Content/Name").text = title
	slot.mouse_entered.connect(_on_slot_hovered.bind(slot,id,title,description))
	slot.mouse_exited.connect(tooltip_controller.hide_text.bind(slot))
	%Grid.add_child(slot)
	return slot

func _on_slot_hovered(slot: Control, id: StringName, title: String, description: String) -> void:
	map_manager.new_content.mark_item_seen(id)
	tooltip_controller.show_hint(title+"\n"+description,slot)

func _use_sapling(data: FloraSpecies, id: StringName) -> void:
	map_manager.new_content.mark_item_seen(id)
	map_manager.start_planting(data.id)

func _refresh_badges() -> void:
	if not visible:
		return
	for slot: Control in %Grid.get_children():
		var id := StringName(slot.get_meta("item_id",&""))
		slot.get_node("Content/Header/New").visible = map_manager.new_content.item_is_unread(id)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()
