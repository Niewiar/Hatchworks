@tool
class_name FloraSpecies
extends DatabaseEntry

enum KIND { TREE, SHRUB, FERN, REEDS, GRASS }

@export var kind: KIND = KIND.GRASS
@export var variants: Array[Mesh] = []
@export_range(0.0, 2.0, 0.001) var density := 0.1
@export var spacing := 0.5
@export var minimum_scale := 0.8
@export var maximum_scale := 1.2
@export var growth_rate := 0.15
@export var canopy_radius := 0.0
@export var trunk_radius := 0.12
@export var trunk_height := 1.3

@export_group("Harvesting")
@export var harvest_resource: ResourceInventory.KIND = ResourceInventory.KIND.FIBER
@export var harvest_amount := 1

@export_group("Habitat")
@export var maximum_slope := 0.6
@export var water_depth_range := Vector2(-100.0, -0.015)
@export_range(1, 100, 1) var hits_required := 4

@export var ground_material := -1
