@tool
class_name EggDefinition
extends DatabaseEntry

@export var creature_id: StringName = &"tuftling"
@export var model: PackedScene
@export_range(1.0, 3600.0, 1.0) var incubation_seconds := 30.0

@export_group("Workshop")
@export_range(1.0, 3600.0, 1.0) var crafting_seconds := 12.0
@export_range(1, 1000, 1) var science_cost := 3
@export_range(0, 10000, 1) var fiber_cost := 5
@export_range(0, 10000, 1) var wood_cost := 0
@export_range(0, 10000, 1) var stone_cost := 0

func costs() -> Dictionary[int, int]:
	return {ResourceInventory.KIND.FIBER:fiber_cost,ResourceInventory.KIND.WOOD:wood_cost,ResourceInventory.KIND.STONE:stone_cost}
