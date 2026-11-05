@tool
class_name ForgeCreatureStore
extends RefCounted

const LABELS = ForgeCreatureSchema.LABELS
const GROUPS = ForgeCreatureSchema.GROUPS
const ENUMS = ForgeCreatureSchema.ENUMS

var last_error := ""
var last_warning := ""
var _entries: Dictionary = {}
var _database: GameDatabase
var _fingerprints: Dictionary = {}
var _signatures: Dictionary = {}
var _directory := ""
var _transaction := ForgeFileTransaction.new()
var _draft_protected := false
var _draft_problem := ""
var _draft_seen_hash := ""

func load_entries() -> Array[Dictionary]:
	last_error = ""
	last_warning = ""
	if _directory.is_empty():
		var project := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
		var identity := project.get_file() + "-" + project.sha256_text().left(12)
		_directory = project.get_base_dir().path_join("Hatchworks-workbench/forge").path_join(identity).path_join("creatures")
		_transaction.configure(_directory, GameDatabase.DEFAULT_PATH, PackedStringArray(["res://resources/database/creatures"]))
	last_error = _transaction.recover()
	if not last_error.is_empty():
		return []
	_database = _load_catalog()
	if _database == null:
		last_error = "Nie udało się odczytać bazy gry."
		return []
	_entries.clear()
	_fingerprints.clear()
	_signatures.clear()
	_collect_files(_database, {})
	_signatures[GameDatabase.DEFAULT_PATH] = _signature(_database)
	for resource: CreatureSpecies in _database.creatures:
		if resource == null:
			continue
		var path := resource.resource_path
		if not _allowed(path) or _entries.has(str(resource.id)):
			last_error = "Baza zawiera nieprawidłowy lub powtórzony wpis kreatury."
			_entries.clear()
			return []
		var id := str(resource.id)
		_entries[id] = {"id": id, "name": str(resource.display_name), "path": path, "icon": resource.icon, "resource": resource, "fields": _schema(resource)}
		_signatures[path] = _signature(resource)
	var result: Array[Dictionary] = []
	for item: Dictionary in _entries.values():
		result.append(item)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return a.name.naturalnocasecmp_to(b.name) < 0)
	return result

func entry(id: String) -> Dictionary:
	return _entries.get(id, {})

