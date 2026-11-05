@tool
class_name ForgeCreaturePanel
extends PanelContainer

const CARD := preload("res://addons/hatchworks_forge/creatures/creature_card.tscn")
const MODES := ["editor", "history"]

var _store := ForgeCreatureStore.new()
var _entries: Array[Dictionary] = []
var _selected := ""
var _female := false
var _mode := 0
var _changes: Dictionary = {}
var _cards: Dictionary = {}
var _pending := Callable()
var _initialized := false
var _validation_status := false

@onready var _preview: ForgeCreaturePreview = $Layout/Body/Workspace/Content/ModelScroll/ModelColumn/Preview
@onready var _fields: ForgeCreatureFields = $Layout/Body/Workspace/Content/Inspector/Content/Fields
@onready var _status: Label = $Layout/Status

func _ready() -> void:
	$Layout/Actions/Refresh.pressed.connect(func(): _request(_reload))
	$Layout/Actions/Revert.pressed.connect(_revert)
	$Layout/Actions/Save.pressed.connect(_confirm_save)
	$Layout/Body/Library/Content/Search.text_changed.connect(_filter_cards)
	$Layout/Body/Workspace/Heading/Sex/Male.pressed.connect(_set_female.bind(false))
	$Layout/Body/Workspace/Heading/Sex/Female.pressed.connect(_set_female.bind(true))
	var buttons := $Layout/Body/Workspace/Modes.get_children()
	for index in buttons.size():
		buttons[index].pressed.connect(_set_mode.bind(index))
	_fields.field_changed.connect(_change_field)
	_fields.validation_changed.connect(func(_error): _update_dirty())
	$Layout/SaveDialog.confirmed.connect(_save_current)
	$Layout/DiscardDialog.confirmed.connect(_discard_and_continue)
	$Layout/DiscardDialog.canceled.connect(func(): _pending = Callable())
	var diff: Tree = $Layout/SaveDialog/Diff
	diff.set_column_title(0, "Pole")
	diff.set_column_title(1, "Było")
	diff.set_column_title(2, "Będzie")
	visibility_changed.connect(_ensure_loaded)
	_ensure_loaded()

func _ensure_loaded() -> void:
	if is_node_ready() and is_visible_in_tree() and not _initialized:
		_initialized = true
		_reload()
		var draft := _store.load_draft()
		if not str(draft.get("error", "")).is_empty():
			_message(str(draft.error), true)
		elif not draft.get("changes", {}).is_empty():
			_changes = draft.changes
			_select_species(_selected if _changes.has(_selected) else str(_changes.keys()[0]))
			_message("Przywrócono niezapisany szkic danych kreatur.")
			_update_dirty()

func _reload() -> void:
	_fields.commit_fields()
	_entries = _store.load_entries()
	if not _store.last_error.is_empty():
		_message(_store.last_error, true)
		return
	_changes.clear()
	_build_cards()
	if _store.entry(_selected).is_empty():
		_selected = "tuftling" if not _store.entry("tuftling").is_empty() else str(_entries[0].id) if not _entries.is_empty() else ""
	if not _selected.is_empty():
		_select_species(_selected)
	_message("Dane kreatur wczytane.")

func _build_cards() -> void:
	var container := $Layout/Body/Library/Content/Scroll/Cards
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	_cards.clear()
	var ordered := _entries.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	for entry in ordered:
		var card := CARD.instantiate() as Button
		card.get_node("Margin/Content/Portrait").texture = entry.icon
		card.get_node("Margin/Content/Info/Name").text = entry.name
		card.get_node("Margin/Content/Info/Id").text = entry.id
		card.pressed.connect(func(): _request(_select_species.bind(str(entry.id))))
		container.add_child(card)
		_cards[str(entry.id)] = card
	_filter_cards($Layout/Body/Library/Content/Search.text)

func _filter_cards(query: String) -> void:
	var count := 0
	for entry in _entries:
		var matched := query.is_empty() or (str(entry.name) + " " + str(entry.id)).to_lower().contains(query.to_lower())
		if _cards.has(str(entry.id)):
			_cards[str(entry.id)].visible = matched
		if matched:
			count += 1
	$Layout/Body/Library/Content/Heading/Count.text = str(count)

