@tool
extends RefCounted

const CATEGORIES := ["Creatures","Flora","Resources","Deposits","Construction","World Balance"]
const SCRIPTS := {
	"Creatures": preload("res://code/database/CreatureSpecies.gd"),
	"Flora": preload("res://code/environment/FloraSpecies.gd"),
	"Resources": preload("res://code/database/ResourceDefinition.gd"),
	"Deposits": preload("res://code/database/DepositDefinition.gd"),
	"Construction": preload("res://code/contructions/fances/FenceData.gd")
}
const FOLDERS := {"Creatures":"creatures","Flora":"flora","Resources":"resources","Deposits":"deposits","Construction":"construction"}
const COLUMNS := {
	"Creatures":["display_name","hold_height","follow_speed","rotation_speed","maximum_tilt"],
	"Flora":["display_name","density","growth_rate","harvest_amount","regrowth_delay"],
	"Resources":["display_name","kind","starting_amount"],
	"Deposits":["display_name","density","hits_required","harvest_amount"],
	"Construction":["display_name","material_per_meter","material_per_post","max_health"],
	"World Balance":["display_name","water_level","wetting_speed","drying_speed","ground_change_speed"]
}

static func field(key: String, label: String, type: String = "text", low: float = 0.0, high: float = 10000.0, step: float = 0.01, choices: Array = []) -> Dictionary:
	return {"key":key,"label":label,"type":type,"min":low,"max":high,"step":step,"choices":choices}

