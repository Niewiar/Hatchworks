class_name InspectionPanel
extends Control

@export var map_manager: Node3D
@export var tooltip_controller: TooltipController

var target: Node3D
var focused := false
var _elapsed := 0.0
var _egg_ids: Array[StringName] = []
var _egg_signature := ""
var _aversion_signature := ""

const AVERSION_ICON := preload("res://scenes/ui/creature_aversion_icon.tscn")

func _ready() -> void:
	%Panel.hide()
	set_process(false)
	%Action.pressed.connect(_on_action)
	%Repair.pressed.connect(_repair_target)
	%EggChoice.item_selected.connect(_select_egg)
	%Close.pressed.connect(close_focus)
	%CreatureClose.pressed.connect(close_focus)
	%CreatureClose.mouse_entered.connect(func(): tooltip_controller.show_text(tr("Close focus - RMB"),%CreatureClose))
	%CreatureClose.mouse_exited.connect(tooltip_controller.hide_text.bind(%CreatureClose))
	%Description.meta_hover_started.connect(_show_term)
	%Description.meta_hover_ended.connect(func(_meta): tooltip_controller.hide_text(%Description))
	for stat in [%Satiety,%Happiness]:
		stat.mouse_entered.connect(_show_stat_hint.bind(stat))
		stat.mouse_exited.connect(tooltip_controller.hide_text.bind(stat))
	for control in [%CreatureState,%Space,%Company,%CarriedWater,%NoiseSensitivity,%CrowdingSensitivity,%NeighboursSensitivity]:
		control.mouse_entered.connect(_show_creature_hint.bind(control))
		control.mouse_exited.connect(tooltip_controller.hide_text.bind(control))

func inspect(chosen: Node3D) -> void:
	if not is_instance_valid(chosen) or not (chosen is Creature or chosen is IncubatorController or chosen is FeederController or chosen is WorkshopController or chosen.has_method("structure_condition")):
		return
	if target != chosen:
		tooltip_controller.hide_tooltip()
	target = chosen
	focused = true
	_elapsed = 0.0
	%Panel.show()
	%CreatureClose.visible = chosen is Creature
	%Close.visible = not chosen is Creature
	%CreatureCard.visible = chosen is Creature
	%Generic.visible = not chosen is Creature
	_egg_signature = ""
	_aversion_signature = ""
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
	%CreatureDetails.visible = target is Creature
	if target is Creature:
		_refresh_creature()
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
		status = ""
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

func _refresh_creature() -> void:
	%Breeding.refresh()
	%SatietyBar.value = target.satiety
	%SatietyValue.text = tr("%d%%") % ceili(target.satiety)
	%HappinessBar.value = target.happiness
	%HappinessValue.text = tr("%d%%") % ceili(target.happiness)
	var species: CreatureSpecies = target.species_data()
	%SpaceValue.text = tr("%.1f / %.1f m²") % [target.space_per_creature,species.preferred_area]
	%CompanyValue.text = tr("×%d") % target.companions
	%CarriedWater.visible = target is TuftlingController and target.species_id == &"tuftling"
	if %CarriedWater.visible:
		%CarriedWater.modulate = Color.WHITE if target.carrying_water else Color(0.5,0.55,0.5,0.55)
	var values := [species.noise_sensitivity,species.crowding_sensitivity,0.0]
	for aversion in species.species_aversions.values():
		values[2] = maxf(values[2],float(aversion))
	var stresses := [target.noise_stress,target.crowding_stress,target.species_stress]
	var labels := [%NoiseSensitivityValue,%CrowdingSensitivityValue,%NeighboursSensitivityValue]
	var bars := [%NoiseStress,%CrowdingStress,%NeighboursStress]
	for index in 3:
		labels[index].text = tr("%d%%") % roundi(values[index]*100.0)
		bars[index].value = stresses[index]*100.0
		bars[index].modulate = Color(1,0.62,0.45) if stresses[index] >= 0.5 else Color(0.7,0.9,0.7)
	var state := _creature_activity()
	%ActivityName.text = tr(state[0])
	%ActivityIcon.texture = load("res://assets/ui/"+state[1]+".png")
	_refresh_aversions(species)

