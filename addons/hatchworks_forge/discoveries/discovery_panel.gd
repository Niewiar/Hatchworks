@tool
class_name ForgeDiscoveryPanel
extends VBoxContainer

var document := ForgeDiscoveryDocument.new()
var _store := ForgeDiscoveryStore.new()
var _selected_discovery := "seed"
var _selected_recipe := "seed_life_egg"
var _refresh_pending := false
var _source_conflict := false
var _confirmation := ""

func _ready() -> void:
	_store.configure()
	document.changed.connect(_queue_refresh)
	%Undo.pressed.connect(_undo)
	%Redo.pressed.connect(_redo)
	%Save.pressed.connect(_save_data)
	%SaveDraft.pressed.connect(_save_draft)
	%RestoreDraft.pressed.connect(_request_restore)
	%Reload.pressed.connect(_request_reload)
	%Confirmation.confirmed.connect(_confirm)
	%AddDiscovery.pressed.connect(_add_discovery)
	%AddRecipe.pressed.connect(_add_recipe)
	%DiscoveryChoice.item_selected.connect(_select_discovery)
	%SourceTimer.timeout.connect(_check_sources)
	%Graph.discovery_selected.connect(_open_discovery)
	%Graph.recipe_selected.connect(_open_recipe)
	%Usage.discovery_selected.connect(_open_discovery)
	%Usage.recipe_selected.connect(_open_recipe)
	%Inspector.recipe_selected.connect(_open_recipe)
	%Inspector.conflicts_requested.connect(_open_conflicts)
	%Conflicts.discovery_selected.connect(_open_discovery)
	%Conflicts.recipe_selected.connect(_open_recipe)
	_load_database()
	%Graph.configure(document)
	%Usage.configure(document)
	%Inspector.configure(document)
	%Conflicts.configure(document)
	%Views.set_tab_title(0,"Połączenia")
	%Views.set_tab_title(1,"Użycie kafli")
	_queue_refresh()

func _load_database() -> void:
	var database := _store.load_database()
	if database == null:
		_status(_store.last_error,true)
		%Save.disabled = true
		return
	if DiscoveryCatalogValidator.capture(database) != document.capture() or document.is_dirty():
		document.load_database(database)
	var previous_conflict := _source_conflict
	_source_conflict = _store.source_changed()
	if previous_conflict != _source_conflict:
		_queue_refresh()
	_status("Znaleziono zachowany szkic." if _store.has_draft() else "Dane odkryć wczytane.")

func _queue_refresh() -> void:
	if not _refresh_pending:
		_refresh_pending = true
		_refresh.call_deferred()

func _refresh() -> void:
	_refresh_pending = false
	if not is_inside_tree():
		return
	var snapshot := document.capture()
	var entries: Array = snapshot.discoveries.filter(func(entry: Variant): return entry is Dictionary)
	entries.sort_custom(func(a: Dictionary,b: Dictionary): return str(a.display_name).naturalnocasecmp_to(str(b.display_name)) < 0)
	if document.discovery(_selected_discovery).is_empty():
		_selected_discovery = str(entries[0].id) if not entries.is_empty() else ""
	if document.recipe(_selected_recipe).is_empty():
		var related := document.index.related(_selected_discovery)
		_selected_recipe = str(related[0].id) if not related.is_empty() else ""
	%DiscoveryChoice.set_block_signals(true)
	%DiscoveryChoice.clear()
	for entry: Dictionary in entries:
		%DiscoveryChoice.add_item(str(entry.display_name))
		var index: int = %DiscoveryChoice.item_count-1
		%DiscoveryChoice.set_item_metadata(index,str(entry.id))
		if entry.id == _selected_discovery:
			%DiscoveryChoice.select(index)
	%DiscoveryChoice.set_block_signals(false)
	var problems := document.problems()
	%Views.set_tab_title(2,"Konflikty (%d)" % problems.size())
	%Undo.disabled = not document.can_undo()
	%Redo.disabled = not document.can_redo()
	%RestoreDraft.disabled = not _store.has_draft()
	%Save.disabled = _source_conflict or not problems.is_empty() or entries.is_empty()
	%SourceNotice.visible = _source_conflict
	%State.text = "Szkic · %d zmian" % document.changed_count() if document.is_dirty() else "Brak niezapisanych zmian"
	if not problems.is_empty():
		%State.text += " · zapis danych zablokowany"
	%Totals.text = "%d kafli · %d receptur" % [entries.size(),snapshot.recipes.size()]
	%Graph.show_discovery(_selected_discovery,_selected_recipe)
	%Usage.refresh()
	%Inspector.show_discovery(_selected_discovery,_selected_recipe)
	%Conflicts.refresh()

