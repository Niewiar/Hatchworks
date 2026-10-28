@tool
class_name GameDatabase
extends Resource

const DEFAULT_PATH := "res://resources/database/game_database.tres"

@export var creatures: Array[CreatureSpecies] = []
@export var flora: Array[FloraSpecies] = []
@export var resources: Array[ResourceDefinition] = []
@export var deposits: Array[DepositDefinition] = []
@export var construction: FancesDatabase
@export var world: WorldBalance

func entries(category: String) -> Array:
	match category:
		"Creatures": return creatures
		"Flora": return flora
		"Resources": return resources
		"Deposits": return deposits
		"Construction": return construction.fances if construction != null else []
		"World Balance": return [world] if world != null else []
	return []

func replace_entries(category: String, values: Array) -> void:
	match category:
		"Creatures": creatures.assign(values)
		"Flora": flora.assign(values)
		"Resources": resources.assign(values)
		"Deposits": deposits.assign(values)
		"Construction": construction.fances.assign(values)
	emit_changed()

func creature(species_id: StringName) -> CreatureSpecies:
	for entry in creatures:
		if entry.id == species_id:
			return entry
	return null
