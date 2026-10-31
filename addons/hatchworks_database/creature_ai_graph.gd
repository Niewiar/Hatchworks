@tool
extends VBoxContainer

signal edited(entry: Resource, property: String, value: Variant)
signal message_requested(message: String, error: bool)

const STATE_NODE := preload("res://addons/hatchworks_database/ai_state_node.tscn")
const CONDITION_ROW := preload("res://addons/hatchworks_database/ai_condition_row.tscn")
var _database: GameDatabase
var _species: CreatureSpecies
var _draft: Dictionary = {}
var _selected := ""
var _syncing := false

func _ready() -> void:
	%Species.item_selected.connect(_choose_species)
	%Fit.pressed.connect(_fit)
	%Reset.pressed.connect(func(): _draft = CreatureAiGraph.defaults(); _selected = ""; _commit(); _render())
	%Transitions.item_selected.connect(_select_transition)
	%From.item_selected.connect(func(_index): _set_edge("from",%From.get_item_metadata(%From.selected)))
	%To.item_selected.connect(func(_index): _set_edge("to",%To.get_item_metadata(%To.selected)))
	%Priority.value_changed.connect(func(value): _set_edge("priority",int(value)))
	%Match.item_selected.connect(func(index): _set_edge("match","all" if index == 0 else "any"))
	%AddCondition.pressed.connect(_add_condition)
	%RemoveTransition.pressed.connect(_remove_transition)
	%AddTransition.pressed.connect(func(): _connect_states("any",0,"work",0))
	%Graph.connection_request.connect(_connect_states)
	%Graph.disconnection_request.connect(_disconnect_states)
	%Graph.end_node_move.connect(_save_positions)

func configure(database: GameDatabase, selection: CreatureSpecies = null) -> void:
	_database = database
	%Species.clear()
	for species: CreatureSpecies in database.creatures:
		%Species.add_icon_item(species.icon,species.display_name)
	var index := database.creatures.find(selection)
	if index < 0:
		index = 0
	if not database.creatures.is_empty():
		%Species.select(index)
		_choose_species(index)

func _choose_species(index: int) -> void:
	_species = _database.creatures[index]
	_draft = CreatureAiGraph.defaults() if _species.ai_graph.is_empty() else _species.ai_graph.duplicate(true)
	_selected = ""
	_render()

func sync(entry: Resource) -> void:
	if entry == _species and _draft != entry.ai_graph:
		_draft = CreatureAiGraph.defaults() if entry.ai_graph.is_empty() else entry.ai_graph.duplicate(true)
		_render()

func _render() -> void:
	_syncing = true
	%Graph.clear_connections()
	for child in %Graph.get_children():
		if child is GraphNode:
			%Graph.remove_child(child)
			child.queue_free()
	for state: Dictionary in _draft.nodes:
		var card := STATE_NODE.instantiate() as GraphNode
		card.name = state.id
		card.title = CreatureAiGraph.STATES[state.id]
		card.position_offset = Vector2(state.position[0],state.position[1])
		card.set_slot_enabled_left(0,state.id != "any")
		card.get_node("Content/Enabled").button_pressed = state.enabled
		card.get_node("Content/Enabled").disabled = state.id == "any"
		card.get_node("Content/Enabled").toggled.connect(_toggle_state.bind(state.id))
		card.get_node("Content/Description").text = {"any":"Checks from every behaviour.","feed":"Find a feeder and eat.","attack":"Pebblit: approach and hit a structure.","rest":"Find dry ground and rest.","work":"Run this species' existing work cycle."}[state.id]
		%Graph.add_child(card)
	_redraw_connections()
	_fill_states(%From,true)
	_fill_states(%To,false)
	_syncing = false
	_render_transitions()
	_render_edge()
	_fit.call_deferred()

func _fit() -> void:
	await get_tree().process_frame
	var bounds := Rect2()
	var first := true
	for card in %Graph.get_children():
		if not card is GraphNode:
			continue
		var rect := Rect2(card.position_offset,card.size)
		bounds = rect if first else bounds.merge(rect)
		first = false
	if not first and bounds.size.x > 0.0 and bounds.size.y > 0.0:
		var available: Vector2 = (%Graph.size-Vector2(40,90)).max(Vector2.ONE)
		%Graph.zoom = clampf(minf(available.x/bounds.size.x,available.y/bounds.size.y)*0.86,%Graph.zoom_min,1.0)
		%Graph.scroll_offset = bounds.get_center()*%Graph.zoom-%Graph.size*0.5-Vector2(0,25)

func _fill_states(choice: OptionButton, include_any: bool) -> void:
	choice.clear()
	for id: String in CreatureAiGraph.STATES:
		if id == "any" and not include_any:
			continue
		choice.add_item(CreatureAiGraph.STATES[id])
		choice.set_item_metadata(choice.item_count-1,id)

func _redraw_connections() -> void:
	%Graph.clear_connections()
	for edge: Dictionary in _draft.transitions:
		if not %Graph.is_node_connected(edge.from,0,edge.to,0):
			%Graph.connect_node(edge.from,0,edge.to,0)

func _render_transitions() -> void:
	%Transitions.clear()
	for edge: Dictionary in _draft.transitions:
		%Transitions.add_item("[%d] %s → %s" % [edge.priority,CreatureAiGraph.STATES[edge.from],CreatureAiGraph.STATES[edge.to]])
		%Transitions.set_item_metadata(%Transitions.item_count-1,edge.id)
		if edge.id == _selected:
			%Transitions.select(%Transitions.item_count-1)
	if _edge().is_empty() and not _draft.transitions.is_empty():
		_selected = _draft.transitions[0].id
		%Transitions.select(0)

