@tool
class_name FanceData
extends DatabaseEntry

const REFERENCE_HEIGHT := 52.0

@export var ui_icon: Texture2D
@export var required_discovery: StringName
@export_range(24.0, 160.0, 1.0) var max_span_length := 84.0
@export_range(4.0, 100.0, 0.25) var height := 17.0
@export_range(1.0, 32.0, 0.25) var post_width := 4.25
@export_range(0.5, 24.0, 0.25) var thickness := 2.0
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

func detail_scale() -> float:
	return height / REFERENCE_HEIGHT
