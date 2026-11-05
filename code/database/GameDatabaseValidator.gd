class_name GameDatabaseValidator
extends RefCounted

static func validate(database: GameDatabase) -> PackedStringArray:
	var errors := PackedStringArray()
	for problem: Dictionary in DiscoveryCatalogValidator.validate(DiscoveryCatalogValidator.capture(database)):
		if problem.code not in ["invalid_entry", "invalid_id"]:
			errors.append(problem.message)
	var catalogs := {
		"discoveries":database.discoveries,"recipes":database.recipes,"buildings":database.buildings,
		"eggs":database.eggs,"glossary":database.glossary,"creatures":database.creatures,
		"science_projects":database.science_projects,"research":database.research,"flora":database.flora,"resources":database.resources,"deposits":database.deposits
	}
	if database.world == null:
		errors.append("world: missing WorldBalance resource.")
	else:
		_check_numbers(database.world,["trade_fee_percent"],0.0,99.0,errors)
		_check_numbers(database.world,["science_trade_value"],0.0001,INF,errors)
		_check_numbers(database.world,["science_project_interval"],1.0,86400.0,errors)
		_check_numbers(database.world,["science_project_cost_ratio"],1.01,10.0,errors)
		_check_numbers(database.world,["starting_height_variation","spawn_clearing_radius","starting_pond_radius"],0.0,INF,errors)
		_check_numbers(database.world,["terrain_wavelength","sculpt_speed"],0.0001,INF,errors)
		_check_numbers(database.world,["maximum_sculpt_slope"],0.0,89.0,errors)
		if not is_finite(database.world.water_level) or not database.world.starting_pond_offset.is_finite():
			errors.append("world: water level and pond offset must be finite.")
	if database.construction == null:
		errors.append("construction: missing FancesDatabase resource.")
	else:
		catalogs["fences"] = database.construction.fances
	var ids := {}
	for category: String in catalogs:
		ids[category] = _index(catalogs[category],category,errors)
	for required: String in ["soil","life","water","grass","sand","rock"]:
		_reference(ids.discoveries,required,"startup.discovery",errors)
	var kinds := {}
	for entry: ResourceDefinition in database.resources:
		if entry == null:
			continue
		if entry.kind not in ResourceInventory.KIND.values() or kinds.has(entry.kind):
			errors.append("resources/%s: resource kind must be supported and unique." % entry.id)
		kinds[entry.kind] = true
		_check_numbers(entry,["starting_amount","trade_value"],0.0,INF,errors)
	for kind: int in ResourceInventory.KIND.values():
		_reference(kinds,kind,"resources.kind",errors)
	for entry: ScienceProjectDefinition in database.science_projects:
		if entry == null:
			continue
		_check_numbers(entry,["science_reward"],1,1000000,errors)
		if entry.costs.is_empty():
			errors.append("science_projects/%s: at least one material is required." % entry.id)
		for kind: int in entry.costs:
			_reference(kinds,kind,"science_projects/%s.costs" % entry.id,errors)
			if entry.costs[kind] < 1 or entry.costs[kind] > 1000000:
				errors.append("science_projects/%s: costs must be positive whole units." % entry.id)
			for resource: ResourceDefinition in database.resources:
				if resource != null and resource.kind == kind and resource.trade_value <= 0.0:
					errors.append("science_projects/%s: required materials need a positive trade value." % entry.id)
	var items: Dictionary = ids.eggs.duplicate()
	for entry: FloraSpecies in database.flora:
		if entry == null:
			continue
		_reference(kinds,entry.harvest_resource,"flora/%s.harvest_resource" % entry.id,errors)
		_check_numbers(entry,["spacing","minimum_scale","maximum_scale","growth_rate"],0.0001,INF,errors)
		_check_numbers(entry,["density","canopy_radius","trunk_radius","trunk_height","maximum_slope","harvest_amount"],0.0,INF,errors)
		_check_numbers(entry,["sapling_chance"],0.0,1.0,errors)
		_ordered(entry,"minimum_scale","maximum_scale",errors)
		if entry.kind not in FloraSpecies.KIND.values() or entry.hits_required < 1 or entry.ground_material < -1 or entry.ground_material > 4:
			errors.append("flora/%s: invalid kind, ground material or hit count." % entry.id)
		if not entry.water_depth_range.is_finite() or entry.water_depth_range.x > entry.water_depth_range.y:
			errors.append("flora/%s: water depth range must be finite and ordered." % entry.id)
		_meshes(entry,errors)
		if not entry.sapling_item.is_empty():
			if items.has(entry.sapling_item):
				errors.append("flora/%s: sapling item must have a unique item ID." % entry.id)
			items[entry.sapling_item] = entry
	for entry: DiscoveryDefinition in database.discoveries:
		if entry == null:
			continue
		if entry.reward_count > 0:
			_reference(items,entry.reward_item,"discoveries/%s.reward_item" % entry.id,errors)
	for entry: CreatureSpecies in database.creatures:
		if entry == null:
			continue
		_creature(entry,ids.creatures,kinds,errors)
	for entry: EggDefinition in database.eggs:
		if entry == null:
			continue
		_reference(ids.creatures,entry.creature_id,"eggs/%s.creature_id" % entry.id,errors)
		_reference(ids.discoveries,entry.id,"eggs.discovery",errors)
		_required_asset(entry,"model",errors)
		_check_numbers(entry,["incubation_seconds","crafting_seconds"],0.0001,INF,errors)
		_check_numbers(entry,["science_cost","fiber_cost","wood_cost","stone_cost"],0.0,INF,errors)
	for entry: CreatureResearch in database.research:
		if entry == null:
			continue
		_reference(ids.creatures,entry.creature_id,"research/%s.creature_id" % entry.id,errors)
		if entry.action_id.is_empty():
			errors.append("research/%s: action ID is required." % entry.id)
		_check_numbers(entry,["science_reward"],0.0,INF,errors)
	for entry: BuildingDefinition in database.buildings:
		if entry == null:
			continue
		_required_asset(entry,"scene",errors)
		_optional_reference(ids.discoveries,entry.required_discovery,"buildings/%s.required_discovery" % entry.id,errors)
		_check_numbers(entry,["wood_cost","stone_cost","fiber_cost","cost_growth_percent","maximum_height_difference"],0.0,INF,errors)
		_check_numbers(entry,["footprint_radius","max_health","storage_capacity"],0.0001,INF,errors)
		if entry.cost_scaling not in BuildingDefinition.COST_SCALING.values():
			errors.append("buildings/%s: unsupported cost scaling mode." % entry.id)
	for entry: DepositDefinition in database.deposits:
		if entry == null:
			continue
		_reference(kinds,entry.harvest_resource,"deposits/%s.harvest_resource" % entry.id,errors)
		_check_numbers(entry,["spacing","minimum_scale","maximum_scale","hits_required","harvest_amount"],0.0001,INF,errors)
		_check_numbers(entry,["density"],0.0,INF,errors)
		_ordered(entry,"minimum_scale","maximum_scale",errors)
		_meshes(entry,errors)
	if database.construction != null:
		for entry: FanceData in database.construction.fances:
			if entry == null:
				continue
			_reference(kinds,entry.construction_resource,"fences/%s.construction_resource" % entry.id,errors)
			_optional_reference(ids.discoveries,entry.required_discovery,"fences/%s.required_discovery" % entry.id,errors)
			_check_numbers(entry,["max_span_length","height","post_width","thickness","max_health","post_max_health"],0.0001,INF,errors)
			_check_numbers(entry,["material_per_meter","material_per_post"],0.0,INF,errors)
	return errors

