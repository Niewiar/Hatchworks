@tool
class_name CreatureSpecies
extends DatabaseEntry

@export var scene: PackedScene
@export var icon: Texture2D
@export_range(0.5, 4.0, 0.1) var hold_height := 1.8
@export_range(0.1, 50.0, 0.1) var follow_speed := 14.0
@export_range(0.1, 50.0, 0.1) var rotation_speed := 9.0
@export_range(0.0, 0.8, 0.01) var maximum_tilt := 0.24

@export_group("Tuftling behaviour")
@export_range(0.2, 5.0, 0.1) var walk_speed := 1.4
@export_range(0.2, 5.0, 0.1) var swim_speed := 1.05
@export_range(0.1, 1.0, 0.05) var minimum_swim_depth := 0.3
@export_range(1.0, 30.0, 0.5) var bathing_seconds := 3.0
@export_range(0.5, 10.0, 0.1) var shaking_seconds := 1.8
@export_range(0.5, 30.0, 0.5) var resting_seconds := 3.0
@export_range(1, 12, 1) var grass_per_cycle := 3
@export_range(0.4, 3.0, 0.1) var grass_radius := 1.0
@export var food_resource := 5
@export_range(1, 10, 1) var food_per_feeding := 1

@export_range(0.5, 10.0, 0.1) var feeding_seconds := 2.0

@export_group("Satiety")
@export_range(30.0,3600.0,1.0) var satiety_seconds := 240.0
@export_range(1.0,90.0,1.0) var feeding_threshold := 35.0
@export_range(1.0,100.0,1.0) var satiety_per_meal := 60.0
