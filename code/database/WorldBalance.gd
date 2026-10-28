@tool
class_name WorldBalance
extends DatabaseEntry

@export var water_level := -0.35
@export_range(0.0, 4.0, 0.1) var starting_height_variation := 1.8
@export_range(8.0, 64.0, 1.0) var terrain_wavelength := 22.0
@export_range(0.0, 8.0, 0.25) var spawn_clearing_radius := 2.5
@export_range(0.1, 4.0, 0.1) var sculpt_speed := 1.0
@export_range(10.0, 60.0, 1.0) var maximum_sculpt_slope := 40.0
@export_range(0.05, 2.0, 0.05) var wetting_speed := 0.45
@export_range(0.01, 0.5, 0.01) var drying_speed := 0.07
@export_range(0.05, 1.0, 0.05) var ground_change_speed := 0.3
@export_range(0.05, 1.0, 0.01) var gather_interval := 0.12
