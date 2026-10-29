@tool
extends VBoxContainer

signal recipe_selected(recipe: DiscoveryRecipe)
signal add_requested(discovery: DiscoveryDefinition)

var _discovery: DiscoveryDefinition

func _ready() -> void:
	%Add.pressed.connect(func(): add_requested.emit(_discovery))
	%Links.item_activated.connect(_open_recipe)

func configure(database: GameDatabase, discovery: DiscoveryDefinition) -> void:
	_discovery = discovery
	%Links.clear()
	var root: TreeItem = %Links.create_item()
	var creates: TreeItem = %Links.create_item(root)
	creates.set_text(0,"Created by")
	creates.set_selectable(0,false)
	var uses: TreeItem = %Links.create_item(root)
	uses.set_text(0,"Used in")
	uses.set_selectable(0,false)
	var created_count := 0
	var used_count := 0
	for recipe: DiscoveryRecipe in database.recipes:
		var parent: TreeItem
		if recipe.result == discovery.id:
			parent = creates
			created_count += 1
		elif recipe.first == discovery.id or recipe.second == discovery.id:
			parent = uses
			used_count += 1
		else:
			continue
		var row: TreeItem = %Links.create_item(parent)
		var first := database.discovery(recipe.first)
		var second := database.discovery(recipe.second)
		var result := database.discovery(recipe.result)
		row.set_text(0,"%s + %s → %s" % [first.display_name if first != null else str(recipe.first),second.display_name if second != null else str(recipe.second),result.display_name if result != null else str(recipe.result)])
		row.set_metadata(0,recipe)
		if result != null:
			row.set_icon(0,result.icon)
			row.set_icon_max_width(0,18)
	creates.set_text(0,"Created by · %d" % created_count)
	uses.set_text(0,"Used in · %d" % used_count)

func _open_recipe() -> void:
	var row: TreeItem = %Links.get_selected()
	if row != null and row.get_metadata(0) is DiscoveryRecipe:
		recipe_selected.emit(row.get_metadata(0))
