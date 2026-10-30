class_name ScienceController
extends Node

signal changed(amount: int)
signal earned(title: String, points: int)
signal gained(points: int, origin: Variant)

var amount := 0
var _database: GameDatabase
var _completed: Dictionary[String, bool] = {}

func initialize(database: GameDatabase) -> void:
	_database = database

func record_recipe(recipe: DiscoveryRecipe, origin: Variant = null) -> void:
	_award("recipe:"+str(recipe.id),recipe.display_name,recipe.science_reward,origin)

func observe(species_id: StringName, action_id: StringName, origin: Variant = null) -> void:
	for entry: CreatureResearch in _database.research:
		if entry.creature_id == species_id and entry.action_id == action_id:
			_award("action:%s:%s" % [species_id,action_id],entry.display_name,entry.science_reward,origin)
			return

func can_afford(points: int) -> bool:
	return points >= 0 and amount >= points

func spend(points: int) -> bool:
	if not can_afford(points):
		return false
	if points > 0:
		amount -= points
		changed.emit(amount)
	return true

func _award(key: String, title: String, points: int, origin: Variant) -> void:
	if _completed.has(key):
		return
	_completed[key] = true
	if points <= 0:
		return
	amount += points
	gained.emit(points,origin)
	changed.emit(amount)
	earned.emit(title,points)
