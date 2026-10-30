@tool
extends RefCounted

const CATEGORIES := ["Discoveries","Recipes","Creatures","Creature Research","Eggs","Flora","Resources","Deposits","Construction","Buildings","Glossary","World Balance"]
const SCRIPTS := {
	"Creature Research": preload("res://code/database/CreatureResearch.gd"),
	"Discoveries": preload("res://code/database/DiscoveryDefinition.gd"),
	"Recipes": preload("res://code/database/DiscoveryRecipe.gd"),
	"Buildings": preload("res://code/database/BuildingDefinition.gd"),
	"Eggs": preload("res://code/database/EggDefinition.gd"),
	"Glossary": preload("res://code/database/GlossaryEntry.gd"),
	"Creatures": preload("res://code/database/CreatureSpecies.gd"),
	"Flora": preload("res://code/environment/FloraSpecies.gd"),
	"Resources": preload("res://code/database/ResourceDefinition.gd"),
	"Deposits": preload("res://code/database/DepositDefinition.gd"),
	"Construction": preload("res://code/contructions/fances/FenceData.gd")
}
const FOLDERS := {"Creature Research":"research","Discoveries":"discoveries","Recipes":"recipes","Buildings":"buildings","Eggs":"eggs","Glossary":"glossary","Creatures":"creatures","Flora":"flora","Resources":"resources","Deposits":"deposits","Construction":"construction"}
const COLUMNS := {
	"Creature Research":["display_name","creature_id","action_id","science_reward"],
	"Discoveries":["display_name","category","reward_item","reward_count"],
	"Recipes":["display_name","first","second","result","science_reward"],
	"Buildings":["display_name","wood_cost","stone_cost","fiber_cost"],
	"Eggs":["display_name","incubation_seconds","crafting_seconds","science_cost"],
	"Glossary":["display_name","id"],
	"Creatures":["display_name","hold_height","follow_speed","rotation_speed","maximum_tilt"],
	"Flora":["display_name","density","growth_rate","harvest_amount"],
	"Resources":["display_name","kind","starting_amount"],
	"Deposits":["display_name","density","hits_required","harvest_amount"],
	"Construction":["display_name","material_per_meter","material_per_post","max_health"],
	"World Balance":["display_name","water_level","starting_height_variation","sculpt_speed","gather_interval"]
}

static func field(key: String, label: String, type: String = "text", low: float = 0.0, high: float = 10000.0, step: float = 0.01, choices: Array = []) -> Dictionary:
	return {"key":key,"label":label,"type":type,"min":low,"max":high,"step":step,"choices":choices}

