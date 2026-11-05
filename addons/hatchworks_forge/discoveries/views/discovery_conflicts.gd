@tool
class_name ForgeDiscoveryConflicts
extends VBoxContainer

signal discovery_selected(id: String)
signal recipe_selected(id: String)

const GROUP := preload("res://addons/hatchworks_forge/discoveries/views/conflict_group.tscn")
const ROW := preload("res://addons/hatchworks_forge/discoveries/views/conflict_row.tscn")

var _document: ForgeDiscoveryDocument
var _refresh_pending := false

func configure(document: ForgeDiscoveryDocument) -> void:
	_document = document
	refresh()

func refresh() -> void:
	if not _refresh_pending:
		_refresh_pending = true
		_rebuild.call_deferred()

func _rebuild() -> void:
	_refresh_pending = false
	if not is_node_ready() or _document == null:
		return
	for child in %Groups.get_children():
		%Groups.remove_child(child)
		child.queue_free()
	var problems := _document.problems()
	var affected := {}
	for problem: Dictionary in problems:
		var group := GROUP.instantiate() as PanelContainer
		%Groups.add_child(group)
		group.get_node("Content/Title").text = ForgeDiscoveryLabels.problem_message(_document.index,problem)
		var entries := group.get_node("Content/Entries")
		for id: String in problem.recipe_ids:
			var recipe := _document.recipe(id)
			if recipe.is_empty():
				continue
			affected[id] = true
			var row := ROW.instantiate() as HBoxContainer
			entries.add_child(row)
			row.get_node("Labels/Equation").text = ForgeDiscoveryLabels.equation(_document.index,recipe)
			row.get_node("Labels/Id").text = id
			row.get_node("Edit").pressed.connect(func(): recipe_selected.emit(id))
			row.get_node("Remove").pressed.connect(_document.remove_recipe.bind(id))
		for id: String in problem.discovery_ids if problem.recipe_ids.is_empty() else []:
			if _document.discovery(id).is_empty():
				continue
			var row := ROW.instantiate() as HBoxContainer
			entries.add_child(row)
			row.get_node("Labels/Equation").text = ForgeDiscoveryLabels.title(_document.index,id)
			row.get_node("Labels/Id").text = id
			row.get_node("Edit").pressed.connect(func(): discovery_selected.emit(id))
			row.get_node("Remove").hide()
	%Summary.text = "%d problemów · %d receptur" % [problems.size(),affected.size()]
	%Empty.visible = problems.is_empty()
