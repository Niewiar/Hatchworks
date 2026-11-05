@tool
class_name ForgeDiscoveryStore
extends RefCounted

const DISCOVERY_FIELDS := ["id", "display_name", "description", "category", "reward_item", "reward_count"]
const RECIPE_FIELDS := ["id", "display_name", "description", "first", "second", "result", "science_reward"]

var last_error := ""
var _catalog_path := GameDatabase.DEFAULT_PATH
var _directory := ""
var _database: GameDatabase
var _baseline: Dictionary = {}
var _fingerprints: Dictionary = {}
var _paths: Dictionary = {}
var _cached_signatures: Dictionary = {}
var _transaction := ForgeFileTransaction.new()

func configure(catalog_path: String = GameDatabase.DEFAULT_PATH) -> void:
	_catalog_path = catalog_path
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var project_id := project.get_file() + "-" + project.sha256_text().left(12)
	_directory = project.get_base_dir().path_join("Hatchworks-workbench/forge").path_join(project_id)
	_transaction.configure(_directory, _catalog_path, _folders())

func load_database() -> GameDatabase:
	if _directory.is_empty():
		configure()
	last_error = _transaction.recover()
	if not last_error.is_empty():
		return null
	if not _catalog_path.begins_with("res://") or _catalog_path.simplify_path() != _catalog_path or _catalog_path.get_extension() != "tres":
		last_error = "Forge requires a project .tres catalog path."
		return null
	_database = ResourceLoader.load(_catalog_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as GameDatabase
	if _database == null:
		last_error = "Forge could not load %s." % _catalog_path
		return null
	_baseline = DiscoveryCatalogValidator.capture(_database)
	_paths.clear()
	for category: String in ["discoveries", "recipes"]:
		for record: Variant in _baseline[category]:
			if record is Dictionary:
				_paths[category + "/" + str(record.id)] = str(record.source_path)
	_fingerprints.clear()
	_cached_signatures.clear()
	_collect_files(_database, {})
	_fingerprints[_catalog_path] = FileAccess.get_sha256(_catalog_path)
	_cached_signatures[_catalog_path] = _signature(_database)
	return _database

func source_changed() -> bool:
	for path: String in _fingerprints:
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != _fingerprints[path]:
			return true
	return not _inspector_conflict().is_empty()

func validation_errors(document: ForgeDiscoveryDocument) -> PackedStringArray:
	var errors := PackedStringArray()
	for problem: Dictionary in document.problems():
		errors.append(str(problem.message))
	if _database == null:
		errors.append("The Forge catalog has not been loaded.")
		return errors
	if not errors.is_empty():
		return errors
	var built := _build_catalog(document.capture())
	if not built.error.is_empty():
		errors.append(built.error)
		return errors
	return GameDatabaseValidator.validate(built.database)

func save_document(document: ForgeDiscoveryDocument) -> String:
	if _database == null:
		return "The Forge catalog has not been loaded."
	if source_changed():
		var inspector := _inspector_conflict()
		return inspector if not inspector.is_empty() else "Source files changed outside Forge. Reload current data before saving. The draft has been preserved."
	var errors := validation_errors(document)
	if not errors.is_empty():
		return "\n".join(errors)
	if not document.is_dirty():
		return ""
	var snapshot := document.capture()
	var built := _build_catalog(snapshot)
	if not built.error.is_empty():
		return built.error
	var staging := _transaction.staging_directory()
	if staging.is_empty():
		return "Forge could not create a save staging directory."
	var outputs := {}
	for item: Dictionary in built.changed:
		var staged := staging.path_join(str(item.path).trim_prefix("res://"))
		var error := DirAccess.make_dir_recursive_absolute(staged.get_base_dir())
		if error == OK:
			error = ResourceSaver.save(item.resource, staged)
		if error != OK:
			return "Forge could not stage %s: %s." % [item.path, error_string(error)]
		if item.is_new:
			item.resource.resource_path = ""
		var uid_error := _preserve_uid(staged, item.path)
		if not uid_error.is_empty():
			return uid_error
		outputs[item.path] = staged
	if built.catalog_changed:
		var staged := staging.path_join("catalog.tres")
		for item: Dictionary in built.changed:
			if item.is_new:
				item.resource.resource_path = item.path
		var error := ResourceSaver.save(built.database, staged)
		for item: Dictionary in built.changed:
			if item.is_new:
				item.resource.resource_path = ""
		if error != OK:
			return "Forge could not stage the catalog: %s." % error_string(error)
		var uid_error := _preserve_uid(staged, _catalog_path)
		if not uid_error.is_empty():
			return uid_error
		outputs[_catalog_path] = staged
	var removed := _orphaned_sources(snapshot)
	var inspector := _inspector_conflict()
	if not inspector.is_empty():
		return inspector
	var result := _transaction.commit(staging, outputs, removed, _fingerprints)
	if not result.is_empty():
		return result
	_publish(outputs, removed)
	last_error = discard_draft()
	if load_database() == null:
		return "The data was saved, but Forge could not reload it: " + last_error
	document.mark_saved(DiscoveryCatalogValidator.capture(_database))
	return ""

func save_draft(document: ForgeDiscoveryDocument) -> String:
	if _directory.is_empty():
		configure()
	var value := {"version": 1, "catalog": _catalog_path, "fingerprints": _fingerprints, "snapshot": document.capture()}
	var error := ForgeFileTransaction.write_atomic(_directory.path_join("draft.json"), JSON.stringify(value, "\t"))
	return "" if error == OK else "Forge could not preserve the draft: %s." % error_string(error)

func restore_draft(document: ForgeDiscoveryDocument) -> String:
	var path := _directory.path_join("draft.json")
	if not FileAccess.file_exists(path):
		return "No saved Forge draft is available."
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16777216:
		return "The Forge draft could not be read."
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not value is Dictionary or value.get("version") != 1 or value.get("catalog") != _catalog_path or not value.get("snapshot") is Dictionary or not value.get("fingerprints") is Dictionary:
		return "The Forge draft has an unsupported format."
	if value.fingerprints != _fingerprints or source_changed():
		return "Source files changed since this draft was saved. The saved draft is preserved on disk; it was not applied over the newer source data."
	return document.restore_draft(value.snapshot)

func has_draft() -> bool:
	return not _directory.is_empty() and FileAccess.file_exists(_directory.path_join("draft.json"))

func discard_draft() -> String:
	if not has_draft():
		return ""
	var error := DirAccess.remove_absolute(_directory.path_join("draft.json"))
	return "" if error == OK else "Forge could not remove its saved draft: %s." % error_string(error)

func _build_catalog(snapshot: Dictionary) -> Dictionary:
	var result := {"database": _database.duplicate(false), "changed": [], "catalog_changed": false, "error": ""}
	for category: String in ["discoveries", "recipes"]:
		var resources: Array = []
		var before: Dictionary = {}
		var ids: Array[String] = []
		for record: Variant in _baseline[category]:
			if record is Dictionary:
				before[str(record.id)] = record
		for record: Dictionary in snapshot[category]:
			var id := str(record.id)
			var path := str(_paths.get(category + "/" + id, ""))
			if path.is_empty():
				if not _safe_id(id):
					result.error = "New entry ID cannot be used as a safe resource filename: %s." % id
					return result
				path = _catalog_path.get_base_dir().path_join(category).path_join(id + ".tres")
				if FileAccess.file_exists(path):
					result.error = "An unrelated resource already occupies %s." % path
					return result
			elif not _allowed_entry_path(path, category):
				result.error = "Forge cannot save an entry outside its trusted resource folder: %s." % path
				return result
			var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) if before.has(id) else (DiscoveryDefinition.new() if category == "discoveries" else DiscoveryRecipe.new())
			if resource == null:
				result.error = "Forge could not reload %s." % path
				return result
			for field: String in DISCOVERY_FIELDS if category == "discoveries" else RECIPE_FIELDS:
				resource.set(field, record[field])
			if category == "discoveries":
				var icon := str(record.icon)
				if not icon.is_empty() and (not icon.begins_with("res://") or not ResourceLoader.exists(icon)):
					result.error = "Discovery '%s' icon is unavailable: %s." % [id, icon]
					return result
				var texture := ResourceLoader.load(icon) as Texture2D if not icon.is_empty() else null
				if not icon.is_empty() and texture == null:
					result.error = "Discovery '%s' icon is unavailable: %s." % [id, icon]
					return result
				resource.set("icon", texture)
			resources.append(resource)
			ids.append(id)
			if not before.has(id) or not _same_record(before[id], record, category):
				result.changed.append({"resource": resource, "path": path, "is_new": not before.has(id)})
		var old_ids: Array[String] = []
		for record: Variant in _baseline[category]:
			old_ids.append(str(record.get("id", "")) if record is Dictionary else "")
		result.catalog_changed = result.catalog_changed or ids != old_ids
		if category == "discoveries":
			var discoveries: Array[DiscoveryDefinition] = []
			discoveries.assign(resources)
			result.database.discoveries = discoveries
		else:
			var recipes: Array[DiscoveryRecipe] = []
			recipes.assign(resources)
			result.database.recipes = recipes
	return result

