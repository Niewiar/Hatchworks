class_name InspectionPanel
extends Control

@export var map_manager: Node3D
@export var tooltip_controller: TooltipController

var target: Node3D
var focused := false
var _elapsed := 0.0
var _egg_ids: Array[StringName] = []
var _egg_signature := ""

func _ready() -> void:
	%Panel.hide()
	set_process(false)
	%Action.pressed.connect(_on_action)
	%Repair.pressed.connect(_repair_target)
	%EggChoice.item_selected.connect(_select_egg)
	%Close.pressed.connect(close_focus)
	%Description.meta_hover_started.connect(_show_term)
	%Description.meta_hover_ended.connect(func(_meta): tooltip_controller.hide_text(%Description))
	for stat in [%Satiety,%Happiness]:
		stat.mouse_entered.connect(_show_stat_hint.bind(stat))
		stat.mouse_exited.connect(tooltip_controller.hide_text.bind(stat))

func inspect(chosen: Node3D) -> void:
	if not is_instance_valid(chosen) or not (chosen is Creature or chosen is IncubatorController or chosen is FeederController or chosen is WorkshopController or chosen.has_method("structure_condition")):
		return
	if target != chosen:
		tooltip_controller.hide_tooltip()
	target = chosen
	focused = true
	_elapsed = 0.0
	%Panel.show()
	%CreatureCard.visible = chosen is Creature
	%Generic.visible = not chosen is Creature
	_egg_signature = ""
	%Workshop.visible = chosen is WorkshopController
	%Breeding.visible = chosen is Creature
	if chosen is WorkshopController:
		%Workshop.configure(chosen,map_manager)
	if chosen is Creature:
		%Breeding.configure(chosen,map_manager)
		%CreatureCard.configure(chosen.species_data(),chosen.sex,map_manager.database,tooltip_controller)
	_refresh()
	if map_manager.camera_controller != null:
		map_manager.camera_controller.focus_on(focus_position())
	set_process(true)

func close_focus() -> void:
	if focused and map_manager.camera_controller != null:
		map_manager.camera_controller.release_focus()
	focused = false
	target = null
	tooltip_controller.hide_tooltip()
	%Panel.hide()
	set_process(false)

func focus_position() -> Vector3:
	return target.global_position+Vector3.UP*0.5 if is_instance_valid(target) else Vector3.ZERO

func _process(delta: float) -> void:
	if map_manager.modal_active:
		%Panel.hide()
		return
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		close_focus()
		return
	%Panel.show()
	_elapsed += delta
	if _elapsed >= 0.15:
		_elapsed = 0
		_refresh()

