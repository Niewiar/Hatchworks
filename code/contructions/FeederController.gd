class_name FeederController
extends Node3D

signal changed

var stock := 0
var capacity := 20
var food_resource := ResourceInventory.KIND.FIBER
var _map: Node3D
var _food: Node3D
var _player: AnimationPlayer

func _ready() -> void:
	BuildingAppearance.configure(self)
	_food = find_child("Food", true, false) as Node3D
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player != null:
		_player.animation_finished.connect(_on_animation_finished)
	_refresh()

func initialize(map: Node3D, definition: BuildingDefinition) -> void:
	_map = map
	capacity = definition.storage_capacity
	_refresh()

func fill() -> int:
	if _map == null or _map.building_controller.relocating_building() == self:
		return 0
	var count := mini(capacity-stock,floori(_map.inventory.amount(food_resource)))
	if count <= 0 or not _map.inventory.spend(food_resource,count):
		return 0
	stock += count
	_refresh()
	_play(&"Fill")
	changed.emit()
	return count

func can_feed(species: CreatureSpecies) -> bool:
	return _map != null and _map.building_controller.relocating_building() != self and species.food_resource == food_resource and stock >= species.food_per_feeding and global_position.y > _map.water_controller.global_position.y+0.04

func eat(species: CreatureSpecies) -> bool:
	if not can_feed(species):
		return false
	stock -= species.food_per_feeding
	_refresh()
	_play(&"Eat")
	changed.emit()
	return true

func feeding_positions() -> PackedVector3Array:
	var result := PackedVector3Array()
	for child in $FeedingSpots.get_children():
		result.append(child.global_position)
	return result

func _refresh() -> void:
	if _food == null:
		return
	_food.visible = stock > 0
	_food.position.y = -0.01835*(1.0-float(stock)/maxi(capacity,1))

func inspection_bounds() -> AABB:
	return AABB(Vector3(-0.6981,0,-0.2743),Vector3(1.395,0.17915,0.54845))

func _play(clip: StringName) -> void:
	if _player != null and _player.has_animation(clip):
		_player.play(clip)

func _on_animation_finished(_clip: StringName) -> void:
	_play(&"Idle")