static func fields(category: String) -> Array:
	var result := [field("id","Stable ID"),field("display_name","Name"),field("description","Description","multiline")]
	match category:
		"Creatures":
			result.append_array([field("scene","Creature scene","PackedScene"),field("icon","Icon","Texture2D"),field("hold_height","Hold height (m)","number",0.5,4,0.1),field("follow_speed","Hold follow speed","number",0.1,50,0.1),field("rotation_speed","Rotation speed","number",0.1,50,0.1),field("maximum_tilt","Maximum tilt (rad)","number",0,0.8,0.01)])
		"Flora":
			result.append_array([field("kind","Plant type","enum",0,4,1,["Tree","Shrub","Fern","Reeds","Grass"]),field("variants","Mesh variants · one path per line","meshes"),field("density","Candidates per m²","number",0,2,0.001),field("spacing","Spacing (m)","number",0.1,20,0.05),field("minimum_scale","Minimum scale","number",0.1,4,0.05),field("maximum_scale","Maximum scale","number",0.1,4,0.05),field("growth_rate","Growth per second","number",0,5,0.001),field("decay_rate","Decay per second","number",0,5,0.001),field("moisture_range","Moisture range (0–1)","vector",-0.01,1.01,0.01),field("shade_range","Shade range (0–1)","vector",-0.01,1.01,0.01),field("maximum_slope","Maximum slope (rise / run)","number",0,4,0.01),field("water_depth_range","Water depth range (m)","vector",-100,20,0.005),field("canopy_radius","Canopy radius (m)","number",0,10,0.05),field("trunk_radius","Trunk radius (m)","number",0.01,2,0.01),field("trunk_height","Trunk height (m)","number",0.1,10,0.1),field("harvest_resource","Harvest resource","resource"),field("harvest_amount","Harvest amount","number",1,10000,1),field("hits_required","Tree hits required","number",1,100,1),field("regrowth_delay","Regrowth delay (s)","number",0,10000,1)])
		"Resources":
			result.append_array([field("kind","Numeric ID","number",0,100000,1),field("icon","Icon","Texture2D"),field("starting_amount","Starting amount","number",0,1000000,0.1)])
		"Deposits":
			result.append_array([field("variants","Mesh variants · one path per line","meshes"),field("material","Material","Material"),field("density","Deposits per m²","number",0,0.1,0.001),field("spacing","Spacing (m)","number",0.1,8,0.1),field("minimum_scale","Minimum scale","number",0.1,4,0.05),field("maximum_scale","Maximum scale","number",0.1,4,0.05),field("harvest_resource","Harvest resource","resource"),field("hits_required","Hits required","number",1,100,1),field("harvest_amount","Base harvest amount","number",1,10000,1)])
		"Construction":
			result.append_array([field("material_kind","Geometry","enum",0,1,1,["Wood","Stone"]),field("ui_icon","Icon","Texture2D"),field("max_span_length","Maximum span (terrain px)","number",24,160,1),field("height","Height (terrain px)","number",16,100,1),field("post_width","Post width (terrain px)","number",6,32,1),field("thickness","Thickness (terrain px)","number",3,24,1),field("body_color","Body color","color"),field("highlight_color","Highlight color","color"),field("outline_color","Outline color","color"),field("max_health","Span health","number",1,100000,1),field("post_max_health","Post health","number",1,100000,1),field("post_priority","Junction post priority","number",0,100,1),field("construction_resource","Construction resource","resource"),field("material_per_meter","Material per meter","number",0,1000,0.1),field("material_per_post","Material per post","number",0,1000,1)])
		"World Balance":
			result.append_array([field("water_level","Water level (m)","number",-4,6,0.05),field("starting_height_variation","Starting height variation (m)","number",0,4,0.1),field("terrain_wavelength","Terrain wavelength (m)","number",8,64,1),field("spawn_clearing_radius","Spawn clearing radius (m)","number",0,8,0.25),field("sculpt_speed","Sculpt speed (m/s)","number",0.1,4,0.1),field("maximum_sculpt_slope","Maximum sculpt slope (deg)","number",10,60,1),field("wetting_speed","Wetting per second","number",0.05,2,0.05),field("drying_speed","Drying per second","number",0.01,0.5,0.01),field("ground_change_speed","Ground change speed","number",0.05,1,0.05),field("gather_interval","Gather interval (s)","number",0.05,1,0.01)])
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
			errors.append("Resources: numeric ID must be unique, nonnegative and outside reserved IDs 1, 7 and 8 (%s)." % data.id)
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
				if data.type == "vector" and (not value.is_finite() or value.x >= value.y):
					errors.append(title+": "+data.label+" requires minimum < maximum.")
				if data.type == "resource" and not kinds.has(value):
					errors.append(title+": unknown "+data.label.to_lower()+".")
			if entry is FloraSpecies or entry is DepositDefinition:
				if entry.variants.is_empty() or entry.variants.has(null):
					errors.append(title+": at least one valid mesh is required.")
				if entry.minimum_scale > entry.maximum_scale:
					errors.append(title+": minimum scale exceeds maximum scale.")
			if entry is CreatureSpecies:
				if entry.scene == null:
					errors.append(title+": creature scene is required.")
				else:
					var root_type: StringName = entry.scene.get_state().get_node_type(0)
					if not root_type.is_empty() and not ClassDB.is_parent_class(root_type,&"Node3D"):
						errors.append(title+": creature scene must have a 3D root.")
	for kind in ResourceInventory.KIND.values():
		if not kinds.has(kind):
			errors.append("Resources: missing built-in numeric ID %d." % kind)
	if database.construction == null or database.construction.fances.is_empty():
		errors.append("Construction: at least one fence definition is required.")
	if database.world == null:
		errors.append("World Balance: missing world settings.")
	if database.creature(&"mossling") == null:
		errors.append("Creatures: the existing Mossling requires stable ID mossling.")
	return errors

static func summary(entry: Resource) -> String:
	if (entry is FloraSpecies or entry is DepositDefinition) and entry.hits_required <= 0:
		return "Hits required must be greater than zero."
	if entry is FloraSpecies:
		if entry.kind == FloraSpecies.KIND.TREE:
			return "%.2f base resources / hit
Trees are removed permanently after harvesting." % (float(entry.harvest_amount)/entry.hits_required)
		var cycle: float = entry.regrowth_delay+0.6/maxf(entry.growth_rate,0.000001)
		return "%.1f s until harvestable again
≈ %.2f resources / minute per plant
Assumes suitable habitat; gathering starts at 60%% growth." % [cycle,60.0*entry.harvest_amount/cycle] if entry.growth_rate > 0 else "Growth is disabled. Harvested plants will not regrow."
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
Built-in numeric IDs keep their gameplay roles." % ["m²" if entry.kind in ResourceInventory.GROUND_TYPES else "items",entry.starting_amount]
	if entry is CreatureSpecies:
		return "Hold height: %.1f m
Scene instances select this definition through Species ID.
Needs and production can be added when those systems exist." % entry.hold_height
	return "Changes apply when starting a new game.
Initial terrain generation and environment simulation use these values."
