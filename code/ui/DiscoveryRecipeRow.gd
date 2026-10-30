extends VBoxContainer

func configure(database: GameDatabase, recipe: DiscoveryRecipe, known: bool, visible_part: int) -> void:
	var parts := [recipe.first,recipe.second,recipe.result]
	for index in parts.size():
		var box := get_node("Equation/Part"+str(index))
		var revealed := known or index == visible_part
		var entry := database.discovery(parts[index])
		box.get_node("Name").text = entry.display_name if revealed else "???"
		box.get_node("Icon").texture = entry.icon if revealed else null
		box.get_node("Icon").visible = true