func save(id: String, changes: Dictionary) -> String:
	last_warning = ""
	if not _entries.has(id) or _database == null:
		return "Nie wybrano kreatury z bazy."
	if changes.is_empty():
		return ""
	var conflict := _source_conflict()
	if not conflict.is_empty():
		return conflict
	var record: Dictionary = _entries[id]
	var resource := ResourceLoader.load(record.path, "", ResourceLoader.CACHE_MODE_IGNORE) as CreatureSpecies
	if resource == null:
		return "Nie udało się odczytać zasobu kreatury."
	var fields: Dictionary = {}
	for field: Dictionary in _schema(resource):
		fields[field.name] = field
	for name: Variant in changes:
		if not fields.has(name) or not fields[name].editable:
			return "Pole nie jest edytowalne: " + str(name)
		var error := _validate(fields[name], changes[name])
		if not error.is_empty():
			return str(fields[name].label) + ": " + error
	var before := {}
	for name: Variant in changes:
		before[name] = fields[name].value
		var value: Variant = changes[name]
		match int(fields[name].type):
			TYPE_INT:
				value = int(value)
			TYPE_FLOAT:
				value = float(value)
			TYPE_STRING_NAME:
				value = StringName(value)
			TYPE_DICTIONARY:
				var typed: Dictionary = resource.get(name).duplicate()
				typed.clear()
				for key: Variant in value:
					typed[StringName(key) if typed.get_typed_key_builtin() == TYPE_STRING_NAME else key] = float(value[key]) if typed.get_typed_value_builtin() == TYPE_FLOAT else value[key]
				value = typed
		resource.set(name, value)
	var database := _load_catalog()
	if database == null:
		return "Nie udało się odczytać bazy do walidacji."
	for index in database.creatures.size():
		if database.creatures[index] != null and str(database.creatures[index].id) == id:
			database.creatures[index] = resource
	var errors := GameDatabaseValidator.validate(database)
	if not errors.is_empty():
		return "\n".join(errors)
	var staging := _transaction.staging_directory()
	if staging.is_empty():
		return "Nie udało się przygotować zapisu."
	var staged := staging.path_join("creature.tres")
	var error := ResourceSaver.save(resource, staged)
	if error != OK:
		return "Nie udało się przygotować zasobu: " + error_string(error)
	var uid_error := _preserve_uid(staged, record.path)
	if not uid_error.is_empty():
		return uid_error
	conflict = _source_conflict()
	if not conflict.is_empty():
		return conflict
	var result := _transaction.commit(staging, {record.path: staged}, PackedStringArray(), _fingerprints)
	if not result.is_empty():
		return result
	var refreshed := ResourceLoader.load(record.path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if refreshed != null:
		refreshed.emit_changed()
	var records := _read_history()
	if records.has("error"):
		last_warning = records.error
	else:
		records.items.push_front({"id": id, "time": Time.get_datetime_string_from_system(), "changes": changes, "before": before})
		error = ForgeFileTransaction.write_atomic(_directory.path_join("history.json"), JSON.stringify(records.items, "\t"))
		if error != OK:
			last_warning = "Dane zapisano, ale nie udało się dopisać historii."
	var warning := last_warning
	load_entries()
	last_warning = warning
	return last_error

func persist_draft(changes_by_id: Dictionary) -> String:
	if _directory.is_empty():
		return "Nie wczytano bazy kreatur."
	var path := _directory.path_join("draft.json")
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) != _draft_seen_hash:
		_draft_protected = true
		_draft_problem = "Zapisany szkic zmienił się poza Forge. Zachowano go bez zmian."
	if _draft_protected and FileAccess.file_exists(path):
		if changes_by_id.is_empty():
			return _draft_problem
		var archive_error := _archive_protected_draft(path)
		if not archive_error.is_empty():
			return archive_error
	if changes_by_id.is_empty():
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(path)
			if error == OK:
				_draft_seen_hash = ""
			return "" if error == OK else "Nie udało się usunąć zapisanego szkicu."
		return ""
	var value := {"version": 1, "fingerprints": _fingerprints, "changes": changes_by_id}
	var error := ForgeFileTransaction.write_atomic(path, JSON.stringify(value, "\t"))
	if error == OK:
		_draft_seen_hash = FileAccess.get_sha256(path)
		_draft_protected = false
		_draft_problem = ""
	return "" if error == OK else "Nie udało się zachować szkicu: " + error_string(error)

func _archive_protected_draft(path: String) -> String:
	var digest := FileAccess.get_sha256(path)
	var archive := _directory.path_join("draft-history").path_join("%d-%d-%s.json" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec(), digest.left(12)])
	var error := DirAccess.make_dir_recursive_absolute(archive.get_base_dir())
	if error == OK:
		error = DirAccess.copy_absolute(path, archive)
	if error != OK or FileAccess.get_sha256(archive) != digest or FileAccess.get_sha256(path) != digest:
		return "Nie udało się zarchiwizować poprzedniego szkicu. Pozostawiono oryginał bez zmian."
	last_warning = "Poprzedni szkic zachowano w " + archive
	return ""

func _draft_result(result: Dictionary) -> Dictionary:
	var path := _directory.path_join("draft.json")
	_draft_seen_hash = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	_draft_problem = str(result.get("error", ""))
	_draft_protected = not _draft_problem.is_empty()
	return result

