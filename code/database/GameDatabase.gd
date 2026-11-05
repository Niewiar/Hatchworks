@tool
class_name GameDatabase
extends Resource

const DEFAULT_PATH := "res://resources/database/game_database.tres"

@export var discoveries: Array[DiscoveryDefinition] = []
@export var recipes: Array[DiscoveryRecipe] = []
@export var buildings: Array[BuildingDefinition] = []
@export var eggs: Array[EggDefinition] = []
@export var glossary: Array[GlossaryEntry] = []
@export var creatures: Array[CreatureSpecies] = []
@export var research: Array[CreatureResearch] = []
@export var science_projects: Array[ScienceProjectDefinition] = []
@export var flora: Array[FloraSpecies] = []
@export var resources: Array[ResourceDefinition] = []
@export var deposits: Array[DepositDefinition] = []
@export var construction: FancesDatabase
@export var world: WorldBalance

func validation_errors() -> PackedStringArray:
	return GameDatabaseValidator.validate(self)

func creature(species_id: StringName) -> CreatureSpecies:
	for entry in creatures:
		if entry.id == species_id:
			return entry
	return null

func term(term_id: String) -> GlossaryEntry:
	for entry in glossary:
		if String(entry.id) == term_id:
			return entry
	return null

func rich_description(text: String) -> String:
	for entry in glossary:
		for word in entry.keywords:
			var expression := RegEx.new()
			var pattern := tr("keyword:"+word)
			if pattern.begins_with("keyword:"):
				pattern = word
			expression.compile("(?i)(?<![\\p{L}\\p{N}_])(?:"+pattern+")(?![\\p{L}\\p{N}_])")
			text = expression.sub(text,"[url="+str(entry.id)+"]$0[/url]",true)
	return text

func discovery(id: StringName) -> DiscoveryDefinition:
	for entry in discoveries:
		if entry.id == id:
			return entry
	return null

func egg(id: StringName) -> EggDefinition:
	for entry in eggs:
		if entry.id == id:
			return entry
	return null

func plant(id: StringName) -> FloraSpecies:
	for entry: FloraSpecies in flora:
		if entry.id == id:
			return entry
	return null

func sapling(id: StringName) -> FloraSpecies:
	for entry: FloraSpecies in flora:
		if not entry.sapling_item.is_empty() and entry.sapling_item == id:
			return entry
	return null

func item_info(id: StringName) -> Dictionary:
	var plant_data := sapling(id)
	if plant_data != null:
		return {"name":tr("%s sapling") % plant_data.display_name,"description":tr("A young plant, ready to put down roots."),"icon":plant_data.icon}
	var egg_data := egg(id)
	if egg_data != null:
		var concept := discovery(id)
		return {"name":egg_data.display_name,"description":egg_data.description,"icon":concept.icon if concept != null else load("res://assets/ui/illustrated/egg.svg")}
	return {"name":str(id).capitalize(),"description":tr("Stored item."),"icon":load("res://assets/ui/illustrated/inventory.svg")}