func _select_transition(index: int) -> void:
	_selected = %Transitions.get_item_metadata(index)
	_render_edge()

func _edge() -> Dictionary:
	for edge: Dictionary in _draft.get("transitions",[]):
		if edge.id == _selected:
			return edge
	return {}

func _render_edge() -> void:
	_syncing = true
	var edge := _edge()
	%EdgeFields.visible = not edge.is_empty()
	for child in %Conditions.get_children():
		%Conditions.remove_child(child)
		child.queue_free()
	if edge.is_empty():
		_syncing = false
		return
	for choice in [%From,%To]:
		var key := "from" if choice == %From else "to"
		for index in choice.item_count:
			if choice.get_item_metadata(index) == edge[key]:
				choice.select(index)
	%Priority.value = edge.priority
	%Match.select(0 if edge.match == "all" else 1)
	for index in edge.conditions.size():
		var condition: Dictionary = edge.conditions[index]
		var row := CONDITION_ROW.instantiate() as HBoxContainer
		%Conditions.add_child(row)
		for field: String in CreatureAiGraph.FIELDS:
			row.get_node("Field").add_item(CreatureAiGraph.FIELDS[field])
			row.get_node("Field").set_item_metadata(row.get_node("Field").item_count-1,field)
			if field == condition.field:
				row.get_node("Field").select(row.get_node("Field").item_count-1)
		for op: String in CreatureAiGraph.OPERATORS:
			row.get_node("Operator").add_item(op)
		row.get_node("Operator").select(CreatureAiGraph.OPERATORS.find(condition.op))
		if condition.field in CreatureAiGraph.BOOLEAN_FIELDS:
			row.get_node("Value").min_value = 0
			row.get_node("Value").max_value = 1
			row.get_node("Value").step = 1
		row.get_node("Value").value = condition.value
		row.get_node("Field").item_selected.connect(func(item): _set_condition(index,"field",row.get_node("Field").get_item_metadata(item)))
		row.get_node("Operator").item_selected.connect(func(item): _set_condition(index,"op",CreatureAiGraph.OPERATORS[item]))
		row.get_node("Value").value_changed.connect(func(value): _set_condition(index,"value",value))
		row.get_node("Remove").pressed.connect(_remove_condition.bind(index))
	_syncing = false

func _set_condition(index: int, key: String, value: Variant) -> void:
	if _syncing:
		return
	_edge().conditions[index][key] = value
	if key == "field" and value in CreatureAiGraph.BOOLEAN_FIELDS:
		_edge().conditions[index].value = 1
	_commit()
	if key == "field":
		_render_edge()

func _set_edge(key: String, value: Variant) -> void:
	if _syncing or _edge().is_empty():
		return
	_edge()[key] = value
	_commit()
	_render_transitions()
	_redraw_connections()

func _toggle_state(enabled: bool, id: String) -> void:
	if _syncing:
		return
	for state: Dictionary in _draft.nodes:
		if state.id == id:
			state.enabled = enabled
	_commit()

func _save_positions() -> void:
	var changed := false
	for state: Dictionary in _draft.nodes:
		var card := %Graph.get_node(NodePath(state.id)) as GraphNode
		var point := card.position_offset.clamp(Vector2.ZERO,Vector2.ONE*10000)
		if not is_equal_approx(point.x,float(state.position[0])) or not is_equal_approx(point.y,float(state.position[1])):
			state.position = [point.x,point.y]
			changed = true
		card.position_offset = point
	if changed:
		_commit()

func _connect_states(from: StringName, _from_port: int, to: StringName, _to_port: int) -> void:
	if _draft.transitions.size() >= 40:
		message_requested.emit("AI graphs support up to 40 transitions.",true)
		return
	if to == &"any" or not CreatureAiGraph.STATES.has(str(from)) or not CreatureAiGraph.STATES.has(str(to)):
		return
	_selected = "transition_"+str(Time.get_ticks_usec())
	_draft.transitions.append({"id":_selected,"from":str(from),"to":str(to),"priority":0,"match":"all","conditions":[]})
	_commit()
	_render_transitions()
	_render_edge()
	_redraw_connections()

func _disconnect_states(from: StringName, _from_port: int, to: StringName, _to_port: int) -> void:
	_draft.transitions = _draft.transitions.filter(func(edge): return edge.from != str(from) or edge.to != str(to))
	_commit()
	_render()

func _add_condition() -> void:
	if _edge().conditions.size() >= 12:
		message_requested.emit("Transitions support up to 12 conditions.",true)
		return
	_edge().conditions.append({"field":"satiety","op":"<=","value":35})
	_commit()
	_render_edge()

func _remove_condition(index: int) -> void:
	_edge().conditions.remove_at(index)
	_commit()
	_render_edge()

func _remove_transition() -> void:
	_draft.transitions = _draft.transitions.filter(func(edge): return edge.id != _selected)
	_selected = ""
	_commit()
	_render()

func _commit() -> void:
	var error := CreatureAiGraph.validate(_draft)
	message_requested.emit(error if not error.is_empty() else "AI graph updated. Save All to use it in the game.",not error.is_empty())
	if error.is_empty():
		edited.emit(_species,"ai_graph",_draft.duplicate(true))