func _same_record(before: Dictionary, after: Dictionary, category: String) -> bool:
	var fields: Array = DISCOVERY_FIELDS if category == "discoveries" else RECIPE_FIELDS
	for field: String in fields:
		if before.get(field) != after.get(field):
			return false
	return category != "discoveries" or before.icon == after.icon

func _orphaned_sources(snapshot: Dictionary) -> PackedStringArray:
	var removed := PackedStringArray()
	for category: String in ["discoveries", "recipes"]:
		var current := {}
		for record: Dictionary in snapshot[category]:
			current[str(record.id)] = true
		for record: Variant in _baseline[category]:
			if record is Dictionary and not current.has(str(record.id)) and _allowed_entry_path(str(record.source_path), category):
				removed.append(str(record.source_path))
	if removed.is_empty():
		return removed
	var referenced := {}
	_collect_references("res://", referenced)
	var unused := PackedStringArray()
	for path in removed:
		if not referenced.has(path):
			unused.append(path)
	return unused

func _collect_references(directory: String, referenced: Dictionary) -> void:
	var folder := DirAccess.open(directory)
	if folder == null:
		return
	for name in folder.get_directories():
		if name not in [".godot", ".git"]:
			_collect_references(directory.path_join(name), referenced)
	for name in folder.get_files():
		var path := directory.path_join(name)
		if path == _catalog_path:
			continue
		if path.get_extension() in ["tres", "tscn", "res", "scn"]:
			for dependency in ResourceLoader.get_dependencies(path):
				referenced[dependency.get_slice("::", dependency.get_slice_count("::") - 1)] = true
		elif path.get_extension() == "gd":
			var text := FileAccess.get_file_as_string(path)
			for source: String in _paths.values():
				if text.contains(source):
					referenced[source] = true

