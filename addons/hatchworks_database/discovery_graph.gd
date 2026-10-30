@tool
extends VBoxContainer

signal entry_selected(entry: Resource)
signal property_requested(entry: Resource, property: String, value: Variant)
signal discovery_requested
signal recipe_requested
signal removal_requested(entries: Array)
signal message_requested(message: String, error: bool)

const DISCOVERY_NODE := preload("res://addons/hatchworks_database/discovery_graph_node.tscn")
const RECIPE_NODE := preload("res://addons/hatchworks_database/recipe_graph_node.tscn")
const SCHEMA := preload("res://addons/hatchworks_database/database_schema.gd")

@onready var _graph: GraphEdit = %Graph
var _database: GameDatabase
var _nodes: Dictionary = {}
var _selected: Resource
var _focus: Resource
var _syncing := false
var _history: EditorUndoRedoManager
var _move_start: Dictionary = {}
var _saved_positions: Dictionary = {}

func _ready() -> void:
	%NewDiscovery.pressed.connect(func(): discovery_requested.emit())
	%NewRecipe.pressed.connect(func(): recipe_requested.emit())
	%ShowAll.pressed.connect(func(): _focus = null; refresh(); _fit.call_deferred())
	%FocusSelected.pressed.connect(_focus_selected)
	%Arrange.pressed.connect(_arrange)
	%Fit.pressed.connect(_fit)
	%Find.text_changed.connect(_find_changed)
	_graph.connection_request.connect(_connect_requested)
	_graph.disconnection_request.connect(_disconnect_requested)
	_graph.node_selected.connect(_node_selected)
	_graph.delete_nodes_request.connect(_delete_requested)
	_graph.begin_node_move.connect(_begin_move)
	_graph.end_node_move.connect(_end_move)
	_graph.add_valid_connection_type(1,1)
	_graph.add_valid_connection_type(2,2)
	_graph.add_valid_left_disconnect_type(1)
	_graph.add_valid_left_disconnect_type(2)
	_graph.add_valid_right_disconnect_type(1)
	_graph.add_valid_right_disconnect_type(2)

func configure(database: GameDatabase, history: EditorUndoRedoManager) -> void:
	_database = database
	_history = history
	_selected = null
	_focus = null
	_saved_positions = EditorInterface.get_editor_settings().get_project_metadata("hatchworks_database","graph_positions",{}) if Engine.is_editor_hint() else {}
	refresh()

func refresh() -> void:
	if _database == null or not is_node_ready():
		return
	_syncing = true
	_graph.clear_connections()
	var active: Array = []
	active.append_array(_database.discoveries)
	active.append_array(_database.recipes)
	for entry: Resource in _nodes.keys():
		if entry not in active:
			var old: GraphNode = _nodes[entry]
			_graph.remove_child(old)
			old.queue_free()
			_nodes.erase(entry)
	var index := 0
	for entry: Resource in active:
		if not _nodes.has(entry):
			var node: GraphNode = (RECIPE_NODE if entry is DiscoveryRecipe else DISCOVERY_NODE).instantiate()
			node.name = "Entry_"+str(entry.get_instance_id())
			node.set_meta("entry",entry)
			_graph.add_child(node)
			node.position_offset = _saved_positions.get(entry.resource_path,Vector2((index % 6)*320,(index / 6)*160))
			_nodes[entry] = node
		var node: GraphNode = _nodes[entry]
		if entry is DiscoveryDefinition:
			node.title = entry.display_name
			node.get_node("Summary/Icon").texture = entry.icon
			node.get_node("Summary/ID").text = str(entry.id)
		else:
			node.title = "Combination"
			node.get_node("First").text = "A: "+_discovery_name(entry.first)
			node.get_node("Second").text = "B: "+_discovery_name(entry.second)
			node.get_node("Result").text = "Result: "+_discovery_name(entry.result)
			node.self_modulate = Color.WHITE if SCHEMA.recipe_error(_database,entry.first,entry.second,entry.result,entry).is_empty() else Color(1,0.67,0.55)
		node.visible = _entry_visible(entry)
		node.selected = entry == _selected
		index += 1
	for recipe: DiscoveryRecipe in _database.recipes:
		_connect_existing(_database.discovery(recipe.first),0,recipe,0)
		_connect_existing(_database.discovery(recipe.second),0,recipe,1)
		_connect_existing(recipe,0,_database.discovery(recipe.result),0)
	%GraphCount.text = "%d discoveries · %d recipes" % [_database.discoveries.size(),_database.recipes.size()]
	_syncing = false

func select_entry(entry: Resource) -> void:
	_selected = entry
	for candidate: Resource in _nodes:
		_nodes[candidate].selected = candidate == entry

func _discovery_name(id: StringName) -> String:
	var entry := _database.discovery(id)
	return entry.display_name if entry != null else "Connect a discovery"

func _connect_existing(from: Resource, from_port: int, to: Resource, to_port: int) -> void:
	if from == null or to == null or not _nodes.has(from) or not _nodes.has(to):
		return
	if _nodes[from].visible and _nodes[to].visible:
		_graph.connect_node(_nodes[from].name,from_port,_nodes[to].name,to_port)

