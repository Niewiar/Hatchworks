class_name FeederController
extends MeshInstance3D

signal changed

var stock := 0
var capacity := 20
var food_resource := ResourceInventory.KIND.FIBER
var _map: Node3D

func initialize(map: Node3D, definition: BuildingDefinition) -> void:
	_map = map
	capacity = definition.storage_capacity
	_refresh()

func fill() -> int:
	if _map == null:
		return 0
	var count := mini(capacity-stock,floori(_map.inventory.amount(food_resource)))
	if count <= 0 or not _map.inventory.spend(food_resource,count):
		return 0
	stock += count
	_refresh()
	changed.emit()
	return count

func can_feed(species: CreatureSpecies) -> bool:
	return species.food_resource == food_resource and stock >= species.food_per_feeding and global_position.y > _map.water_controller.global_position.y+0.04

func eat(species: CreatureSpecies) -> bool:
	if not can_feed(species):
		return false
	stock -= species.food_per_feeding
	_refresh()
	changed.emit()
	return true

func feeding_positions() -> PackedVector3Array:
	var result := PackedVector3Array()
	for child in $FeedingSpots.get_children():
		result.append(child.global_position)
	return result

func _refresh() -> void:
	$Food.visible = stock > 0
	$Food.scale.y = 0.25+0.75*float(stock)/capacity
	$Timer.text = "Feeder · %d / %d" % [stock,capacity]

func inspection_bounds() -> AABB:
	return AABB(Vector3(-1.35,0,-0.6),Vector3(2.9,1.2,1.2))