static func fields(category: String) -> Array:
	var result := [field("id","Stable ID"),field("display_name","Name"),field("description","Description","multiline")]
	match category:
		"Discoveries":
			result.append_array([field("category","Category","enum",0,6,1,DiscoveryDefinition.CATEGORY_NAMES),field("icon","Icon","Texture2D"),field("reward_item","First discovery reward","item"),field("reward_count","First discovery quantity","number",0,100,1)])
		"Creature Research":
			result.append_array([field("creature_id","Creature species","creature"),field("action_id","Action ID · hatch, create_grass, plant_tree, create_stone, grow_herbs or breed"),field("science_reward","One-time science reward","number",0,1000,1)])
		"Recipes":
			result.append_array([field("science_reward","One-time science reward","number",0,1000,1),field("first","Ingredient A","discovery"),field("second","Ingredient B","discovery"),field("result","Result","discovery")])
		"Creatures":
			result.append_array([field("scene","Creature scene","PackedScene"),field("icon","Icon","Texture2D"),field("hold_height","Hold height (m)","number",0.5,4,0.1),field("follow_speed","Hold follow speed","number",0.1,50,0.1),field("rotation_speed","Rotation speed","number",0.1,50,0.1),field("maximum_tilt","Maximum tilt (rad)","number",0,0.8,0.01),field("walk_speed","Walking speed (m/s)","number",0.2,5,0.1),field("swim_speed","Swimming speed (m/s)","number",0.2,5,0.1),field("minimum_swim_depth","Bathing depth (m)","number",0.1,1,0.05),field("bathing_seconds","Bathing duration (s)","number",1,30,0.5),field("shaking_seconds","Shaking duration (s)","number",0.5,10,0.1),field("resting_seconds","Rest duration (s)","number",0.5,30,0.5),field("grass_per_cycle","Grass tufts per cycle","number",1,12,1),field("grass_radius","Grass patch radius (m)","number",0.4,3,0.1),field("food_resource","Food","resource"),field("food_per_feeding","Food per feeding","number",1,10,1),field("satiety_seconds","Full satiety duration (s)","number",30,3600,1),field("feeding_threshold","Seek food below (%)","number",1,90,1),field("satiety_per_meal","Satiety restored per meal (%)","number",1,100,1),field("feeding_seconds","Eating duration (s)","number",0.5,10,0.1),field("breeding_seconds","Breeding duration (s)","number",1,120,1),field("breeding_cooldown","Breeding recovery (s)","number",1,3600,1),field("breeding_min_satiety","Breeding minimum satiety (%)","number",1,100,1),field("breeding_satiety_cost","Breeding satiety cost (%)","number",0,100,1)])
			result.append_array([field("leisure_seconds_min","Shortest leisure (s)","number",1,120,0.5),field("leisure_seconds_max","Longest leisure (s)","number",1,120,0.5),field("leisure_cycles_min","Fewest cycles before leisure","number",1,10,1),field("leisure_cycles_max","Most cycles before leisure","number",1,10,1),field("happiness_response_seconds","Contentment response (s)","number",1,300,1),field("preferred_area","Preferred dry area (m²)","number",1,100,0.5),field("company_radius","Companion radius (m)","number",1,30,0.5),field("breeding_call_seconds","Mate call duration (s)","number",0.5,30,0.5)])
			result.append_array([field("noise_sensitivity","Noise sensitivity","number",0,1,0.05),field("crowding_sensitivity","Crowding sensitivity","number",0,1,0.05),field("species_aversions","Species aversions · species_id = weight 0..1","aversions")])
			result.append_array([field("requires_water","Requires water access","boolean"),field("habitat_ground","Breeding ground (-1 any)","number",-1,4,1),field("production","Production behaviour","enum",0,3,1,["Tuftling","Gardener","Quarry","Herbalist"]),field("production_seconds","Work duration (s)","number",1,30,0.1),field("impact_time","Work impact time (s)","number",0.1,30,0.1),field("production_radius","Work search radius (m)","number",1,15,0.5),field("production_limit","Nearby output limit","number",1,40,1),field("impact_radius","Rock impact radius (m)","number",0.4,3,0.1),field("impact_strength","Rock ripple height (m)","number",0.01,0.3,0.01),field("aggression_threshold","Quarry anger below contentment (%)","number",0,100,1),field("impact_damage","Quarry structure damage","number",1,100,1),field("aggression_cooldown","Quarry anger recovery (s)","number",1,60,1)])
		"Flora":
			result.append_array([field("icon","Icon","Texture2D"),field("sapling_item","Sapling item ID"),field("kind","Plant type","enum",0,4,1,["Tree","Shrub","Fern","Reeds","Grass"]),field("variants","Mesh variants · one path per line","meshes"),field("density","Candidates per m²","number",0,2,0.001),field("spacing","Spacing (m)","number",0.1,20,0.05),field("minimum_scale","Minimum scale","number",0.1,4,0.05),field("maximum_scale","Maximum scale","number",0.1,4,0.05),field("growth_rate","Growth per second","number",0,5,0.001),field("maximum_slope","Maximum slope (rise / run)","number",0,4,0.01),field("water_depth_range","Water depth range (m)","vector",-100,20,0.005),field("canopy_radius","Canopy radius (m)","number",0,10,0.05),field("trunk_radius","Trunk radius (m)","number",0.01,2,0.01),field("trunk_height","Trunk height (m)","number",0.1,10,0.1),field("harvest_resource","Harvest resource","resource"),field("harvest_amount","Harvest amount","number",1,10000,1),field("hits_required","Tree hits required","number",1,100,1),field("ground_material","Ground material ID (-1 any)","number",-1,4,1)])
		"Eggs":
			result.append_array([field("creature_id","Creature species","creature"),field("model","Breakable egg scene","PackedScene"),field("incubation_seconds","Incubation (s)","number",1,3600,1),field("crafting_seconds","Workshop crafting time (s)","number",1,3600,1),field("science_cost","Science cost per egg","number",1,1000,1),field("fiber_cost","Plant Fiber cost per egg","number",0,10000,1),field("wood_cost","Wood cost per egg","number",0,10000,1),field("stone_cost","Stone cost per egg","number",0,10000,1)])
		"Glossary":
			result.append_array([field("keywords","Keywords · one per line","words"),field("icon","Icon","Texture2D")])
		"Resources":
			result.append_array([field("kind","Numeric ID","number",0,100000,1),field("icon","Icon","Texture2D"),field("starting_amount","Starting amount","number",0,1000000,0.1)])
		"Deposits":
			result.append_array([field("variants","Mesh variants · one path per line","meshes"),field("material","Material","Material"),field("density","Deposits per m²","number",0,0.1,0.001),field("spacing","Spacing (m)","number",0.1,8,0.1),field("minimum_scale","Minimum scale","number",0.1,4,0.05),field("maximum_scale","Maximum scale","number",0.1,4,0.05),field("harvest_resource","Harvest resource","resource"),field("hits_required","Hits required","number",1,100,1),field("harvest_amount","Base harvest amount","number",1,10000,1)])
		"Construction":
			result.append_array([field("ui_icon","Icon","Texture2D"),field("required_discovery","Required discovery","discovery"),field("max_span_length","Maximum span (terrain px)","number",24,160,1),field("height","Height (terrain px)","number",16,100,1),field("post_width","Post width (terrain px)","number",6,32,1),field("thickness","Thickness (terrain px)","number",3,24,1),field("body_color","Body color","color"),field("highlight_color","Highlight color","color"),field("outline_color","Outline color","color"),field("max_health","Span health","number",1,100000,1),field("post_max_health","Post health","number",1,100000,1),field("post_priority","Junction post priority","number",0,100,1),field("construction_resource","Construction resource","resource"),field("material_per_meter","Material per meter","number",0,1000,0.1),field("material_per_post","Material per post","number",0,1000,1)])
		"Buildings":
			result.append_array([field("scene","Building scene","PackedScene"),field("icon","Icon","Texture2D"),field("wood_cost","Wood cost","number",0,10000,1),field("stone_cost","Stone cost","number",0,10000,1),field("fiber_cost","Plant Fiber cost","number",0,10000,1),field("footprint_radius","Footprint radius (m)","number",0.25,8,0.05),field("maximum_height_difference","Maximum ground height difference (m)","number",0,1,0.01),field("required_discovery","Required discovery","discovery"),field("storage_capacity","Food storage capacity (feeder)","number",1,1000,1),field("max_health","Durability","number",1,1000,1)])
		"World Balance":
			result.append_array([field("generate_nature_on_start","Generate natural terrain and resources at start","boolean"),field("water_level","Water level (m)","number",-4,6,0.05),field("starting_height_variation","Starting height variation (m)","number",0,4,0.1),field("terrain_wavelength","Terrain wavelength (m)","number",8,64,1),field("spawn_clearing_radius","Spawn clearing radius (m)","number",0,8,0.25),field("sculpt_speed","Sculpt speed (m/s)","number",0.1,4,0.1),field("maximum_sculpt_slope","Maximum sculpt slope (deg)","number",10,60,1),field("gather_interval","Gather interval (s)","number",0.05,1,0.01),field("starting_pond_radius","Starting pond radius (m)","number",0,5,0.1),field("starting_pond_offset","Starting pond offset","vector",-20,20,0.5)])
	return result

