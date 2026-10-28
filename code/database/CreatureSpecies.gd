@tool
class_name CreatureSpecies
extends DatabaseEntry

@export var scene: PackedScene
@export var icon: Texture2D
@export_range(0.5, 4.0, 0.1) var hold_height := 1.8
@export_range(0.1, 50.0, 0.1) var follow_speed := 14.0
@export_range(0.1, 50.0, 0.1) var rotation_speed := 9.0
@export_range(0.0, 0.8, 0.01) var maximum_tilt := 0.24
