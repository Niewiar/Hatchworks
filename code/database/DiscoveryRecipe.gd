@tool
class_name DiscoveryRecipe
extends DatabaseEntry

@export var first: StringName
@export var second: StringName
@export var result: StringName
@export_range(0, 1000, 1) var science_reward := 1

func matches(a: StringName, b: StringName) -> bool:
	return (first == a and second == b) or (first == b and second == a)