static func label_for(category: String, key: String) -> String:
	for data in fields(category):
		if data.key == key:
			return data.label
	return key.capitalize()

static func fingerprint(entry: Resource) -> String:
	var values: Array = []
	for property in entry.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE:
			values.append([property.name,entry.get(property.name)])
	return var_to_str(values)

static func validate(database: GameDatabase) -> PackedStringArray:
	var errors := PackedStringArray()
	var kinds: Dictionary = {}
	for data in database.resources:
		if data == null:
			continue
		if data.kind < 0 or data.kind in ResourceInventory.RESERVED_KINDS or kinds.has(data.kind):
			errors.append("Resources: numeric ID must be unique, nonnegative and outside reserved IDs 0, 1, 2, 3, 4, 7 and 8 (%s)." % data.id)
		kinds[data.kind] = data
	for category in CATEGORIES:
		var ids: Dictionary = {}
		for entry: Resource in database.entries(category):
			if entry == null:
				errors.append(category+": missing entry.")
				continue
			var title := "%s / %s" % [category,entry.display_name]
			var id := String(entry.id)
			if id.is_empty() or not id.is_valid_identifier() or id != id.to_lower() or ids.has(id):
				errors.append(title+": stable ID must be unique lowercase letters, digits and underscores.")
			ids[id] = true
			if entry.display_name.strip_edges().is_empty():
				errors.append(title+": name is empty.")
			for data in fields(category):
				var value: Variant = entry.get(data.key)
				if data.type == "number" and (not is_finite(float(value)) or float(value) < data.min or float(value) > data.max):
					errors.append(title+": "+data.label+" is outside its allowed range.")
				if data.type == "vector" and (not value.is_finite() or (data.key != "starting_pond_offset" and value.x >= value.y)):
					errors.append(title+": "+data.label+" requires minimum < maximum.")
				if data.type == "resource" and not kinds.has(value):
					errors.append(title+": unknown "+data.label.to_lower()+".")
			if entry is FloraSpecies or entry is DepositDefinition:
				if entry.variants.is_empty() or entry.variants.has(null):
					errors.append(title+": at least one valid mesh is required.")
				if entry.minimum_scale > entry.maximum_scale:
					errors.append(title+": minimum scale exceeds maximum scale.")
			if entry is BuildingDefinition and entry.scene == null:
				errors.append(title+": building scene is required.")
			if entry is CreatureSpecies:
				if entry.scene == null:
					errors.append(title+": creature scene is required.")
				else:
					var root_type: StringName = entry.scene.get_state().get_node_type(0)
					if not root_type.is_empty() and not ClassDB.is_parent_class(root_type,&"Node3D"):
						errors.append(title+": creature scene must have a 3D root.")
			if entry is EggDefinition:
				if database.creature(entry.creature_id) == null:
					errors.append(title+": unknown creature species.")
				if entry.model == null:
					errors.append(title+": breakable egg scene is required.")
				else:
					var state: SceneState = entry.model.get_state()
					var controller: Script
					var fragments := 0
					for index in state.get_node_property_count(0):
						if state.get_node_property_name(0,index) == &"script":
							controller = state.get_node_property_value(0,index) as Script
					for index in state.get_node_count():
						if state.get_node_type(index) == &"RigidBody3D":
							fragments += 1
					var valid_controller := false
					while controller != null:
						if controller.get_global_name() == &"EggShell":
							valid_controller = true
							break
						controller = controller.get_base_script()
					if not valid_controller or fragments < 3:
						errors.append(title+": egg scene requires an EggShell controller and at least three rigid shell fragments.")
			if entry is FloraSpecies and entry.ground_material not in [-1,0,1,3,4]:
				errors.append(title+": unsupported ground material.")
	var research_keys := {}
	for entry: CreatureResearch in database.research:
		var key := "%s:%s" % [entry.creature_id,entry.action_id]
		if database.creature(entry.creature_id) == null:
			errors.append("Creature Research / %s: unknown creature species." % entry.display_name)
		if entry.action_id not in [&"hatch",&"create_grass",&"breed",&"plant_tree",&"create_stone",&"grow_herbs"] or research_keys.has(key):
			errors.append("Creature Research / %s: action must be supported and unique per species." % entry.display_name)
		research_keys[key] = true
	for species: CreatureSpecies in database.creatures:
		for id: StringName in species.species_aversions:
			var weight: float = species.species_aversions[id]
			if id == species.id or database.creature(id) == null or not is_finite(weight) or weight < 0.0 or weight > 1.0:
				errors.append("Creatures / %s: species aversions require another valid species and a weight from 0 to 1." % species.display_name)
		if species.habitat_ground not in [-1,0,1,3,4]:
			errors.append("Creatures / %s: unsupported habitat ground." % species.display_name)
		if species.impact_time > species.production_seconds:
			errors.append("Creatures / %s: impact must happen before work ends." % species.display_name)
		if species.breeding_satiety_cost >= 100.0:
			errors.append("Creatures / %s: breeding satiety cost must be below 100%%." % species.display_name)
		if species.leisure_seconds_max < species.leisure_seconds_min or species.leisure_cycles_max < species.leisure_cycles_min:
			errors.append("Creatures / %s: leisure maximums must be at least their minimums." % species.display_name)

	var pairs := {}
	for recipe: DiscoveryRecipe in database.recipes:
		for id in [recipe.first,recipe.second,recipe.result]:
			if database.discovery(id) == null:
				errors.append("Recipes / %s: unknown discovery %s." % [recipe.display_name,id])
		var parts := [str(recipe.first),str(recipe.second)]
		parts.sort()
		var pair := "|".join(parts)
		if pairs.has(pair):
			errors.append("Recipes: duplicate ingredient pair "+pair)
		pairs[pair] = true
	for entry: DiscoveryDefinition in database.discoveries:
		if entry.category < 0 or entry.category >= DiscoveryDefinition.CATEGORY_NAMES.size():
			errors.append("Discoveries / %s: unknown category." % entry.display_name)
		if entry.reward_count > 0:
			var valid_item := database.egg(entry.reward_item) != null or database.sapling(entry.reward_item) != null
			if not valid_item:
				errors.append("Discoveries / %s: unknown reward item." % entry.display_name)
	var sapling_ids := {}
	for flora: FloraSpecies in database.flora:
		if sapling_ids.has(flora.sapling_item) or not str(flora.sapling_item).is_valid_identifier():
			errors.append("Flora / %s: sapling item ID must be unique and valid." % flora.display_name)
		sapling_ids[flora.sapling_item] = true
		if flora.sapling_item.is_empty() or flora.icon == null or database.discovery(flora.id) == null:
			errors.append("Flora / %s: discovery, icon and sapling item ID are required." % flora.display_name)
	for fence: FanceData in database.construction.fances:
		if not fence.required_discovery.is_empty() and database.discovery(fence.required_discovery) == null:
			errors.append("Construction / %s: unknown required discovery." % fence.display_name)
	for building: BuildingDefinition in database.buildings:
		if not building.required_discovery.is_empty() and database.discovery(building.required_discovery) == null:
			errors.append("Buildings / %s: unknown required discovery." % building.display_name)
	if database.buildings.is_empty():
		errors.append("Buildings: at least one building is required.")
	if database.eggs.is_empty():
		errors.append("Eggs: at least one egg is required.")
	for term in ["soil","water","grass","fiber"]:
		if database.term(term) == null:
			errors.append("Glossary: missing built-in term "+term+".")
	for kind in ResourceInventory.KIND.values():
		if not kinds.has(kind):
			errors.append("Resources: missing built-in numeric ID %d." % kind)
	if database.construction == null or database.construction.fances.is_empty():
		errors.append("Construction: at least one fence definition is required.")
	if database.world == null:
		errors.append("World Balance: missing world settings.")
	if database.creature(&"tuftling") == null:
		errors.append("Creatures: the existing Tuftling requires stable ID tuftling.")
	return errors

