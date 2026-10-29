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
	%EggChoice.item_selected.connect(_select_egg)
	%Close.pressed.connect(close_focus)
	%Description.meta_hover_started.connect(_show_term)
	%Description.meta_hover_ended.connect(func(_meta): tooltip_controller.hide_text(%Description))

func inspect(chosen: Node3D) -> void:
	if not is_instance_valid(chosen) or not (chosen is Creature or chosen is IncubatorController or chosen is FeederController):
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
	if chosen is Creature:
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
	if target is Creature:
		%SatietyBar.value = target.satiety
		%SatietyValue.text = "%d%%" % ceili(target.satiety)
	_refresh_eggs()
	var status := ""
	var action_text := ""
	var action_visible := false
	var action_disabled := false
	var progress_visible := false
	var progress := 0.0
	if target is TuftlingController:
		status = target.activity_text()+"\nCarried water: %s" % ["Yes" if target.carrying_water else "No"]
	elif target is IncubatorController:
		%Title.text = "Incubator"
		%Description.text = "An incubator for discovered eggs. Your creature will appear beside it after hatching."
		match target.state:
			IncubatorController.STATE.EMPTY:
				if target.current_egg == null:
					status = "Empty incubator\nDiscover an egg to begin incubation."
				else:
					status = "Incubation: %.0f s\nOwned eggs: %d\nStarting consumes one egg." % [target.current_egg.incubation_seconds,map_manager.items.amount(target.current_egg.id)]
					action_visible = true
					action_text = "Start incubation"
					action_disabled = map_manager.items.amount(target.current_egg.id) < 1
			IncubatorController.STATE.INCUBATING:
				progress_visible = true
				progress = (1.0-target.remaining/target.current_egg.incubation_seconds)*100.0
				status = "Incubating · %d s remaining" % ceili(target.remaining)
			IncubatorController.STATE.READY:
				status = "Ready to hatch"
				action_visible = true
				action_text = "Hatch"
			_:
				status = "Hatching"
	elif target is FeederController:
		%Title.text = "Feeder"
		%Description.text = "A wooden trough with a brass supply inlet. Hungry Tuftlings walk here to eat Plant Fiber."
		status = "Plant Fiber: %d / %d\nEach meal restores a Tuftling’s satiety." % [target.stock,target.capacity]
		action_visible = true
		action_text = "Fill with Plant Fiber (%s available)" % map_manager.inventory.quantity_text(target.food_resource)
		action_disabled = target.stock >= target.capacity or map_manager.inventory.amount(target.food_resource) < 1
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
			labels.append("%s ×%d" % [egg.display_name,count])
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
