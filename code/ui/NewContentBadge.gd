class_name NewContentBadge
extends PanelContainer

func set_count(value: int) -> void:
	visible = value > 0
	$Count.text = str(value)
