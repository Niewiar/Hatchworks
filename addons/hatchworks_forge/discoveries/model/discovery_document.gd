@tool
class_name ForgeDiscoveryDocument
extends RefCounted

signal changed

const HISTORY_LIMIT := 100
const DISCOVERY_FIELDS := ["display_name", "description", "category", "icon", "reward_item", "reward_count"]
const RECIPE_FIELDS := ["display_name", "description", "first", "second", "result", "science_reward"]

var index := ForgeDiscoveryIndex.new()
var _snapshot: Dictionary = {"discoveries": [], "recipes": []}
var _saved: Dictionary = {"discoveries": [], "recipes": []}
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []

func load_database(database: GameDatabase) -> void:
	_snapshot = DiscoveryCatalogValidator.capture(database)
	_saved = _snapshot.duplicate(true)
	_undo.clear()
	_redo.clear()
	_refresh()

func capture() -> Dictionary:
	return _snapshot.duplicate(true)

func discovery(id: String) -> Dictionary:
	return index.discovery(id)

func recipe(id: String) -> Dictionary:
	return index.recipe(id)

func add_discovery() -> String:
	var next := capture()
	var id := _unique_id("discovery", next.discoveries)
	next.discoveries.append({"id": id, "display_name": "New discovery", "description": "", "category": 0, "icon": "", "reward_item": "", "reward_count": 0, "source_path": ""})
	_apply(next)
	return id

func update_discovery(id: String, field: String, value: Variant) -> bool:
	return _update("discoveries", DISCOVERY_FIELDS, id, field, value)

func add_recipe(first: String = "", second: String = "", result: String = "") -> String:
	var next := capture()
	var id := _unique_id("recipe", next.recipes)
	next.recipes.append({"id": id, "display_name": "New recipe", "description": "", "first": first, "second": second, "result": result, "science_reward": 1, "source_path": ""})
	_apply(next)
	return id

func duplicate_recipe(id: String) -> String:
	var source := recipe(id)
	if source.is_empty():
		return ""
	var next := capture()
	var duplicate_id := _unique_id(id + "_copy", next.recipes)
	source.id = duplicate_id
	source.source_path = ""
	next.recipes.append(source)
	_apply(next)
	return duplicate_id

func update_recipe(id: String, field: String, value: Variant) -> bool:
	return _update("recipes", RECIPE_FIELDS, id, field, value)

func remove_recipe(id: String) -> bool:
	var next := capture()
	for index_in_array in next.recipes.size():
		if str(next.recipes[index_in_array].get("id", "")) == id:
			next.recipes.remove_at(index_in_array)
			_apply(next)
			return true
	return false

func restore_draft(snapshot: Dictionary) -> String:
	var error := _shape_error(snapshot)
	if not error.is_empty():
		return error
	var restored := snapshot.duplicate(true)
	for category in ["discoveries", "recipes"]:
		for entry: Dictionary in restored[category]:
			for field in ["category", "reward_count", "science_reward"]:
				if entry.has(field) and _whole_number(entry[field]):
					entry[field] = int(entry[field])
	_apply(restored)
	return ""

func mark_saved(snapshot: Dictionary = {}) -> void:
	if not snapshot.is_empty():
		_snapshot = snapshot.duplicate(true)
	_saved = capture()
	_refresh()

func is_dirty() -> bool:
	return _snapshot != _saved

func changed_count() -> int:
	var count := 0
	for category in ["discoveries", "recipes"]:
		var previous := {}
		for entry: Variant in _saved[category]:
			if entry is Dictionary:
				previous[str(entry.get("id", ""))] = entry
		for entry: Variant in _snapshot[category]:
			if not entry is Dictionary:
				count += 1
				continue
			var id := str(entry.get("id", ""))
			if previous.get(id) != entry:
				count += 1
			previous.erase(id)
		count += previous.size()
	return count

func problems() -> Array[Dictionary]:
	return DiscoveryCatalogValidator.validate(_snapshot)

func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()

func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(capture())
	_snapshot = _undo.pop_back()
	_refresh()

func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(capture())
	_snapshot = _redo.pop_back()
	_refresh()

func _update(category: String, allowed: Array, id: String, field: String, value: Variant) -> bool:
	if not allowed.has(field):
		return false
	var next := capture()
	for entry: Variant in next[category]:
		if entry is Dictionary and str(entry.get("id", "")) == id:
			if field in ["category", "reward_count", "science_reward"]:
				entry[field] = int(value) if _whole_number(value) else value
			else:
				entry[field] = str(value)
			_apply(next)
			return true
	return false

func _apply(next: Dictionary) -> void:
	if next == _snapshot:
		return
	_undo.append(capture())
	if _undo.size() > HISTORY_LIMIT:
		_undo.pop_front()
	_redo.clear()
	_snapshot = next
	_refresh()

func _refresh() -> void:
	index.rebuild(_snapshot)
	changed.emit()

func _unique_id(prefix: String, records: Array) -> String:
	var ids := {}
	for record: Variant in records:
		if record is Dictionary:
			ids[str(record.get("id", ""))] = true
	var safe_prefix := ""
	for position in mini(48, prefix.length()):
		var character := prefix[position]
		safe_prefix += character if "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_".contains(character) else "_"
	var result := "%s_%x" % [safe_prefix, ResourceUID.create_id()]
	while ids.has(result):
		result = "%s_%x" % [safe_prefix, ResourceUID.create_id()]
	return result

func _shape_error(snapshot: Dictionary) -> String:
	for category in ["discoveries", "recipes"]:
		if not snapshot.get(category) is Array:
			return "Draft requires discoveries and recipes arrays."
		if snapshot[category].size() > 100000:
			return "Draft catalog is too large."
		for entry: Variant in snapshot[category]:
			if not entry is Dictionary:
				return "Draft entries must be objects."
			var fields: Array = ["id", "display_name", "description", "source_path"]
			fields.append_array(["icon", "reward_item"] if category == "discoveries" else ["first", "second", "result"])
			for field in fields:
				if not entry.get(field) is String:
					return "Draft field '%s' must be text." % field
			for field in (["category", "reward_count"] if category == "discoveries" else ["science_reward"]):
				if not entry.get(field) is int and not entry.get(field) is float:
					return "Draft field '%s' must be numeric." % field
	return ""

func _whole_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))
