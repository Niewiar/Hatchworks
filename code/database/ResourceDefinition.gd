@tool
class_name ResourceDefinition
extends DatabaseEntry

@export var kind := 11
@export var icon: Texture2D
@export_range(0.0, 1000000.0, 0.1) var starting_amount := 0.0
