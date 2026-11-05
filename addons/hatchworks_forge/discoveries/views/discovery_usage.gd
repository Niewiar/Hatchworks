@tool
class_name ForgeDiscoveryUsage
extends VBoxContainer

signal recipe_selected(id: String)
signal discovery_selected(id: String)

const ROW := preload("res://addons/hatchworks_forge/discoveries/views/usage_row.tscn")
const RECIPE := preload("res://addons/hatchworks_forge/discoveries/views/usage_recipe.tscn")

var _document: ForgeDiscoveryDocument
var _category := -1
var _sort := 0
var _selected_id := ""
var _pending := false

func _ready() -> void:
	for i in %Categories.get_child_count():
		%Categories.get_child(i).pressed.connect(_choose_category.bind(i - 1))
	%Sort.item_selected.connect(_choose_sort)
	%OpenGraph.pressed.connect(func(): discovery_selected.emit(_selected_id))
	refresh()

func configure(document: ForgeDiscoveryDocument) -> void:
	_document = document
	refresh()

func refresh() -> void:
	if _pending or not is_node_ready():
		return
	_pending = true
	_rebuild.call_deferred()

func _choose_category(category: int) -> void:
	_category = category
	_selected_id = ""
	refresh()

func _choose_sort(order: int) -> void:
	_sort = order
	refresh()

func _select_usage(id: String) -> void:
	_selected_id = id if _selected_id != id else ""
	refresh()

func _rebuild() -> void:
	_pending = false
	_clear(%Rows)
	_clear(%RecipeRows)
	if _document == null:
		return
	var snapshot := _document.capture()
	var valid: Array = snapshot.discoveries.filter(func(entry: Variant): return entry is Dictionary)
	var counts := _document.index.category_counts()
	%Total.text = "%d kafli w bazie" % valid.size()
	for i in %Categories.get_child_count():
		var button := %Categories.get_child(i) as Button
		button.text = "Wszystkie %d" % valid.size() if i == 0 else "%s %d" % [ForgeDiscoveryLabels.category_name(i - 1), counts.get(i - 1, 0)]
		button.set_pressed_no_signal(i - 1 == _category)
	var entries: Array[Dictionary] = []
	for data: Dictionary in valid:
		if _category < 0 or int(data.category) == _category:
			entries.append(data)
	entries.sort_custom(_before)
	for entry in entries:
		var row := ROW.instantiate() as HBoxContainer
		%Rows.add_child(row)
		row.configure(entry, _document.index.usage(str(entry.id)), str(entry.id) == _selected_id)
		row.selected.connect(_select_usage)
	var selected := _document.index.discovery(_selected_id)
	%Details.visible = not selected.is_empty()
	if selected.is_empty():
		return
	var usage := _document.index.usage(_selected_id)
	%SelectedTitle.text = "%s · %d miejsc składnika" % [selected.display_name, usage.slots]
	for recipe in _document.index.related(_selected_id):
		var row := RECIPE.instantiate() as HBoxContainer
		%RecipeRows.add_child(row)
		row.configure(_document.index, recipe)
		row.selected.connect(recipe_selected.emit)
	%NoUses.visible = _document.index.related(_selected_id).is_empty()

func _before(first: Dictionary, second: Dictionary) -> bool:
	if _sort == 0:
		var first_count: int = _document.index.usage(str(first.id)).recipes
		var second_count: int = _document.index.usage(str(second.id)).recipes
		if first_count != second_count:
			return first_count > second_count
	elif _sort == 2 and first.category != second.category:
		return int(first.category) < int(second.category)
	return str(first.display_name).naturalnocasecmp_to(str(second.display_name)) < 0

func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