func _entry_visible(entry: Resource) -> bool:
	if _focus == null:
		return true
	if entry == _focus:
		return true
	if _focus is DiscoveryDefinition:
		if entry is DiscoveryRecipe:
			return _focus.id in [entry.first,entry.second,entry.result]
		for recipe: DiscoveryRecipe in _database.recipes:
			if _focus.id in [recipe.first,recipe.second,recipe.result] and entry.id in [recipe.first,recipe.second,recipe.result]:
				return true
	elif _focus is DiscoveryRecipe:
		return entry is DiscoveryDefinition and entry.id in [_focus.first,_focus.second,_focus.result]
	return false

func _focus_selected() -> void:
	if _selected != null:
		_focus = _selected
		refresh()
		_fit.call_deferred()

func _find_changed(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	for entry: DiscoveryDefinition in _database.discoveries:
		if (str(entry.id)+" "+entry.display_name).containsn(text):
			_selected = entry
			_focus = entry
			refresh()
			_fit.call_deferred()
			entry_selected.emit(entry)
			return

func _node_selected(node: Node) -> void:
	if _syncing or not node.has_meta("entry"):
		return
	_selected = node.get_meta("entry")
	entry_selected.emit(_selected)

func _connection_target(from_name: StringName, to_name: StringName, to_port: int) -> Array:
	var from := _graph.get_node_or_null(NodePath(from_name))
	var to := _graph.get_node_or_null(NodePath(to_name))
	if from == null or to == null or not from.has_meta("entry") or not to.has_meta("entry"):
		return []
	var first: Resource = from.get_meta("entry")
	var second: Resource = to.get_meta("entry")
	if first is DiscoveryDefinition and second is DiscoveryRecipe and to_port in [0,1]:
		return [second,"first" if to_port == 0 else "second",first.id]
	if first is DiscoveryRecipe and second is DiscoveryDefinition:
		return [first,"result",second.id]
	return []

func _connect_requested(from_name: StringName, _from_port: int, to_name: StringName, to_port: int) -> void:
	var target := _connection_target(from_name,to_name,to_port)
	if target.is_empty():
		message_requested.emit("Connect discoveries to A / B, and a recipe result to a discovery.",true)
		return
	var recipe: DiscoveryRecipe = target[0]
	var ids: Array[StringName] = [recipe.first,recipe.second,recipe.result]
	ids[["first","second","result"].find(target[1])] = target[2]
	if not ids.has(&""):
		var reason := SCHEMA.recipe_error(_database,ids[0],ids[1],ids[2],recipe)
		if not reason.is_empty():
			message_requested.emit(reason,true)
			return
	elif not ids[0].is_empty() and not ids[1].is_empty():
		for other: DiscoveryRecipe in _database.recipes:
			if other != recipe and other.matches(ids[0],ids[1]):
				message_requested.emit("This ingredient pair already belongs to: "+other.display_name,true)
				return
	property_requested.emit(recipe,target[1],target[2])

func _disconnect_requested(from_name: StringName, _from_port: int, to_name: StringName, to_port: int) -> void:
	var target := _connection_target(from_name,to_name,to_port)
	if not target.is_empty() and target[0].get(target[1]) == target[2]:
		property_requested.emit(target[0],target[1],&"")

func _delete_requested(names: Array[StringName]) -> void:
	var entries: Array = []
	for node_name in names:
		var node := _graph.get_node_or_null(NodePath(node_name))
		if node != null and node.has_meta("entry"):
			entries.append(node.get_meta("entry"))
	if not entries.is_empty():
		removal_requested.emit(entries)

func _begin_move() -> void:
	_move_start.clear()
	for entry: Resource in _nodes:
		_move_start[entry] = _nodes[entry].position_offset

func _end_move() -> void:
	var before: Dictionary = {}
	var after: Dictionary = {}
	for entry: Resource in _move_start:
		if _nodes.has(entry) and _nodes[entry].position_offset != _move_start[entry]:
			before[entry] = _move_start[entry]
			after[entry] = _nodes[entry].position_offset
	if after.is_empty():
		return
	_history.create_action("Database: move graph nodes",UndoRedo.MERGE_DISABLE,_database)
	_history.add_do_method(self,"_apply_positions",after)
	_history.add_undo_method(self,"_apply_positions",before)
	_history.commit_action()

func _apply_positions(positions: Dictionary) -> void:
	for entry: Resource in positions:
		if _nodes.has(entry):
			_nodes[entry].position_offset = positions[entry]
			_saved_positions[entry.resource_path] = positions[entry]
	if Engine.is_editor_hint():
		EditorInterface.get_editor_settings().set_project_metadata("hatchworks_database","graph_positions",_saved_positions)

func _arrange() -> void:
	_begin_move()
	_syncing = true
	for entry: Resource in _nodes:
		_nodes[entry].selected = _nodes[entry].visible
	_graph.arrange_nodes()
	for entry: Resource in _nodes:
		_nodes[entry].selected = entry == _selected
	_syncing = false
	await get_tree().process_frame
	_end_move()
	_fit()

func _fit() -> void:
	var bounds := Rect2()
	var found := false
	for entry: Resource in _nodes:
		var node: GraphNode = _nodes[entry]
		if not node.visible:
			continue
		var rect := Rect2(node.position_offset,node.size)
		bounds = bounds.merge(rect) if found else rect
		found = true
	if not found or bounds.size.x <= 0 or bounds.size.y <= 0:
		return
	_graph.zoom = clampf(minf(_graph.size.x / bounds.size.x,_graph.size.y / bounds.size.y)*0.86,_graph.zoom_min,1.0)
	_graph.scroll_offset = bounds.get_center()*_graph.zoom-_graph.size*0.5