static func _creature(entry: CreatureSpecies, creatures: Dictionary, kinds: Dictionary, errors: PackedStringArray) -> void:
	_required_asset(entry,"scene",errors)
	_reference(kinds,entry.food_resource,"creatures/%s.food_resource" % entry.id,errors)
	_check_numbers(entry,["terrain_happiness_penalty","unhappy_threshold","happy_threshold","breeding_min_satiety","breeding_satiety_cost","feeding_threshold","satiety_per_meal"],0.0,100.0,errors)
	if entry.unhappy_threshold >= entry.happy_threshold:
		errors.append("creatures/%s: unhappy_threshold must be below happy_threshold." % entry.id)
	_check_numbers(entry,["noise_sensitivity","crowding_sensitivity"],0.0,1.0,errors)
	_check_numbers(entry,["hold_height","follow_speed","rotation_speed","walk_speed","swim_speed","minimum_swim_depth","bathing_seconds","shaking_seconds","resting_seconds","feeding_seconds","breeding_seconds","breeding_cooldown","satiety_seconds","leisure_seconds_min","leisure_seconds_max","happiness_response_seconds","preferred_area","company_radius","breeding_call_seconds","production_seconds","impact_time","production_radius","impact_radius","impact_strength","impact_damage","aggression_cooldown","grass_radius"],0.0001,INF,errors)
	_check_numbers(entry,["grass_per_cycle","food_per_feeding","production_limit"],1.0,INF,errors)
	_ordered(entry,"leisure_seconds_min","leisure_seconds_max",errors)
	_ordered(entry,"impact_time","production_seconds",errors)
	if entry.habitat_ground < -1 or entry.habitat_ground > 4 or entry.production not in CreatureSpecies.PRODUCTION.values() or entry.female_production not in CreatureSpecies.PRODUCTION.values():
		errors.append("creatures/%s: unsupported habitat or production type." % entry.id)
	for id: StringName in entry.species_aversions:
		_reference(creatures,id,"creatures/%s.species_aversions" % entry.id,errors)
		var strength: float = entry.species_aversions[id]
		if not is_finite(strength) or strength < 0.0 or strength > 1.0:
			errors.append("creatures/%s: aversion strengths must be finite values from 0 to 1." % entry.id)
	for field: String in ["terrain_minimums","female_terrain_minimums"]:
		var issue := terrain_minimums_error(entry.get(field))
		if not issue.is_empty():
			errors.append("creatures/%s.%s: %s" % [entry.id,field,issue])
	var graph_error := CreatureAiGraph.validate(entry.ai_graph)
	if not graph_error.is_empty():
		errors.append("creatures/%s.ai_graph: %s" % [entry.id,graph_error])

