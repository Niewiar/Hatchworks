@tool
class_name BuildingDefinition
extends DatabaseEntry

@export var scene: PackedScene
@export var icon: Texture2D
@export_group("Construction cost")
@export_range(0, 10000, 1) var wood_cost := 0
@export_range(0, 10000, 1) var stone_cost := 0
@export_range(0, 10000, 1) var fiber_cost := 0
enum COST_SCALING { LINEAR, MULTIPLICATIVE }

@export_group("Price progression")
@export var first_placement_free := true
@export var cost_scaling: COST_SCALING = COST_SCALING.LINEAR
@export_range(0,500,1) var cost_growth_percent := 50

@export_group("Building properties")
@export_range(0.25, 8.0, 0.05) var footprint_radius := 1.35
@export_range(0.0, 1.0, 0.01) var maximum_height_difference := 0.18

func costs() -> Dictionary[int, int]:
	return {ResourceInventory.KIND.WOOD:wood_cost,ResourceInventory.KIND.STONE:stone_cost,ResourceInventory.KIND.FIBER:fiber_cost}

@export var required_discovery: StringName
@export_range(1, 1000, 1) var storage_capacity := 20

@export_range(1.0,1000.0,1.0) var max_health := 100.0

func scaled_costs(existing_count: int, first_placement_used: bool = false) -> Dictionary[int, int]:
	var result := costs()
	var count := maxi(0,existing_count)
	if first_placement_free and not first_placement_used and count == 0:
		for kind: int in result:
			result[kind] = 0
		return result
	var paid_index := maxi(0,count-(1 if first_placement_free else 0))
	var increase := float(cost_growth_percent)/100.0
	var multiplier := pow(1.0+increase,mini(paid_index,1024)) if cost_scaling == COST_SCALING.MULTIPLICATIVE else 1.0+paid_index*increase
	for kind: int in result:
		result[kind] = int(minf(1000000000000.0,ceilf(result[kind]*multiplier))) if result[kind] > 0 else 0
	return result
