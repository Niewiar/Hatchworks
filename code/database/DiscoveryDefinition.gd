@tool
class_name DiscoveryDefinition
extends DatabaseEntry

@export var icon: Texture2D
@export var reward_item: StringName
@export_range(0, 100, 1) var reward_count := 0
