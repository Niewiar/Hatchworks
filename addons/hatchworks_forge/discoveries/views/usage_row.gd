@tool
extends HBoxContainer

signal selected(id: String)

var _discovery_id := ""

func _ready() -> void:
	%Name.pressed.connect(_select)
	%Recipes.pressed.connect(_select)

func configure(data: Dictionary, counts: Dictionary, chosen: bool) -> void:
	_discovery_id = str(data.id)
	%Name.text = str(data.display_name)
	%Name.icon = ForgeDiscoveryLabels.icon(str(data.get("icon", "")))
	%Name.set_pressed_no_signal(chosen)
	%Category.text = ForgeDiscoveryLabels.category_name(int(data.category))
	%Input.text = str(counts.input)
	%Output.text = str(counts.output)
	%Recipes.text = str(counts.recipes)
	%Recipes.set_pressed_no_signal(chosen)

func _select() -> void:
	selected.emit(_discovery_id)
