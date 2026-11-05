@tool
class_name ForgeDiscoveryGraph
extends VBoxContainer

signal recipe_selected(id: String)
signal discovery_selected(id: String)

const CARD := preload("res://addons/hatchworks_forge/discoveries/views/graph_card.tscn")

var _document: ForgeDiscoveryDocument
var _discovery_id := ""
var _recipe_id := ""
var _pending := false
var _reset_view := true
var _building := false
var _positions: Dictionary[String, Vector2] = {}
var _structure_signature := ""

func _ready() -> void:
	%ResetView.pressed.connect(_center_view)
	%Graph.node_selected.connect(_on_node_selected)
	refresh()

func configure(document: ForgeDiscoveryDocument) -> void:
	_document = document
	refresh()

func show_discovery(id: String, selected_recipe := "") -> void:
	if _discovery_id != id:
		_positions.clear()
		_reset_view = true
	_discovery_id = id
	_recipe_id = selected_recipe
	refresh()

func refresh() -> void:
	if _pending or not is_node_ready():
		return
	_pending = true
	_rebuild.call_deferred()

func _rebuild() -> void:
	_pending = false
	_building = true
	var graph: GraphEdit = %Graph
	var incoming: Array[Dictionary] = _document.index.incoming(_discovery_id) if _document != null else []
	var outgoing: Array[Dictionary] = _document.index.outgoing(_discovery_id) if _document != null else []
	var signature := JSON.stringify([_discovery_id, incoming.map(func(recipe): return recipe.id), outgoing.map(func(recipe): return recipe.id)])
	if signature != _structure_signature:
		_structure_signature = signature
		_positions.clear()
		_reset_view = true
	graph.clear_connections()
	for child in graph.get_children():
		if child is GraphNode:
			if not _reset_view:
				_positions[str(child.get_meta("layout_id"))] = child.position_offset
			graph.remove_child(child)
			child.queue_free()
	if _document == null:
		_building = false
		return
	var data := _document.index.discovery(_discovery_id)
	%Empty.visible = data.is_empty()
	if data.is_empty():
		%Title.text = "Połączenia"
		%Counts.text = "Wybierz kafel"
		_building = false
		return
	%Title.text = str(data.display_name)
	var usage := _document.index.usage(_discovery_id)
	%Counts.text = "%d receptur · %d jako składnik · %d jako wynik" % [usage.recipes, usage.input, usage.output]
	var columns := maxi(1, ceili(outgoing.size() / 6.0))
	var outgoing_rows := maxi(1, ceili(float(outgoing.size()) / columns))
	var rows := maxi(1, maxi(incoming.size(), outgoing_rows))
	var center := _new_card("focus", "Focus", Vector2(340, rows * 68.0))
	center.configure_discovery(data)
	var conflicts := {}
	for problem in _document.problems():
		for id in problem.get("recipe_ids", []):
			conflicts[str(id)] = true
	for i in incoming.size():
		var recipe: Dictionary = incoming[i]
		var card := _new_card("in:" + str(recipe.id), "Incoming%d" % i, Vector2(20, (rows - incoming.size()) * 68.0 + i * 136.0 + 24))
		card.configure_recipe(recipe, _document.index, _discovery_id, true, conflicts.has(str(recipe.id)), str(recipe.id) == _recipe_id)
		graph.connect_node(card.name, 0, center.name, 0)
	for i in outgoing.size():
		var recipe: Dictionary = outgoing[i]
		var column := floori(float(i) / outgoing_rows)
		var column_count := mini(outgoing_rows, outgoing.size() - column * outgoing_rows)
		var card := _new_card("out:" + str(recipe.id), "Outgoing%d" % i, Vector2(660 + column * 280, (rows - column_count) * 68.0 + (i % outgoing_rows) * 136.0 + 24))
		card.configure_recipe(recipe, _document.index, _discovery_id, false, conflicts.has(str(recipe.id)), str(recipe.id) == _recipe_id)
		graph.connect_node(center.name, 0, card.name, 0)
	_building = false
	if _reset_view:
		_reset_view = false
		_center_view.call_deferred(true)

func _new_card(layout_id: String, node_name: String, point: Vector2) -> GraphNode:
	var card := CARD.instantiate() as GraphNode
	card.name = node_name
	card.set_meta("layout_id", layout_id)
	card.position_offset = _positions.get(layout_id, point)
	card.recipe_selected.connect(recipe_selected.emit)
	card.discovery_selected.connect(discovery_selected.emit)
	%Graph.add_child(card)
	return card

func _center_view(readable := false) -> void:
	var bounds := Rect2()
	var has_card := false
	for card in %Graph.get_children():
		if card is GraphNode:
			var rectangle := Rect2(card.position_offset, card.size)
			bounds = bounds.merge(rectangle) if has_card else rectangle
			has_card = true
	if not has_card:
		return
	var available: Vector2 = %Graph.size - Vector2(70, 110)
	var minimum_zoom: float = maxf(0.8, %Graph.zoom_min) if readable else %Graph.zoom_min
	var zoom := clampf(minf(available.x / maxf(bounds.size.x, 1), available.y / maxf(bounds.size.y, 1)), minimum_zoom, 1.0)
	%Graph.zoom = zoom
	var center := bounds.get_center()
	var focus := %Graph.get_node_or_null("Focus") as GraphNode
	if readable and is_equal_approx(zoom, minimum_zoom) and focus != null:
		center = focus.position_offset + focus.size * 0.5
	%Graph.scroll_offset = center * zoom - %Graph.size * 0.5 - Vector2(0, 20)

func _on_node_selected(chosen: Node) -> void:
	if _building:
		return
	if not chosen is GraphNode:
		return
	var layout_id := str(chosen.get_meta("layout_id", ""))
	if layout_id.begins_with("in:") or layout_id.begins_with("out:"):
		recipe_selected.emit(layout_id.substr(layout_id.find(":") + 1))