func _select_species(id: String) -> void:
	var entry := _store.entry(id)
	if entry.is_empty():
		return
	_fields.commit_fields()
	_selected = id
	_female = false
	_mode = 0
	for button in $Layout/Body/Workspace/Modes.get_children():
		button.set_pressed_no_signal(button.get_index() == 0)
	$Layout/Body/Workspace/Content.show()
	$Layout/Body/Workspace/Content/ModelScroll.show()
	$Layout/Body/Workspace/History.hide()
	$Layout/Body/Workspace/Heading/Identity/Name.text = entry.name
	$Layout/Body/Workspace/Heading/Sex/Male.set_pressed_no_signal(true)
	$Layout/Body/Workspace/Heading/Sex/Female.set_pressed_no_signal(false)
	for key in _cards:
		_cards[key].set_pressed_no_signal(key == id)
	_bind_fields()
	_preview.configure(entry.resource, false)
	_build_relations(id)
	_refresh_history()

func _set_female(female: bool) -> void:
	if _female == female:
		return
	_fields.commit_fields()
	_female = female
	$Layout/Body/Workspace/Heading/Sex/Male.set_pressed_no_signal(not female)
	$Layout/Body/Workspace/Heading/Sex/Female.set_pressed_no_signal(female)
	var entry := _store.entry(_selected)
	if not entry.is_empty():
		_preview.configure(entry.resource, female)

func _set_mode(index: int) -> void:
	if not _fields.commit_fields():
		for button in $Layout/Body/Workspace/Modes.get_children():
			button.set_pressed_no_signal(button.get_index() == _mode)
		return
	_mode = clampi(index, 0, MODES.size() - 1)
	for button in $Layout/Body/Workspace/Modes.get_children():
		button.set_pressed_no_signal(button.get_index() == _mode)
	$Layout/Body/Workspace/Content.visible = _mode == 0
	$Layout/Body/Workspace/History.visible = _mode == 1
	if _mode == 1:
		_refresh_history()
	else:
		_bind_fields()

func _bind_fields() -> void:
	var entry := _store.entry(_selected)
	if not entry.is_empty():
		_fields.configure(entry, _changes.get(_selected, {}))
	_update_dirty()

func _change_field(name: String, value: Variant) -> void:
	var entry := _store.entry(_selected)
	if entry.is_empty():
		return
	var changes: Dictionary = _changes.get(_selected, {}).duplicate(true)
	var baseline: Variant = null
	for field in entry.fields:
		if str(field.name) == name:
			baseline = field.value
	if value == baseline:
		changes.erase(name)
	else:
		changes[name] = value
	if changes.is_empty():
		_changes.erase(_selected)
	else:
		_changes[_selected] = changes
	_update_dirty()

func _update_dirty() -> void:
	if not is_node_ready():
		return
	var count := int(_changes.get(_selected, {}).size())
	$Layout/Body/Workspace/Content/Inspector/Content/Dirty.text = "%d niezapisane zmiany" % count if count > 0 else "Brak niezapisanych zmian"
	$Layout/Actions/Revert.disabled = count == 0
	$Layout/Actions/Save.disabled = count == 0 or not _fields.validation_error().is_empty()
	if not _fields.validation_error().is_empty():
		_message(_fields.validation_error(), true)
		_validation_status = true
	elif _validation_status:
		_message("")

func _revert() -> void:
	_changes.erase(_selected)
	_bind_fields()
	persist_draft()
	_message("Cofnięto niezapisane zmiany.")

func _request(action: Callable) -> void:
	if not _fields.commit_fields():
		for key in _cards:
			_cards[key].set_pressed_no_signal(key == _selected)
		return
	if not _changes.get(_selected, {}).is_empty():
		_pending = action
		$Layout/DiscardDialog.popup_centered()
		for key in _cards:
			_cards[key].set_pressed_no_signal(key == _selected)
	else:
		action.call()

