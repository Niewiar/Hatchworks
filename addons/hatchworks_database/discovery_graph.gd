@tool
extends VBoxContainer

signal entry_selected(entry: Resource)
signal discovery_requested
signal recipe_requested
signal removal_requested(entries: Array)
signal message_requested(message: String, error: bool)

const DISCOVERY_NODE := preload("res://addons/hatchworks_database/discovery_graph_node.tscn")

@onready var _graph: GraphEdit = %Graph
var _database: GameDatabase
var _nodes: Dictionary = {}
var _selected: DiscoveryDefinition
var _focus: DiscoveryDefinition
var _focus_recipe: DiscoveryRecipe
var _show_all := false
var _syncing := false
var _history: EditorUndoRedoManager
var _move_start: Dictionary = {}
var _saved_positions: Dictionary = {}
var _refresh_queued := false
var _layout_signature := ""

func _ready() -> void:
	%NewDiscovery.pressed.connect(func(): discovery_requested.emit())
	%NewRecipe.pressed.connect(func(): recipe_requested.emit())
	%ShowAll.toggled.connect(_show_all_changed)
	%Arrange.pressed.connect(_arrange)
	%Fit.pressed.connect(_fit)
	%Find.text_changed.connect(_find_changed)
	_graph.node_selected.connect(_node_selected)
	_graph.delete_nodes_request.connect(_delete_requested)
	_graph.begin_node_move.connect(_begin_move)
	_graph.end_node_move.connect(_end_move)
	_graph.connection_request.connect(func(_from,_port,_to,_target): message_requested.emit("Edit the recipe in the side panel.",false))

func configure(database: GameDatabase, history: EditorUndoRedoManager) -> void:
	_database = database
	_history = history
	_selected = database.discoveries[0] if not database.discoveries.is_empty() else null
	_focus = _selected
	_focus_recipe = _first_recipe(_selected)
	_saved_positions = EditorInterface.get_editor_settings().get_project_metadata("hatchworks_database","discovery_positions_v2",{}) if Engine.is_editor_hint() else {}
	_layout_signature = ""
	refresh()

func refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()

func _refresh() -> void:
	_refresh_queued = false
	if _database == null or not is_node_ready() or not is_inside_tree():
		return
	_syncing = true
	_graph.clear_connections()
	for entry: Resource in _nodes.keys():
		if entry not in _database.discoveries:
			var old: GraphNode = _nodes[entry]
			_graph.remove_child(old)
			old.queue_free()
			_nodes.erase(entry)
	var index := 0
	for entry: DiscoveryDefinition in _database.discoveries:
		if not _nodes.has(entry):
			var node: GraphNode = DISCOVERY_NODE.instantiate()
			node.name = "Entry_"+str(entry.get_instance_id())
			node.set_meta("entry",entry)
			_graph.add_child(node)
			node.position_offset = Vector2((index % 5)*250,(index / 5)*140)
			_nodes[entry] = node
		var node: GraphNode = _nodes[entry]
		node.title = entry.display_name
		node.get_node("Summary/Icon").texture = entry.icon
		node.get_node("Summary/ID").text = _card_role(entry)
		node.visible = _entry_visible(entry)
		node.selected = entry == _selected
		index += 1
	var recipes: Array = _database.recipes if _show_all else ([_focus_recipe] if _focus_recipe != null else [])
	for recipe: DiscoveryRecipe in recipes:
		var target := _database.discovery(recipe.result)
		for id in [recipe.first,recipe.second]:
			var source := _database.discovery(id)
			if source == null or target == null or source == target or not _nodes.has(source) or not _nodes.has(target):
				continue
			if _nodes[source].visible and _nodes[target].visible and not _graph.is_node_connected(_nodes[source].name,0,_nodes[target].name,0):
				_graph.connect_node(_nodes[source].name,0,_nodes[target].name,0)
	var signature := str(_show_all)+":"+str([_focus_recipe.id,_focus_recipe.first,_focus_recipe.second,_focus_recipe.result] if _focus_recipe != null else [_focus.id if is_instance_valid(_focus) else &""])+":"+str(_database.discoveries.size())
	if signature != _layout_signature:
		_layout_signature = signature
		if _show_all:
			var offset := 0
			for entry: Resource in _nodes:
				_nodes[entry].position_offset = Vector2((offset % 5)*250,(offset / 5)*140)
				offset += 1
		else:
			_layout_neighbourhood()
		var saved: Dictionary = _saved_positions.get(_position_scope(),{})
		for entry: Resource in _nodes:
			if _nodes[entry].visible and saved.has(entry.resource_path):
				_nodes[entry].position_offset = saved[entry.resource_path]
		_fit.call_deferred()
	%GraphCount.text = "%d discoveries · %d recipes" % [_database.discoveries.size(),_database.recipes.size()]
	_syncing = false

