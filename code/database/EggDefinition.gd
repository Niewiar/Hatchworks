@tool
class_name EggDefinition
extends DatabaseEntry

@export var creature_id: StringName = &"tuftling"
@export var model: PackedScene
@export_range(1.0, 3600.0, 1.0) var incubation_seconds := 30.0
