@tool
class_name CreatureResearch
extends DatabaseEntry

@export var creature_id: StringName = &"tuftling"
@export var action_id: StringName
@export_range(0, 1000, 1) var science_reward := 2
