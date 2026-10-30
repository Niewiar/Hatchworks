class_name WorkshopPanel
extends VBoxContainer

var _target: WorkshopController
var _map: Node3D
var _ids: Array[StringName] = []
var _signature := ""

func _ready() -> void:
	%Recipe.item_selected.connect(_select_recipe)
	%Craft.pressed.connect(_on_action)

func configure(target: WorkshopController, map: Node3D) -> void:
	_target = target
	_map = map
	_signature = ""
	refresh()

func refresh() -> void:
	var ids: Array[StringName] = []
	for egg: EggDefinition in _map.database.eggs:
		if _map.discoveries.knows(egg.id):
			ids.append(egg.id)
	var signature := str(ids)
	if signature != _signature:
		_signature = signature
		_ids = ids
		%Recipe.clear()
		for id: StringName in ids:
			var egg: EggDefinition = _map.database.egg(id)
			var concept: DiscoveryDefinition = _map.database.discovery(id)
			%Recipe.add_icon_item(concept.icon,egg.display_name)
	if _target.current_egg == null and not ids.is_empty():
		_target.select_egg(_map.database.egg(ids[0]))
	var egg := _target.current_egg
	var idle := _target.state == WorkshopController.STATE.EMPTY
	%Recipe.visible = not ids.is_empty()
	%Recipe.disabled = not idle
	if egg != null and ids.has(egg.id):
		%Recipe.select(ids.find(egg.id))
	%Costs.visible = idle and egg != null
	%CraftProgress.visible = _target.state == WorkshopController.STATE.WORKING
	if egg != null:
		%CreationTime.text = tr("Creation: %.0f s") % egg.crafting_seconds
		for pair in [[%Fiber,ResourceInventory.KIND.FIBER],[%Wood,ResourceInventory.KIND.WOOD],[%Stone,ResourceInventory.KIND.STONE]]:
			var row := pair[0] as HBoxContainer
			var kind: int = pair[1]
			var cost: int = egg.costs()[kind]
			row.visible = cost > 0
			row.get_node("Quantity").text = "%d / %s" % [cost,_map.inventory.quantity_text(kind)]
			row.modulate = Color.WHITE if _map.inventory.can_afford(kind,cost) else Color(1,0.57,0.45)
		%ScienceCost.text = "%d / %d" % [egg.science_cost,_map.science.amount]
		%ScienceRow.modulate = Color.WHITE if _map.science.can_afford(egg.science_cost) else Color(1,0.57,0.45)
	else:
		%CreationTime.text = tr("Discover an egg recipe to begin.")
	match _target.state:
		WorkshopController.STATE.EMPTY:
			var error := _target.crafting_error()
			%CraftStatus.text = ""
			%Craft.text = tr("Create egg")
			%Craft.disabled = not error.is_empty()
		WorkshopController.STATE.WORKING:
			var progress := 1.0-_target.remaining/egg.crafting_seconds
			var stage := tr("Turning to the recipe") if progress < 0.16 else (tr("Preparing ingredients") if progress < 0.4 else (tr("Forming the shell") if progress < 0.86 else tr("Raising the press")))
			%CraftStatus.text = tr("%s\n%d s remaining") % [stage,ceili(_target.remaining)]
			%CraftProgress.value = progress*100.0
			%Craft.text = tr("Creating egg…")
			%Craft.disabled = true
		WorkshopController.STATE.READY:
			%CraftStatus.text = tr("Your egg is ready.")
			%Craft.text = tr("Collect egg")
			%Craft.disabled = false
	%CraftStatus.visible = not %CraftStatus.text.is_empty()

func _select_recipe(index: int) -> void:
	if index >= 0 and index < _ids.size():
		_target.select_egg(_map.database.egg(_ids[index]))
		refresh()

func _on_action() -> void:
	if _target.state == WorkshopController.STATE.EMPTY:
		_target.start_crafting()
	elif _target.state == WorkshopController.STATE.READY:
		_target.collect_egg(%Craft.get_global_rect().get_center())
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_signature = ""
		if is_instance_valid(_target):
			refresh()