func _select_discovery(index: int) -> void:
	_open_discovery(str(%DiscoveryChoice.get_item_metadata(index)))

func _open_discovery(id: String) -> void:
	%Inspector.commit_fields()
	_selected_discovery = id
	var related := document.index.related(id)
	_selected_recipe = str(related[0].id) if not related.is_empty() else ""
	%Views.current_tab = 0
	_queue_refresh()

func _open_recipe(id: String) -> void:
	%Inspector.commit_fields()
	var entry := document.recipe(id)
	if entry.is_empty():
		return
	if not document.index.related(_selected_discovery).any(func(record: Dictionary): return record.id == id):
		for field in ["first","result","second"]:
			if not document.discovery(str(entry[field])).is_empty():
				_selected_discovery = str(entry[field])
				break
	_selected_recipe = id
	%Views.current_tab = 0
	_queue_refresh()

func _open_conflicts() -> void:
	%Views.current_tab = 2

func _add_discovery() -> void:
	%Inspector.commit_fields()
	_selected_discovery = document.add_discovery()
	_selected_recipe = ""
	%Views.current_tab = 0
	_queue_refresh()

func _add_recipe() -> void:
	%Inspector.commit_fields()
	_selected_recipe = document.add_recipe(_selected_discovery)
	%Views.current_tab = 0
	_queue_refresh()

func _undo() -> void:
	%Inspector.commit_fields()
	document.undo()

func _redo() -> void:
	document.redo()

func _save_data() -> void:
	%Inspector.commit_fields()
	if not document.problems().is_empty():
		_status("Popraw konflikty przed zapisem danych.",true)
		_open_conflicts()
		_queue_refresh()
		return
	var error := _store.save_document(document)
	if not error.is_empty():
		_status(error,true)
		_source_conflict = _store.source_changed()
		_queue_refresh()
		if not document.problems().is_empty():
			_open_conflicts()
		return
	_source_conflict = false
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	_status("Zapisano dane odkryć. Kopia poprzednich plików jest w katalogu roboczym.")
	_queue_refresh()

func _save_draft() -> void:
	%Inspector.commit_fields()
	var error := _store.save_draft(document)
	_status("Szkic zachowany, także z konfliktami." if error.is_empty() else error,not error.is_empty())
	_queue_refresh()

func persist_draft() -> void:
	if not is_node_ready():
		return
	%Inspector.commit_fields()
	if document.is_dirty():
		var error := _store.save_draft(document)
		if not error.is_empty():
			push_error("Hatchworks Forge: "+error)

func _request_restore() -> void:
	%Inspector.commit_fields()
	if document.is_dirty():
		_confirmation = "restore"
		%Confirmation.dialog_text = "Przywrócić zachowany szkic i zastąpić nim bieżące zmiany?"
		%Confirmation.popup_centered()
	else:
		_restore_draft()

func _restore_draft() -> void:
	var error := _store.restore_draft(document)
	_status("Przywrócono szkic." if error.is_empty() else error,not error.is_empty())
	_queue_refresh()

func _request_reload() -> void:
	%Inspector.commit_fields()
	if document.is_dirty():
		_confirmation = "reload"
		%Confirmation.dialog_text = "Zachować bieżący szkic i wczytać zmienione pliki projektu?"
		%Confirmation.popup_centered()
	else:
		_load_database()

func _confirm() -> void:
	if _confirmation == "restore":
		_restore_draft()
	elif _confirmation == "reload":
		var error := _store.save_draft(document)
		if not error.is_empty():
			_status(error,true)
			return
		_load_database()
	_confirmation = ""

func _check_sources() -> void:
	if not _store.source_changed():
		if _source_conflict:
			_source_conflict = false
			_queue_refresh()
		return
	%Inspector.commit_fields()
	if document.is_dirty():
		_source_conflict = true
		_queue_refresh()
	else:
		_load_database()

func _status(message: String, error := false) -> void:
	%Status.text = message
	%Status.theme_type_variation = &"ForgeError" if error else &"ForgeMuted"

func _shortcut_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo or not event.is_command_or_control_pressed():
		return
	if event.keycode == KEY_S:
		if event.shift_pressed:
			_save_draft()
		else:
			_save_data()
	elif event.keycode in [KEY_Z,KEY_Y]:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		if event.keycode == KEY_Y or event.shift_pressed:
			_redo()
		else:
			_undo()
	else:
		return
	get_viewport().set_input_as_handled()
