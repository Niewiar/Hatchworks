@tool
class_name BuildingDefinition
extends DatabaseEntry

@export var scene: PackedScene
@export var icon: Texture2D
@export_range(0, 10000, 1) var wood_cost := 0
@export_range(0, 10000, 1) var stone_cost := 0
@export_range(0, 10000, 1) var fiber_cost := 0
@export_range(0.25, 8.0, 0.05) var footprint_radius := 1.35
@export_range(0.0, 1.0, 0.01) var maximum_height_difference := 0.18

func costs() -> Dictionary[int, int]:
	return {ResourceInventory.KIND.WOOD:wood_cost,ResourceInventory.KIND.STONE:stone_cost,ResourceInventory.KIND.FIBER:fiber_cost}

@export var required_discovery: StringName
@export_range(1, 1000, 1) var storage_capacity := 20

@export_range(1.0,1000.0,1.0) var max_health := 100.0
