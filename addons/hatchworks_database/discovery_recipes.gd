@tool
extends VBoxContainer

signal recipe_selected(recipe: DiscoveryRecipe)
signal add_requested(discovery: DiscoveryDefinition)
signal edited(entry: Resource, property: String, value: Variant)
signal recipe_focused(recipe: DiscoveryRecipe)

var _discovery: DiscoveryDefinition
var _database: GameDatabase
var _recipe: DiscoveryRecipe
var _refresh_queued := false
var _syncing := false

func _ready() -> void:
	%Add.pressed.connect(func(): add_requested.emit(_discovery))
	%Links.item_selected.connect(_select_recipe)
	%Links.item_activated.connect(_open_recipe)
	%InlineRecipe.edited.connect(func(entry,property,value): edited.emit(entry,property,value))
	%Science.value_changed.connect(_science_changed)

func configure(database: GameDatabase, discovery: DiscoveryDefinition) -> void:
	if _discovery != discovery:
		_recipe = null
	_database = database
	_discovery = discovery
	refresh()

func refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()

func _refresh() -> void:
	_refresh_queued = false
	if _database == null or _discovery == null or not is_inside_tree():
		return
	_syncing = true
	%Links.clear()
	var root: TreeItem = %Links.create_item()
	var first: TreeItem
	var matches: Array[DiscoveryRecipe] = []
	for creates in [true,false]:
		for candidate: DiscoveryRecipe in _database.recipes:
			if _discovery.id in [candidate.first,candidate.second,candidate.result] and (candidate.result == _discovery.id) == creates:
				matches.append(candidate)
	for recipe: DiscoveryRecipe in matches:
		var row: TreeItem = %Links.create_item(root)
		if first == null:
			first = row
		var a := _database.discovery(recipe.first)
		var b := _database.discovery(recipe.second)
		var result := _database.discovery(recipe.result)
		row.set_text(0,"%s + %s → %s" % [a.display_name if a != null else "…",b.display_name if b != null else "…",result.display_name if result != null else "…"])
		row.set_metadata(0,recipe)
		if recipe == _recipe:
			row.select(0)
	if %Links.get_selected() == null and first != null:
		first.select(0)
	_syncing = false
	_select_recipe()

func _select_recipe() -> void:
	if _syncing:
		return
	var row: TreeItem = %Links.get_selected()
	_recipe = row.get_metadata(0) if row != null else null
	%InlineRecipe.visible = _recipe != null
	%ScienceRow.visible = _recipe != null
	%Empty.visible = _recipe == null
	if _recipe != null:
		%InlineRecipe.configure(_database,_recipe)
		%Science.set_value_no_signal(_recipe.science_reward)
		recipe_focused.emit(_recipe)

func _science_changed(value: float) -> void:
	if _recipe != null:
		edited.emit(_recipe,"science_reward",roundi(value))

func _open_recipe() -> void:
	if _recipe != null:
		recipe_selected.emit(_recipe)
