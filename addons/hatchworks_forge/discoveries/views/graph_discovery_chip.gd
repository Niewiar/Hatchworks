@tool
extends Button

const DRAG_PREVIEW := preload("res://addons/hatchworks_forge/discoveries/views/graph_drag_preview.tscn")

var discovery_id := ""

func configure(data: Dictionary, prefix := "") -> void:
	discovery_id = str(data.get("id", ""))
	text = prefix + str(data.get("display_name", discovery_id))
	icon = ForgeDiscoveryLabels.icon(str(data.get("icon", "")))

func _get_drag_data(_at_position: Vector2) -> Variant:
	if discovery_id.is_empty():
		return null
	var preview := DRAG_PREVIEW.instantiate() as Label
	preview.text = text
	set_drag_preview(preview)
	return {"forge_discovery": discovery_id}