func select_entry(entry: Resource) -> void:
	var chosen := entry as DiscoveryDefinition
	if entry is DiscoveryRecipe and _database != null:
		chosen = _database.discovery(entry.result)
	if chosen == null:
		return
	var was_syncing := _syncing
	_syncing = true
	_selected = chosen
	_focus = chosen
	_focus_recipe = entry if entry is DiscoveryRecipe else _first_recipe(chosen)
	for candidate: Resource in _nodes:
		_nodes[candidate].selected = candidate == chosen
	_syncing = was_syncing
	refresh()

func _entry_visible(entry: DiscoveryDefinition) -> bool:
	if _show_all:
		return true
	if _focus_recipe != null:
		return entry.id in [_focus_recipe.first,_focus_recipe.second,_focus_recipe.result]
	return entry == _focus

func _first_recipe(entry: DiscoveryDefinition) -> DiscoveryRecipe:
	if entry == null or _database == null:
		return null
	for recipe: DiscoveryRecipe in _database.recipes:
		if recipe.result == entry.id:
			return recipe
	for recipe: DiscoveryRecipe in _database.recipes:
		if entry.id in [recipe.first,recipe.second]:
			return recipe
	return null

func show_recipe(recipe: DiscoveryRecipe) -> void:
	if _focus_recipe == recipe:
		return
	_focus_recipe = recipe
	_layout_signature = ""
	refresh()

func _card_role(entry: DiscoveryDefinition) -> String:
	if _show_all or _focus_recipe == null:
		return DiscoveryDefinition.CATEGORY_NAMES[entry.category]
	var parts := PackedStringArray()
	if entry.id == _focus_recipe.first: parts.append("A")
	if entry.id == _focus_recipe.second: parts.append("B")
	if entry.id == _focus_recipe.result: parts.append("Result")
	return " + ".join(parts)

func _layout_neighbourhood() -> void:
	if _focus_recipe == null:
		if _focus != null and _nodes.has(_focus):
			_nodes[_focus].position_offset = Vector2.ZERO
		return
	var first := _database.discovery(_focus_recipe.first)
	var second := _database.discovery(_focus_recipe.second)
	var result := _database.discovery(_focus_recipe.result)
	if first != null: _nodes[first].position_offset = Vector2(0,0 if first != second else 70)
	if second != null and first != second: _nodes[second].position_offset = Vector2(0,140)
	if result != null and result not in [first,second]: _nodes[result].position_offset = Vector2(330,70)

func _show_all_changed(active: bool) -> void:
	_show_all = active
	_layout_signature = ""
	refresh()

func _find_changed(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	for entry: DiscoveryDefinition in _database.discoveries:
		if (str(entry.id)+" "+entry.display_name).containsn(text):
			select_entry(entry)
			entry_selected.emit(entry)
			return

func _node_selected(node: Node) -> void:
	if _syncing or not node.has_meta("entry"):
		return
	_selected = node.get_meta("entry")
	_focus = _selected
	entry_selected.emit(_selected)
	refresh()

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
		if _nodes[entry].visible:
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
	_history.add_do_method(self,"_apply_positions",after,_position_scope())
	_history.add_undo_method(self,"_apply_positions",before,_position_scope())
	_history.commit_action()

func _position_scope() -> String:
	return "all" if _show_all else ("recipe:"+str(_focus_recipe.id) if _focus_recipe != null else "entry:"+str(_focus.id if _focus != null else &""))

func _apply_positions(positions: Dictionary, scope: String) -> void:
	if not _saved_positions.has(scope):
		_saved_positions[scope] = {}
	for entry: Resource in positions:
		if _nodes.has(entry) and scope == _position_scope():
			_nodes[entry].position_offset = positions[entry]
		_saved_positions[scope][entry.resource_path] = positions[entry]
	if Engine.is_editor_hint():
		EditorInterface.get_editor_settings().set_project_metadata("hatchworks_database","discovery_positions_v2",_saved_positions)

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

