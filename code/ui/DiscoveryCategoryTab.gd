class_name DiscoveryCategoryTab
extends Button

@export var category := -1
@export var display_name := "All"
@export var icon_texture: Texture2D

func _ready() -> void:
	$Content/Icon.texture = icon_texture
	$Content/Name.text = display_name
	toggled.connect(_on_toggled)
	_on_toggled(button_pressed)

func set_counts(known: int, total: int) -> void:
	$Content/Count.text = "%d/%d" % [known,total]
	$Completed.visible = total > 0 and known == total

func _on_toggled(selected: bool) -> void:
	var color := Color(1,0.96,0.84) if selected else Color(0.22,0.18,0.13)
	$Content/Name.add_theme_color_override("font_color", color)
	$Content/Count.add_theme_color_override("font_color", color)
