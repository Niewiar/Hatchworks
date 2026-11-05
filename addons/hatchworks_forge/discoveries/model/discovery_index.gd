@tool
class_name ForgeDiscoveryIndex
extends RefCounted

var _discoveries: Dictionary[String, Dictionary] = {}
var _recipes: Dictionary[String, Dictionary] = {}
var _incoming: Dictionary[String, Array] = {}
var _outgoing: Dictionary[String, Array] = {}
var _related: Dictionary[String, Array] = {}
var _slots: Dictionary[String, int] = {}
var _categories: Dictionary[int, int] = {}

func rebuild(snapshot: Dictionary) -> void:
	_discoveries.clear()
	_recipes.clear()
	_incoming.clear()
	_outgoing.clear()
	_related.clear()
	_slots.clear()
	_categories.clear()
	for category in DiscoveryDefinition.CATEGORY.values():
		_categories[category] = 0
	for record: Variant in snapshot.get("discoveries", []):
		if not record is Dictionary:
			continue
		var id := str(record.get("id", ""))
		if not _discoveries.has(id):
			_discoveries[id] = record.duplicate(true)
			_incoming[id] = []
			_outgoing[id] = []
			_related[id] = []
			_slots[id] = 0
		var value: Variant = record.get("category", -1)
		var category := int(value) if (value is int or value is float) and is_finite(float(value)) else -1
		_categories[category] = _categories.get(category, 0) + 1
	for record: Variant in snapshot.get("recipes", []):
		if not record is Dictionary:
			continue
		var recipe_record: Dictionary = record.duplicate(true)
		var id := str(record.get("id", ""))
		if not _recipes.has(id):
			_recipes[id] = recipe_record
		var first := str(record.get("first", ""))
		var second := str(record.get("second", ""))
		var result := str(record.get("result", ""))
		var references: Array[String] = []
		for ingredient in [first, second]:
			if _discoveries.has(ingredient):
				_slots[ingredient] += 1
				if not references.has(ingredient):
					_outgoing[ingredient].append(recipe_record)
					references.append(ingredient)
		if _discoveries.has(result):
			_incoming[result].append(recipe_record)
			if not references.has(result):
				references.append(result)
		for reference in references:
			_related[reference].append(recipe_record)

func discovery(id: String) -> Dictionary:
	return _discoveries.get(id, {}).duplicate(true)

func recipe(id: String) -> Dictionary:
	return _recipes.get(id, {}).duplicate(true)

func incoming(id: String) -> Array[Dictionary]:
	return _records(_incoming.get(id, []))

func outgoing(id: String) -> Array[Dictionary]:
	return _records(_outgoing.get(id, []))

func related(id: String) -> Array[Dictionary]:
	return _records(_related.get(id, []))

func usage(id: String) -> Dictionary:
	return {"recipes": _related.get(id, []).size(), "input": _outgoing.get(id, []).size(), "output": _incoming.get(id, []).size(), "slots": _slots.get(id, 0)}

func category_counts() -> Dictionary[int, int]:
	return _categories.duplicate()

func _records(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in source:
		result.append(record.duplicate(true))
	return result