func _refresh() -> void:
	%Satiety.visible = target is Creature
	%Happiness.visible = target is Creature
	%HabitatNeeds.visible = target is Creature
	if target is Creature:
		%Breeding.refresh()
		%SatietyBar.value = target.satiety
		%SatietyValue.text = tr("%d%%") % ceili(target.satiety)
		%HappinessBar.value = target.happiness
		%HappinessValue.text = tr("%d%%") % ceili(target.happiness)
		%HabitatNeeds.text = tr("Dry space per creature: %.1f m²\nPreferred space: %.1f m² · Nearby company: %d") % [target.space_per_creature,target.species_data().preferred_area,target.companions]
	_refresh_eggs()
	var building: BuildingDefinition = map_manager.building_controller.building_definition(target)
	%Durability.visible = building != null or target.has_method("structure_condition")
	if %Durability.visible:
		var integrity: float = map_manager.building_controller.condition(target) if building != null else target.structure_condition()
		%DurabilityBar.value = integrity*100.0
		%DurabilityValue.text = tr("%d%%") % ceili(integrity*100.0)
		%Repair.disabled = integrity >= 1.0
	var status := ""
	var action_text := ""
	var action_visible := false
	var action_disabled := false
	var progress_visible := false
	var progress := 0.0
	if target is Creature:
		status = target.activity_text() if target.has_method("activity_text") else tr("Resting")
		if target is TuftlingController and target.species_id == &"tuftling":
			status += tr("\nCarried water: %s") % [tr("Yes") if target.carrying_water else tr("No")]
	elif target is IncubatorController:
		%Title.text = tr("Incubator")
		%Description.text = tr("An incubator for discovered eggs. Your creature will appear beside it after hatching.")
		match target.state:
			IncubatorController.STATE.EMPTY:
				if target.current_egg == null:
					status = tr("Empty incubator\nDiscover an egg to begin incubation.")
				else:
					status = tr("Incubation: %.0f s\nOwned eggs: %d\nStarting consumes one egg.") % [target.current_egg.incubation_seconds,map_manager.items.amount(target.current_egg.id)]
					action_visible = true
					action_text = tr("Start incubation")
					action_disabled = map_manager.items.amount(target.current_egg.id) < 1
			IncubatorController.STATE.INCUBATING:
				progress_visible = true
				progress = (1.0-target.remaining/target.current_egg.incubation_seconds)*100.0
				status = tr("Incubating · %d s remaining") % ceili(target.remaining)
			IncubatorController.STATE.READY:
				status = tr("Ready to hatch")
				action_visible = true
				action_text = tr("Hatch")
			_:
				status = tr("Hatching")
	elif target is WorkshopController:
		%Title.text = tr("Life Workshop")
		%Description.text = tr("Form discovered eggs from materials and science. Each egg appears in the central socket when production finishes.")
		%Workshop.refresh()
	elif target is FeederController:
		%Title.text = tr("Feeder")
		%Description.text = tr("A wooden trough with a brass supply inlet. Hungry creatures walk here to eat Plant Fiber.")
		status = tr("Plant Fiber: %d / %d\nEach meal restores a creature’s satiety.") % [target.stock,target.capacity]
		action_visible = true
		action_text = tr("Fill with Plant Fiber (%s available)") % map_manager.inventory.quantity_text(target.food_resource)
		action_disabled = target.stock >= target.capacity or map_manager.inventory.amount(target.food_resource) < 1
	if target.has_method("structure_condition"):
		%Title.text = target.structure_title()
		%Description.text = tr("A modular fence. Repair damaged sections to keep creatures contained.")
	%Description.visible = not target is WorkshopController
	%Status.visible = not status.is_empty()
	%Status.text = status
	%Action.text = action_text
	%Action.disabled = action_disabled
	%Action.visible = action_visible
	%Progress.value = progress
	%Progress.visible = progress_visible

func _select_egg(index: int) -> void:
	if target is IncubatorController and index >= 0 and index < _egg_ids.size():
		target.select_egg(map_manager.database.egg(_egg_ids[index]))
		_refresh()

func _on_action() -> void:
	if target is IncubatorController:
		if target.state == IncubatorController.STATE.EMPTY:
			target.start_incubation()
		elif target.state == IncubatorController.STATE.READY:
			target.request_hatch()
	elif target is WorkshopController:
		%Title.text = tr("Life Workshop")
		%Description.text = tr("Form discovered eggs from materials and science. Each egg appears in the central socket when production finishes.")
		%Workshop.refresh()
	elif target is FeederController:
		target.fill()
	_refresh()

func _show_term(meta: Variant) -> void:
	var term: GlossaryEntry = map_manager.database.term(str(meta))
	if term != null:
		tooltip_controller.show_hint(term.display_name+"\n"+term.description,%Description)

func _refresh_eggs() -> void:
	%EggChoice.visible = target is IncubatorController and target.state == IncubatorController.STATE.EMPTY
	if not %EggChoice.visible:
		return
	var ids: Array[StringName] = []
	var labels := PackedStringArray()
	for egg: EggDefinition in map_manager.database.eggs:
		var count: int = map_manager.items.amount(egg.id)
		if count > 0:
			ids.append(egg.id)
			labels.append(tr("%s ×%d") % [egg.display_name,count])
	var signature := "|".join(labels)
	if signature != _egg_signature:
		_egg_signature = signature
		_egg_ids = ids
		%EggChoice.clear()
		for label in labels:
			%EggChoice.add_item(label)
	if target.current_egg == null or not ids.has(target.current_egg.id):
		target.select_egg(map_manager.database.egg(ids[0]) if not ids.is_empty() else null)
	if target.current_egg != null:
		%EggChoice.select(ids.find(target.current_egg.id))
	%EggChoice.visible = not ids.is_empty()

func _show_stat_hint(stat: Control) -> void:
	var message := tr("A full belly makes for a busy creature. Keep a little food nearby.")
	if stat == %Happiness:
		message = tr("Room to roam, a full belly and a friend make this creature feel at home.")
	tooltip_controller.show_hint(message,stat)

func _repair_target() -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("repair_structure"):
		target.repair_structure()
	else:
		map_manager.building_controller.repair_building(target)
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		if is_instance_valid(target) and not target.is_queued_for_deletion():
			_egg_signature = ""
			_refresh()