func _collect_files(resource: Resource, visited: Dictionary) -> void:
	if resource == null or visited.has(resource.get_instance_id()):
		return
	visited[resource.get_instance_id()] = true
	var path := resource.resource_path
	if path.begins_with("res://") and not path.contains("::") and path.get_extension() == "tres":
		_fingerprints[path] = FileAccess.get_sha256(path)
		if resource is DiscoveryDefinition or resource is DiscoveryRecipe:
			_cached_signatures[path] = _signature(resource)
	if not (resource is GameDatabase or resource is DatabaseEntry or resource is FancesDatabase):
		return
	for property: Dictionary in resource.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or property.name == "script":
			continue
		var value: Variant = resource.get(property.name)
		if value is Resource:
			_collect_files(value, visited)
		elif value is Array:
			for item: Variant in value:
				if item is Resource:
					_collect_files(item, visited)

func _folders() -> PackedStringArray:
	return PackedStringArray([_catalog_path.get_base_dir().path_join("discoveries"), _catalog_path.get_base_dir().path_join("recipes")])

func _allowed_entry_path(path: String, category: String) -> bool:
	return path.begins_with(_catalog_path.get_base_dir().path_join(category) + "/") and path.simplify_path() == path and path.get_extension() == "tres"

func _safe_id(id: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z0-9][A-Za-z0-9_-]*$")
	return expression.search(id) != null

func _preserve_uid(staged: String, target: String) -> String:
	if not FileAccess.file_exists(target):
		return ""
	var source := FileAccess.get_file_as_string(target)
	var content := FileAccess.get_file_as_string(staged)
	var expression := RegEx.new()
	expression.compile(" uid=\"[^\"]+\"")
	var original := expression.search(source.get_slice("\n", 0))
	var header := content.get_slice("\n", 0)
	var changed := expression.sub(header, "", true)
	if original != null:
		changed = changed.trim_suffix("]") + original.get_string() + "]"
	content = changed + content.substr(header.length())
	var file := FileAccess.open(staged, FileAccess.WRITE)
	if file == null:
		return "Forge could not preserve the UID of %s." % target
	file.store_string(content)
	file.close()
	return ""

func _inspector_conflict() -> String:
	for path: String in _cached_signatures:
		if ResourceLoader.has_cached(path):
			var cached := ResourceLoader.get_cached_ref(path)
			if cached != null and _signature(cached) != _cached_signatures[path]:
				return "A source resource has unsaved Inspector changes: %s. Save or undo them before writing from Forge. The Forge draft has been preserved." % path
	return ""

func _publish(outputs: Dictionary, removed: PackedStringArray) -> void:
	for path in removed:
		if ResourceLoader.has_cached(path):
			var cached := ResourceLoader.get_cached_ref(path)
			if cached != null:
				cached.resource_path = ""
	for path: String in outputs:
		if path == _catalog_path:
			continue
		var refreshed := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if refreshed != null:
			refreshed.emit_changed()
	if outputs.has(_catalog_path):
		var refreshed := ResourceLoader.load(_catalog_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if refreshed != null:
			refreshed.emit_changed()

func _signature(resource: Resource) -> String:
	var values := {}
	for property: Dictionary in resource.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) != 0 and property.name != "script":
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