static func summary(entry: Resource) -> String:
	if (entry is FloraSpecies or entry is DepositDefinition) and entry.hits_required <= 0:
		return "Hits required must be greater than zero."
	if entry is FloraSpecies:
		if entry.kind == FloraSpecies.KIND.TREE:
			return "%.2f base resources / hit
Trees are removed permanently after harvesting." % (float(entry.harvest_amount)/entry.hits_required)
		return "Harvest: %d resources\nPlants do not regrow after gathering. Creatures sow new patches.\nGrowth rate applies only to newly sown plants." % entry.harvest_amount
	if entry is DepositDefinition:
		return "%.2f base resources / hit
Yield scales with deposit size. Depleted deposits are removed." % (float(entry.harvest_amount)/entry.hits_required)
	if entry is FanceData:
		var posts := ceili(10.0/(maxf(entry.max_span_length,0.01)/32.0))+1
		return "10 m fence: %d material + %d posts × %d
Estimated total: %d resources
Assumes 32 terrain pixels / meter and no reused posts." % [ceili(10.0*entry.material_per_meter),posts,entry.material_per_post,ceili(10.0*entry.material_per_meter)+posts*entry.material_per_post]
	if entry is ResourceDefinition:
		return "Unit: %s
Starting stock: %.1f
Built-in numeric IDs keep their gameplay roles." % ["items",entry.starting_amount]

	if entry is CreatureSpecies:
		return "Food per meal: %d\nFull satiety lasts %.0f s. At 0%%, only seeking food remains active.\nGrass tufts per cycle: %d" % [entry.food_per_feeding,entry.satiety_seconds,entry.grass_per_cycle]
	if entry is BuildingDefinition:
		return "Build cost: %d Wood, %d Stone, %d Plant Fiber\nPlace on dry, level ground." % [entry.wood_cost,entry.stone_cost,entry.fiber_cost]
	if entry is CreatureResearch:
		return "Awarded once per species and action, across all individuals. No repeat rewards."
	if entry is EggDefinition:
		return "Incubation: %.0f s\nConsumes one owned egg when started.\nCreature species: %s\nWorkshop: %.0f s, %d science, %d fiber, %d wood, %d stone per egg." % [entry.incubation_seconds,entry.creature_id,entry.crafting_seconds,entry.science_cost,entry.fiber_cost,entry.wood_cost,entry.stone_cost]
	if entry is DiscoveryDefinition:
		return "First discovery reward: %d item(s).\nRecipes for this discovery are listed below." % entry.reward_count if entry.reward_count > 0 else "A reusable concept. Recipes for this discovery are listed below."
	if entry is DiscoveryRecipe:
		return "Choose Ingredient A, Ingredient B and Result in the recipe editor. Science is awarded only on the first successful combination of this recipe."
	if entry is GlossaryEntry:
		return "Hover descriptions are shared by creature cards and inspection."
	return "Changes apply when starting a new game. No moisture simulation or spontaneous plant regrowth."

