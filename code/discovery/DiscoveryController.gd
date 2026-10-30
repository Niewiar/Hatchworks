class_name DiscoveryController
extends Node

signal discovered(entry: DiscoveryDefinition)
signal seen(id: StringName)
signal combined(first: StringName, second: StringName, result: StringName, is_new: bool)

var _map: Node3D
var _known: Dictionary[StringName, bool] = {}
var _unread: Dictionary[StringName, bool] = {}
var _recipes: Dictionary[String, bool] = {}
var _scan_delay := -1.0
var _stocks: Dictionary[int, float] = {}

func initialize(map: Node3D) -> void:
	_map = map
	map.terrain_controller.height_changed.connect(_queue_scan)
	map.water_controller.water_level_changed.connect(_queue_scan)
	map.vegetation_controller.plant_sown.connect(_on_plant_sown)
	map.inventory.changed.connect(_on_resource_changed)
	map.inventory.gained.connect(_on_resource_gained)
	for data in map.inventory.definitions:
		_stocks[data.kind] = map.inventory.amount(data.kind)
	discover(&"soil")
	for flora: FloraSpecies in map.vegetation_controller.present_species():
		discover(flora.id)
	for child in map.rock_controller.get_children():
		if child is HarvestableDeposit:
			discover(&"rock")
	_queue_scan()

func knows(id: StringName) -> bool:
	return _known.has(id)

func known_entries() -> Array[DiscoveryDefinition]:
	var result: Array[DiscoveryDefinition] = []
	for id: StringName in _known:
		result.append(_map.database.discovery(id))
	return result

func is_unread(id: StringName) -> bool:
	return _unread.has(id)

func mark_seen(id: StringName) -> void:
	if _unread.erase(id):
		seen.emit(id)

func discover(id: StringName, origin: Variant = null) -> bool:
	var entry: DiscoveryDefinition = _map.database.discovery(id)
	if entry == null or knows(id):
		return false
	_known[id] = true
	_unread[id] = true
	if entry.reward_count > 0:
		_map.items.add(entry.reward_item,entry.reward_count,origin)
	discovered.emit(entry)
	return true

func combine(first: StringName, second: StringName, origin: Variant = null) -> StringName:
	if not knows(first) or not knows(second):
		return &""
	mark_seen(first)
	mark_seen(second)
	for recipe: DiscoveryRecipe in _map.database.recipes:
		if recipe.matches(first,second):
			var is_new := discover(recipe.result,origin)
			_recipes[str(recipe.id)] = true
			_map.science.record_recipe(recipe,origin)
			combined.emit(first,second,recipe.result,is_new)
			return recipe.result
	combined.emit(first,second,&"",false)
	return &""

func recipe_known(id: StringName) -> bool:
	return _recipes.has(str(id))

func _queue_scan() -> void:
	_scan_delay = 0.2
	set_process(true)

func _process(delta: float) -> void:
	_scan_delay -= delta
	if _scan_delay > 0.0:
		return
	if _map.terrain_controller.has_submerged_ground(_map.water_controller.global_position.y):
		discover(&"water")
	set_process(false)

func _on_plant_sown(species: FloraSpecies, world_position: Vector3) -> void:
	discover(species.id,world_position)

func _on_resource_changed(kind: int, quantity: float) -> void:
	_stocks[kind] = quantity

func _on_resource_gained(kind: int, _quantity: float, origin: Variant) -> void:
	var definition: ResourceDefinition = _map.inventory.definition(kind)
	if definition != null:
		discover(definition.id,origin)
