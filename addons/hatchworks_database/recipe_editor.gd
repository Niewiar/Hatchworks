@tool
extends VBoxContainer

signal edited(entry: Resource, property: String, value: Variant)
signal validity_changed(valid: bool)

const SCHEMA = preload("res://addons/hatchworks_database/database_schema.gd")
var _database: GameDatabase
var _recipe: DiscoveryRecipe
var valid_selection := false
var _syncing := false

func _ready() -> void:
	%First.item_selected.connect(_choice_changed.bind("first"))
	%Second.item_selected.connect(_choice_changed.bind("second"))
	%Result.item_selected.connect(_choice_changed.bind("result"))

func configure(database: GameDatabase, recipe: DiscoveryRecipe, result: StringName = &"") -> void:
	if is_instance_valid(_recipe) and _recipe.changed.is_connected(sync):
		_recipe.changed.disconnect(sync)
	_database = database
	_recipe = recipe
	var entries := database.discoveries.duplicate()
	entries.sort_custom(func(a,b): return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	for choice: OptionButton in [%First,%Second,%Result]:
		choice.clear()
		choice.add_item("Choose a discovery…")
		choice.set_item_metadata(0,&"")
		for entry in entries:
			choice.add_icon_item(entry.icon,entry.display_name)
			choice.set_item_metadata(choice.item_count-1,entry.id)
	if recipe != null:
		recipe.changed.connect(sync)
		sync()
	else:
		_select_value(%Result,result)
		_refresh()

func _select_value(choice: OptionButton, id: StringName) -> void:
	for index in choice.item_count:
		if choice.get_item_metadata(index) == id:
			choice.select(index)
			return
	choice.add_item("Missing: "+str(id))
	choice.set_item_metadata(choice.item_count-1,id)
	choice.select(choice.item_count-1)

func sync() -> void:
	if not is_instance_valid(_recipe):
		return
	_syncing = true
	_select_value(%First,_recipe.first)
	_select_value(%Second,_recipe.second)
	_select_value(%Result,_recipe.result)
	_syncing = false
	_refresh()

func values() -> Array[StringName]:
	var result: Array[StringName] = []
	for choice: OptionButton in [%First,%Second,%Result]:
		result.append(StringName(choice.get_selected_metadata()))
	return result

func _choice_changed(_index: int, property: String) -> void:
	if _syncing:
		return
	if _recipe != null:
		var index: int = ["first","second","result"].find(property)
		edited.emit(_recipe,property,values()[index])
	_refresh()

func _refresh() -> void:
	if _database == null:
		return
	var ids := values()
	var names := PackedStringArray()
	var icons := [%FirstIcon,%SecondIcon,%ResultIcon]
	for index in ids.size():
		var entry := _database.discovery(ids[index])
		names.append(entry.display_name if entry != null else "…")
		icons[index].texture = entry.icon if entry != null else null
	%Equation.text = "%s + %s → %s" % [names[0],names[1],names[2]]
	var reason := SCHEMA.recipe_error(_database,ids[0],ids[1],ids[2],_recipe)
	valid_selection = reason.is_empty()
	%Feedback.text = "Valid combination. Ingredient order does not matter." if valid_selection else reason
	%Feedback.modulate = Color(0.6,0.82,0.63) if valid_selection else Color(1,0.65,0.47)
	validity_changed.emit(valid_selection)