static func value_text(database: GameDatabase, entry: Resource, key: String) -> String:
	var value: Variant = entry.get(key)
	if entry is DiscoveryDefinition and key == "category":
		return DiscoveryDefinition.CATEGORY_NAMES[value] if value >= 0 and value < DiscoveryDefinition.CATEGORY_NAMES.size() else "Unknown"
	if (entry is DiscoveryRecipe and key in ["first","second","result"]) or (entry is BuildingDefinition and key == "required_discovery"):
		var discovery := database.discovery(StringName(value))
		return discovery.display_name if discovery != null else ("None" if str(value).is_empty() else str(value)+" (missing)")
	if entry is DiscoveryDefinition and key == "reward_item":
		if str(value).is_empty():
			return "None"
		var plant := database.sapling(StringName(value))
		if plant != null:
			return plant.display_name+" sapling"
		var egg := database.egg(StringName(value))
		if egg != null:
			return egg.display_name
	return str(value)

static func recipe_error(database: GameDatabase, first: StringName, second: StringName, result: StringName, except: DiscoveryRecipe = null) -> String:
	if first.is_empty() or second.is_empty() or result.is_empty():
		return "Choose both ingredients and a result."
	for id in [first,second,result]:
		if database.discovery(id) == null:
			return "Unknown discovery: "+str(id)
	for recipe: DiscoveryRecipe in database.recipes:
		if recipe != except and recipe.matches(first,second):
			return "This ingredient pair already belongs to: "+recipe.display_name
	return ""
