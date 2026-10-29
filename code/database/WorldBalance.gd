@tool
class_name WorldBalance
extends DatabaseEntry

@export var generate_nature_on_start := false
@export var water_level := -0.35
@export_range(0.0, 4.0, 0.1) var starting_height_variation := 1.8
@export_range(8.0, 64.0, 1.0) var terrain_wavelength := 22.0
@export_range(0.0, 8.0, 0.25) var spawn_clearing_radius := 2.5
@export_range(0.1, 4.0, 0.1) var sculpt_speed := 1.0
@export_range(10.0, 60.0, 1.0) var maximum_sculpt_slope := 40.0
@export_range(0.05, 1.0, 0.01) var gather_interval := 0.12

@export_range(0.0, 5.0, 0.1) var starting_pond_radius := 2.4
@export var starting_pond_offset := Vector2(0, 5.5)