func _creature_activity() -> Array[String]:
	if map_manager.breeding.is_breeding(target):
		return ["Courting","breeding_heart"]
	if not target is TuftlingController:
		return ["Resting","status_rest"]
	match target.activity:
		TuftlingController.ACTIVITY.SEEKING_WATER,TuftlingController.ACTIVITY.MOVING_TO_WATER:
			return ["Seeking water","water"]
		TuftlingController.ACTIVITY.BATHING,TuftlingController.ACTIVITY.SWIMMING:
			return ["Swimming","water"]
		TuftlingController.ACTIVITY.SEEKING_GROUND,TuftlingController.ACTIVITY.MOVING_TO_GROUND:
			return ["On the move","status_walk"]
		TuftlingController.ACTIVITY.SHAKING:
			return ["Working","status_work"]
		TuftlingController.ACTIVITY.HUNGRY:
			return ["Hungry","status_satiety"]
		TuftlingController.ACTIVITY.MOVING_TO_FOOD:
			return ["Seeking food","status_satiety"]
		TuftlingController.ACTIVITY.EATING:
			return ["Eating","status_satiety"]
		TuftlingController.ACTIVITY.NO_WATER:
			return ["Needs water","water"]
		TuftlingController.ACTIVITY.NO_GROUND:
			return ["Needs space","status_space"]
	return ["Resting","status_rest"]

func _refresh_aversions(species: CreatureSpecies) -> void:
	var signature := str(species.species_aversions)
	for id in species.species_aversions:
		signature += str(map_manager.discoveries.knows(id))
	if _aversion_signature == signature:
		return
	_aversion_signature = signature
	for child in %AversionIcons.get_children():
		%AversionIcons.remove_child(child)
		child.queue_free()
	for id in species.species_aversions:
		if float(species.species_aversions[id]) <= 0.0:
			continue
		var other: CreatureSpecies = map_manager.database.creature(id)
		if other == null:
			continue
		var icon := AVERSION_ICON.instantiate() as VBoxContainer
		icon.get_node("Icon").texture = other.icon if map_manager.discoveries.knows(id) else load("res://assets/ui/status_neighbours.png")
		icon.get_node("Unknown").visible = not map_manager.discoveries.knows(id)
		%AversionIcons.add_child(icon)
		icon.mouse_entered.connect(_show_aversion.bind(id,icon))
		icon.mouse_exited.connect(tooltip_controller.hide_text.bind(icon))
	%AversionIcons.visible = %AversionIcons.get_child_count() > 0

func _show_aversion(id: StringName, icon: Control) -> void:
	if not target is Creature:
		return
	var other: CreatureSpecies = map_manager.database.creature(id)
	var strength := roundi(float(target.species_data().species_aversions.get(id,0.0))*100.0)
	tooltip_controller.show_hint(tr("Uneasy around %s · %d%%") % [other.display_name if map_manager.discoveries.knows(id) else "???",strength],icon)

func _show_creature_hint(control: Control) -> void:
	if not target is Creature:
		return
	var text := ""
	if control == %CreatureState:
		text = target.activity_text() if target.has_method("activity_text") else tr("Resting")
	elif control == %Space:
		text = tr("Room to roam\n%.1f / %.1f m² of dry ground") % [target.space_per_creature,target.species_data().preferred_area]
	elif control == %Company:
		text = tr("A familiar face nearby\nCompanions: %d") % target.companions
	elif control == %CarriedWater:
		text = tr("Carrying a little water") if target.carrying_water else tr("Ready for a dip")
	elif control == %NoiseSensitivity:
		text = tr("Noise\nPrefers a quiet corner.\nSensitivity: %d%% · Disturbed: %d%%") % [roundi(target.species_data().noise_sensitivity*100.0),roundi(target.noise_stress*100.0)]
	elif control == %CrowdingSensitivity:
		text = tr("Crowding\nNeeds room to feel at home.\nSensitivity: %d%% · Crowded: %d%%") % [roundi(target.species_data().crowding_sensitivity*100.0),roundi(target.crowding_stress*100.0)]
	elif control == %NeighboursSensitivity:
		text = tr("Neighbours\nSome company feels less welcome.\nDisturbed: %d%%") % roundi(target.species_stress*100.0)
	tooltip_controller.show_hint(text,control)