func _discard_and_continue() -> void:
	_changes.erase(_selected)
	var action := _pending
	_pending = Callable()
	if action.is_valid():
		action.call()
	persist_draft()

func _confirm_save() -> void:
	_fields.commit_fields()
	if not _fields.validation_error().is_empty():
		_message(_fields.validation_error(), true)
		return
	var changes: Dictionary = _changes.get(_selected, {})
	if changes.is_empty():
		return
	var entry := _store.entry(_selected)
	var diff: Tree = $Layout/SaveDialog/Diff
	diff.clear()
	var root := diff.create_item()
	for field in entry.fields:
		if changes.has(str(field.name)):
			var row := diff.create_item(root)
			row.set_text(0, str(field.label))
			row.set_text(1, _print_value(field.value))
			row.set_text(2, _print_value(changes[str(field.name)]))
	$Layout/SaveDialog.popup_centered()

func _save_current() -> void:
	var error := _store.save(_selected, _changes.get(_selected, {}))
	if not error.is_empty():
		_message(error, true)
		return
	_changes.erase(_selected)
	for index in _entries.size():
		_entries[index] = _store.entry(str(_entries[index].id))
	_build_cards()
	var entry := _store.entry(_selected)
	$Layout/Body/Workspace/Heading/Identity/Name.text = str(entry.name)
	for key in _cards:
		_cards[key].set_pressed_no_signal(key == _selected)
	_bind_fields()
	_refresh_history()
	persist_draft()
	_message(_store.last_warning if not _store.last_warning.is_empty() else "Zapisano do Godota. Uruchom ponownie rozgrywkę, aby wczytać nowe dane.", not _store.last_warning.is_empty())

func _refresh_history() -> void:
	var blocks := PackedStringArray()
	for record in _store.history(_selected):
		blocks.append(str(record.get("time", "")).replace("T", " "))
		for name in record.get("changes", {}):
			var label := str(name)
			for field in _store.entry(_selected).get("fields", []):
				if str(field.name) == str(name):
					label = str(field.label)
			blocks.append(label + ": " + _print_value(record.changes[name]))
		blocks.append("")
	$Layout/Body/Workspace/History/Content/Rows.text = "\n".join(blocks) if not blocks.is_empty() else "Brak zapisów z Forge."

func _build_relations(id: String) -> void:
	var links := $Layout/Body/Workspace/Content/ModelScroll/ModelColumn/Relations/Links
	for child in links.get_children():
		links.remove_child(child)
		child.queue_free()
	var database := ResourceLoader.load(GameDatabase.DEFAULT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDatabase
	if database == null:
		return
	for group in [[database.eggs, "Jajo"], [database.research, "Badanie"]]:
		for resource in group[0]:
			if resource == null or str(resource.creature_id) != id:
				continue
			var button := Button.new()
			button.text = group[1] + " · " + str(resource.display_name)
			button.pressed.connect(_open_related.bind(resource.resource_path))
			links.add_child(button)
	$Layout/Body/Workspace/Content/ModelScroll/ModelColumn/Relations.visible = links.get_child_count() > 0

func _open_related(path: String) -> void:
	if Engine.is_editor_hint():
		EditorInterface.edit_resource(ResourceLoader.load(path))
		_message("Powiązany zasób otwarto w Inspektorze Godota.")

func persist_draft() -> void:
	if not _initialized or not is_node_ready():
		return
	_fields.commit_fields()
	var error := _store.persist_draft(_changes)
	if not error.is_empty():
		_message(error, true)

func _print_value(value: Variant) -> String:
	if value is bool:
		return "Tak" if value else "Nie"
	if value is Dictionary or value is Array:
		return JSON.stringify(value)
	return str(value)

func _message(text: String, error := false) -> void:
	_validation_status = false
	_status.text = text
	_status.modulate = Color(1.0, 0.65, 0.52) if error else Color.WHITE

func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo and event.is_command_or_control_pressed() and event.keycode == KEY_S:
		_confirm_save()
		get_viewport().set_input_as_handled()