func load_draft() -> Dictionary:
	var result := {"changes": {}, "error": ""}
	var path := _directory.path_join("draft.json")
	if not FileAccess.file_exists(path):
		return _draft_result(result)
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		result.error = "Szkic kreatur jest uszkodzony. Zachowano plik bez zmian."
		return _draft_result(result)
	var value: Variant = parser.data
	if not value is Dictionary or value.get("version") != 1 or not value.get("changes") is Dictionary or not value.get("fingerprints") is Dictionary:
		result.error = "Nieprawidłowy format szkicu kreatur."
		return _draft_result(result)
	if value.fingerprints != _fingerprints or not _source_conflict().is_empty():
		result.error = "Źródła zmieniły się od zapisu szkicu. Zachowano szkic bez nakładania na nowsze dane."
		return _draft_result(result)
	for id: Variant in value.changes:
		if not _entries.has(id) or not value.changes[id] is Dictionary:
			result.error = "Szkic odwołuje się do nieznanej kreatury."
			return _draft_result(result)
		var fields := {}
		for field: Dictionary in _entries[id].fields:
			fields[field.name] = field
		for name: Variant in value.changes[id]:
			if not fields.has(name) or not fields[name].editable:
				result.error = "Szkic zawiera nieedytowalne pole."
				return _draft_result(result)
			var draft_value: Variant = value.changes[id][name]
			if int(fields[name].type) == TYPE_DICTIONARY and (draft_value is String or draft_value is Dictionary):
				continue
			var error := _validate(fields[name], draft_value)
			if not error.is_empty():
				result.error = "Szkic zawiera nieprawidłową wartość pola " + str(fields[name].label) + "."
				return _draft_result(result)
	result.changes = value.changes
	return _draft_result(result)

func history(id: String) -> Array:
	var data := _read_history()
	if data.has("error"):
		last_warning = data.error
		return []
	return data.items.filter(func(record: Dictionary): return str(record.get("id", record.get("key", "").trim_prefix("creatures/"))) == id)

func _read_history() -> Dictionary:
	var path := _directory.path_join("history.json")
	if not FileAccess.file_exists(path):
		return {"items": []}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Array:
		return {"error": "Historia kreatur jest uszkodzona; plik pozostawiono bez zmian."}
	for record: Variant in parser.data:
		if not record is Dictionary or not record.get("time") is String or not record.get("changes") is Dictionary:
			return {"error": "Historia kreatur ma nieprawidłowy wpis; plik pozostawiono bez zmian."}
	return {"items": parser.data}

func _schema(resource: CreatureSpecies) -> Array:
	var result: Array = []
	var group := "Podstawowe"
	for property: Dictionary in resource.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_GROUP:
			group = property.name
			continue
		if not (int(property.usage) & PROPERTY_USAGE_EDITOR) or not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = resource.get(property.name)
		var editable: bool = int(property.type) in [TYPE_STRING, TYPE_STRING_NAME, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_DICTIONARY] and str(property.name) != "id"
		if value is Resource:
			value = value.resource_path
		var field_group: String = "Podstawowe" if property.name in ["id", "display_name", "description", "scene", "icon"] else group
		var options: Array = []
		if int(property.hint) == PROPERTY_HINT_ENUM:
			var index := 0
			for option in str(property.hint_string).split(","):
				var parts := option.split(":")
				if parts.size() > 1:
					index = int(parts[1])
				options.append({"value": index, "label": ENUMS.get(parts[0], parts[0])})
				index += 1
		if property.name == "food_resource" and _database != null:
			for food: ResourceDefinition in _database.resources:
				if food != null:
					options.append({"value": food.kind, "label": food.display_name})
		result.append({"name": str(property.name), "label": LABELS.get(property.name, str(property.name)), "group": field_group, "group_label": GROUPS.get(field_group, field_group), "type": property.type, "hint": property.hint, "hint_string": property.hint_string, "value": value, "editable": editable, "options": options})
	return ForgeCreatureSchema.describe(result, resource, _database)

func _validate(field: Dictionary, value: Variant) -> String:
	return ForgeCreatureSchema.field_error(field,value,_entries.keys())

