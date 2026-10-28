@tool
class_name DepositDefinition
extends DatabaseEntry

@export var variants: Array[Mesh] = []
@export var material: Material
@export_range(0.0, 0.1, 0.001) var density := 0.009
@export_range(0.1, 8.0, 0.1) var spacing := 2.0
@export_range(0.1, 4.0, 0.05) var minimum_scale := 0.8
@export_range(0.1, 4.0, 0.05) var maximum_scale := 1.25
@export var harvest_resource := 10
@export_range(1, 100, 1) var hits_required := 4
@export_range(1, 10000, 1) var harvest_amount := 12
