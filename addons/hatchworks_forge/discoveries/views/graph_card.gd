@tool
extends GraphNode

signal recipe_selected(id: String)
signal discovery_selected(id: String)

var _recipe_id := ""

func _ready() -> void:
	for button in [%Discovery, %First, %Second, %Partner, %Result]:
		button.pressed.connect(_open_discovery.bind(button))
	%EditIncoming.pressed.connect(_edit_recipe)
	%EditOutgoing.pressed.connect(_edit_recipe)

func configure_discovery(data: Dictionary) -> void:
	%Central.show()
	%Incoming.hide()
	%Outgoing.hide()
	title = str(data.get("display_name", data.get("id", "")))
	%Discovery.configure(data)
	set_slot(0, true, 0, get_theme_color("accent_color", "Editor"), true, 0, get_theme_color("accent_color", "Editor"))

func configure_recipe(recipe: Dictionary, index: ForgeDiscoveryIndex, focus: String, incoming: bool, conflict: bool, chosen: bool) -> void:
	_recipe_id = str(recipe.id)
	%Central.hide()
	%Incoming.visible = incoming
	%Outgoing.visible = not incoming
	title = ("Konflikt · " if conflict else "") + ("Powstaje z" if incoming else "Tworzy")
	if incoming:
		%First.configure(_entry(index, str(recipe.first)))
		%Second.configure(_entry(index, str(recipe.second)))
	else:
		var partner := str(recipe.second) if str(recipe.first) == focus else str(recipe.first)
		%Partner.configure(_entry(index, partner), ForgeDiscoveryLabels.title(index, focus) + " + ")
		%Result.configure(_entry(index, str(recipe.result)), "→ ")
	selected = chosen
	var wire_color := get_theme_color("error_color", "Editor") if conflict else get_theme_color("accent_color", "Editor")
	set_slot(0, not incoming, 0, wire_color, incoming, 0, wire_color)
	if conflict:
		for style_name in ["panel", "panel_selected"]:
			var panel := get_theme_stylebox(style_name).duplicate() as StyleBoxFlat
			if panel != null:
				panel.border_color = wire_color
				panel.set_border_width_all(2)
				add_theme_stylebox_override(style_name, panel)
		add_theme_color_override("title_color", wire_color)

func _entry(index: ForgeDiscoveryIndex, id: String) -> Dictionary:
	var data := index.discovery(id)
	return data if not data.is_empty() else {"id": id, "display_name": "Brak: " + id}

func _edit_recipe() -> void:
	recipe_selected.emit(_recipe_id)

func _open_discovery(button: Button) -> void:
	discovery_selected.emit(button.discovery_id)
