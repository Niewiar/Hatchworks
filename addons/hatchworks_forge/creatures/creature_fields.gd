@tool
class_name ForgeCreatureFields
extends VBoxContainer

signal field_changed(name: String, value: Variant)
signal validation_changed(error: String)

const ROW := preload("res://addons/hatchworks_forge/creatures/field_row.tscn")
const GROUP := preload("res://addons/hatchworks_forge/creatures/field_group.tscn")

var _entry: Dictionary = {}
var _changes: Dictionary = {}
var _errors: Dictionary = {}
var _rows: Array[ForgeCreatureFieldRow] = []
var _fields: Array = []
var _categories: Array[String] = []
var _category := ""

func _ready() -> void:
	%Category.item_selected.connect(_select_category)

func configure(entry: Dictionary, changes: Dictionary) -> void:
	if not is_node_ready():
		await ready
	_entry = entry
	_changes = changes.duplicate(true)
	_build_categories()

func _build_categories() -> void:
	_fields = ForgeCreatureSchema.visible_fields(_entry, _changes)
	_categories.clear()
	%Category.clear()
	for field: Dictionary in _fields:
		var group := str(field.group)
		if not field.editable or group in _categories:
			continue
		_categories.append(group)
		%Category.add_item(str(field.group_label))
	if _category not in _categories:
		_category = _categories[0] if not _categories.is_empty() else ""
	%Category.disabled = _categories.size() < 2
	if not _categories.is_empty():
		%Category.select(_categories.find(_category))
	_render_category()

func _select_category(index: int) -> void:
	if not commit_fields():
		%Category.select(_categories.find(_category))
		return
	_category = _categories[index]
	_render_category()

func _render_category() -> void:
	_fields = ForgeCreatureSchema.visible_fields(_entry, _changes)
	_rows.clear()
	_errors.clear()
	for child in %Groups.get_children():
		%Groups.remove_child(child)
		child.queue_free()
	%Description.text = ""
	var group := GROUP.instantiate()
	%Groups.add_child(group)
	for field: Dictionary in _fields:
		if not field.editable or str(field.group) != _category:
			continue
		%Description.text = str(field.get("group_description", ""))
		var row := ROW.instantiate() as ForgeCreatureFieldRow
		group.add_child(row)
		row.configure(field, _changes.get(field.name, field.value), _changes.has(field.name))
		row.value_changed.connect(_changed)
		row.validation_changed.connect(_validation_changed)
		_rows.append(row)
		if not row.validation_error().is_empty():
			_errors[field.name] = row.validation_error()
	%Scroll.scroll_vertical = 0
	validation_changed.emit(validation_error())

func validation_error() -> String:
	var errors := PackedStringArray()
	var schema_error: String = ForgeCreatureSchema.validation_error(_entry, _changes)
	if not schema_error.is_empty():
		errors.append(schema_error)
	for name: String in _errors:
		var error := str(ForgeCreatureStore.LABELS.get(name, name)) + ": " + str(_errors[name])
		if not schema_error.contains(error):
			errors.append(error)
	return "\n".join(errors)

func commit_fields() -> bool:
	var complete := true
	for row in _rows:
		if is_instance_valid(row):
			row.commit_field()
			complete = not row.has_uncommitted_value() and complete
	return complete

func _changed(name: String, value: Variant) -> void:
	var baseline: Variant = null
	for field: Dictionary in _entry.get("fields", []):
		if str(field.name) == name:
			baseline = field.value
	if value == baseline:
		_changes.erase(name)
	else:
		_changes[name] = value
	if name == "terrain_minimums":
		for row in _rows:
			if str(row._field.name) == "female_terrain_minimums":
				row.update_inherited_value(value)
	field_changed.emit(name, value)
	validation_changed.emit(validation_error())

func _validation_changed(name: String, error: String) -> void:
	if error.is_empty():
		_errors.erase(name)
	else:
		_errors[name] = error
	validation_changed.emit(validation_error())
