@tool
class_name DiscoveryCatalogValidator
extends RefCounted

static func capture(database: GameDatabase) -> Dictionary:
	var snapshot := {"discoveries": [], "recipes": []}
	if database == null:
		return snapshot
	for entry: DiscoveryDefinition in database.discoveries:
		if entry == null:
			snapshot.discoveries.append(null)
			continue
		snapshot.discoveries.append({"id": str(entry.id), "display_name": entry.display_name, "description": entry.description, "category": entry.category, "icon": entry.icon.resource_path if entry.icon != null else "", "reward_item": str(entry.reward_item), "reward_count": entry.reward_count, "source_path": entry.resource_path})
	for entry: DiscoveryRecipe in database.recipes:
		if entry == null:
			snapshot.recipes.append(null)
			continue
		snapshot.recipes.append({"id": str(entry.id), "display_name": entry.display_name, "description": entry.description, "first": str(entry.first), "second": str(entry.second), "result": str(entry.result), "science_reward": entry.science_reward, "source_path": entry.resource_path})
	return snapshot

static func validate(snapshot: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if not snapshot.get("discoveries") is Array or not snapshot.get("recipes") is Array:
		issues.append(_issue("invalid_snapshot", "Discovery data requires discoveries and recipes arrays.", [], [], []))
		return issues
	var discoveries := _index(snapshot.discoveries, "discovery", issues)
	_index(snapshot.recipes, "recipe", issues)
	for entry: Variant in snapshot.discoveries:
		if not entry is Dictionary:
			continue
		var id := str(entry.get("id", ""))
		if not entry.get("display_name") is String or str(entry.display_name).strip_edges().is_empty():
			issues.append(_issue("missing_name", "Discovery '%s' needs a name." % id, [id], [], ["display_name"]))
		if not _integer(entry.get("category"), 0, DiscoveryDefinition.CATEGORY.size() - 1):
			issues.append(_issue("invalid_category", "Discovery '%s' has an unsupported category." % id, [id], [], ["category"]))
		if not _valid_icon(entry.get("icon", "")):
			issues.append(_issue("invalid_icon", "Discovery '%s' icon must reference an existing project Texture2D." % id, [id], [], ["icon"]))
		if not _integer(entry.get("reward_count"), 0, 100):
			issues.append(_issue("invalid_reward", "Discovery '%s' reward count must be an integer from 0 to 100." % id, [id], [], ["reward_count"]))
		elif int(entry.reward_count) > 0 and str(entry.get("reward_item", "")).is_empty():
			issues.append(_issue("missing_reward", "Discovery '%s' has a reward count without a reward item." % id, [id], [], ["reward_item"]))
	var pairs := {}
	for entry: Variant in snapshot.recipes:
		if not entry is Dictionary:
			continue
		var id := str(entry.get("id", ""))
		var valid_ingredients := true
		for field in ["first", "second", "result"]:
			var reference := str(entry.get(field, ""))
			if not discoveries.has(reference):
				issues.append(_issue("missing_reference", "Recipe '%s' %s references an unavailable discovery '%s'." % [id, field, reference], [reference] if not reference.is_empty() else [], [id], [field]))
				if field != "result":
					valid_ingredients = false
		if not _integer(entry.get("science_reward"), 0, 1000):
			issues.append(_issue("invalid_science", "Recipe '%s' science reward must be an integer from 0 to 1000." % id, [], [id], ["science_reward"]))
		if valid_ingredients:
			var ingredients: Array[String] = [str(entry.first), str(entry.second)]
			ingredients.sort()
			var key := JSON.stringify(ingredients)
			if not pairs.has(key):
				pairs[key] = []
			pairs[key].append(entry)
	for members: Array in pairs.values():
		if members.size() < 2:
			continue
		var recipe_ids: Array[String] = []
		for entry: Dictionary in members:
			recipe_ids.append(str(entry.id))
		var first := str(members[0].first)
		var second := str(members[0].second)
		issues.append(_issue("duplicate_pair", "The pair '%s' + '%s' occurs in %d recipes. Reversed ingredients are the same pair." % [first, second, members.size()], [first, second], recipe_ids, ["first", "second"]))
	return issues

static func _index(entries: Array, kind: String, issues: Array[Dictionary]) -> Dictionary:
	var result := {}
	for index in entries.size():
		var entry: Variant = entries[index]
		if not entry is Dictionary:
			issues.append(_issue("invalid_entry", "%s[%d] is missing or malformed." % [kind, index], [], [], []))
			continue
		var id: Variant = entry.get("id")
		if not id is String or str(id).strip_edges().is_empty() or result.has(id):
			issues.append(_issue("invalid_id", "%s[%d] needs a nonempty, unique ID (%s)." % [kind, index, id], [str(id)] if kind == "discovery" else [], [str(id)] if kind == "recipe" else [], ["id"]))
		else:
			result[id] = entry
	return result

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _valid_icon(value: Variant) -> bool:
	if not value is String:
		return false
	if value.is_empty():
		return true
	return value.begins_with("res://") and ResourceLoader.exists(value) and ResourceLoader.load(value) is Texture2D

static func _issue(code: String, message: String, discoveries: Array, recipes: Array, fields: Array) -> Dictionary:
	return {"code": code, "message": message, "discovery_ids": discoveries, "recipe_ids": recipes, "fields": fields}