func _collect_files(resource: Resource, visited: Dictionary) -> void:
	if resource == null or visited.has(resource.get_instance_id()):
		return
	visited[resource.get_instance_id()] = true
	var path := resource.resource_path
	if path.begins_with("res://") and not path.contains("::") and path.get_extension() == "tres":
		_fingerprints[path] = FileAccess.get_sha256(path)
	if not (resource is GameDatabase or resource is DatabaseEntry or resource is FancesDatabase):
		return
	for property: Dictionary in resource.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or property.name == "script":
			continue
		var value: Variant = resource.get(property.name)
		if value is Resource:
			_collect_files(value, visited)
		elif value is Array:
			for item: Variant in value:
				if item is Resource:
					_collect_files(item, visited)

func _load_catalog() -> GameDatabase:
	var source := ResourceLoader.load(GameDatabase.DEFAULT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDatabase
	return _fresh_data(source, {}) as GameDatabase if source != null else null

func _fresh_data(source: Resource, detached: Dictionary) -> Resource:
	if not (source is GameDatabase or source is DatabaseEntry or source is FancesDatabase):
		return source
	var path := source.resource_path
	var external := path.begins_with("res://") and not path.contains("::")
	var key := path if external else "#" + str(source.get_instance_id())
	if detached.has(key):
		return detached[key]
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) if external else source.duplicate(false)
	if resource == null:
		return null
	detached[key] = resource
	for property: Dictionary in resource.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or property.name == "script":
			continue
		var value: Variant = resource.get(property.name)
		if value is Resource and (value is GameDatabase or value is DatabaseEntry or value is FancesDatabase):
			resource.set(property.name, _fresh_data(value, detached))
		elif value is Array:
			var items: Array = value.duplicate()
			var changed := false
			for index in items.size():
				var item: Variant = items[index]
				if item is Resource and (item is GameDatabase or item is DatabaseEntry or item is FancesDatabase):
					items[index] = _fresh_data(item, detached)
					changed = true
			if changed:
				resource.set(property.name, items)
	return resource

func _source_conflict() -> String:
	for path: String in _fingerprints:
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != _fingerprints[path]:
			return "Dane zmieniły się poza Forge. Odśwież bazę przed zapisem; szkic zachowano."
	for path: String in _signatures:
		if ResourceLoader.has_cached(path):
			var cached := ResourceLoader.get_cached_ref(path)
			if cached != null and _signature(cached) != _signatures[path]:
				return "Zasób ma niezapisane zmiany w Inspektorze: " + path
	return ""

func _signature(resource: Resource) -> String:
	var values := {}
	for property: Dictionary in resource.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != "script":
			values[str(property.name)] = _signature_value(resource.get(property.name))
	return var_to_bytes(values).hex_encode().sha256_text()

func _signature_value(value: Variant) -> Variant:
	if value is Resource:
		return value.resource_path if not value.resource_path.is_empty() and not value.resource_path.contains("::") else _signature(value)
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_signature_value(item))
		return items
	if value is Dictionary:
		var items := {}
		for key: Variant in value:
			items[key] = _signature_value(value[key])
		return items
	return value

func _allowed(path: String) -> bool:
	return path.begins_with("res://resources/database/creatures/") and path.simplify_path() == path and not path.contains("::") and path.get_extension() == "tres"

func _preserve_uid(staged: String, target: String) -> String:
	var source := FileAccess.get_file_as_string(target)
	var content := FileAccess.get_file_as_string(staged)
	var expression := RegEx.create_from_string(" uid=\"[^\"]+\"")
	var original := expression.search(source.get_slice("\n", 0))
	var header := content.get_slice("\n", 0)
	var changed := expression.sub(header, "", true)
	if original != null:
		changed = changed.trim_suffix("]") + original.get_string() + "]"
	content = changed + content.substr(header.length())
	var file := FileAccess.open(staged, FileAccess.WRITE)
	if file == null:
		return "Nie udało się zachować UID kreatury."
	file.store_string(content)
	file.close()
	return ""
