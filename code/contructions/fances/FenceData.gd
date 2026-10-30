@tool
class_name FanceData
extends DatabaseEntry

@export var ui_icon: Texture2D
@export var required_discovery: StringName
@export_range(24.0, 160.0, 1.0) var max_span_length := 84.0
@export_range(16.0, 100.0, 1.0) var height := 52.0
@export_range(6.0, 32.0, 1.0) var post_width := 13.0
@export_range(3.0, 24.0, 1.0) var thickness := 6.0
@export var body_color := Color(0.51, 0.34, 0.20, 1.0)
@export var highlight_color := Color(0.77, 0.57, 0.34, 1.0)
@export var outline_color := Color(0.20, 0.17, 0.12, 1.0)
@export var max_health := 100.0
@export var post_max_health := 150.0
@export var post_priority := 0
@export_group("Construction cost")
@export var construction_resource: ResourceInventory.KIND = ResourceInventory.KIND.WOOD
@export var material_per_meter := 1.0
@export var material_per_post := 1