static func terrain_minimums_error(value: Variant) -> String:
	if not value is Dictionary:
		return "Terrain minimums must be a JSON object."
	var total := 0.0
	for kind in value:
		if String(kind) not in ["grass","soil","sand","rock"]:
			return "Supported terrain names: grass, soil, sand, rock."
		var amount: Variant = value[kind]
		if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) < 0.0 or float(amount) > 100.0:
			return "Terrain minimums must be finite numeric percentages from 0 to 100."
		total += float(amount)
	return "Terrain minimums must total no more than 100 percent." if total > 100.0001 else ""

static func _index(entries: Array, category: String, errors: PackedStringArray) -> Dictionary:
	var result := {}
	for index: int in entries.size():
		var entry: DatabaseEntry = entries[index]
		if entry == null:
			errors.append("%s[%d]: missing resource." % [category,index])
		elif entry.id.is_empty() or result.has(entry.id):
			errors.append("%s[%d]: entry ID must be nonempty and unique (%s)." % [category,index,entry.id])
		else:
			result[entry.id] = entry
	return result

static func _reference(entries: Dictionary, id: Variant, field: String, errors: PackedStringArray) -> void:
	if not entries.has(id):
		errors.append("%s: unknown reference '%s'." % [field,id])

static func _optional_reference(entries: Dictionary, id: StringName, field: String, errors: PackedStringArray) -> void:
	if not id.is_empty():
		_reference(entries,id,field,errors)

static func _check_numbers(entry: DatabaseEntry, fields: Array, minimum: float, maximum: float, errors: PackedStringArray) -> void:
	for field: String in fields:
		var value := float(entry.get(field))
		if not is_finite(value) or value < minimum or value > maximum:
			errors.append("%s.%s: value must be finite and between %s and %s." % [entry.id,field,minimum,maximum])

static func _ordered(entry: DatabaseEntry, first: String, second: String, errors: PackedStringArray) -> void:
	if entry.get(first) > entry.get(second):
		errors.append("%s: %s must not exceed %s." % [entry.id,first,second])

static func _required_asset(entry: DatabaseEntry, field: String, errors: PackedStringArray) -> void:
	if entry.get(field) == null:
		errors.append("%s.%s: required asset is missing." % [entry.id,field])

static func _meshes(entry: DatabaseEntry, errors: PackedStringArray) -> void:
	var variants: Array = entry.get("variants")
	if variants.is_empty() or variants.has(null):
		errors.append("%s.variants: at least one valid mesh is required." % entry.id)
