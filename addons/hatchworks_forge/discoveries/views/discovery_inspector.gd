@tool
class_name ForgeDiscoveryInspector
extends ScrollContainer

signal recipe_selected(id: String)
signal conflicts_requested

var _document: ForgeDiscoveryDocument
var _discovery_id := ""
var _recipe_id := ""
var _binding := false

func _ready() -> void:
	%EditTile.toggled.connect(func(active: bool): %TileFields.visible = active)
	%Category.clear()
	for label in ForgeDiscoveryLabels.categories():
		%Category.add_item(label)
	for field in [%Name,%IconPath]:
		field.text_submitted.connect(func(_text): commit_fields())
		field.focus_exited.connect(commit_fields)
	%Description.focus_exited.connect(commit_fields)
	%Category.item_selected.connect(_change_category)
	%ChooseIcon.pressed.connect(func(): %IconDialog.popup_centered())
	%IconDialog.file_selected.connect(_select_icon)
	%RecipeChoice.item_selected.connect(_choose_recipe)
	%First.item_selected.connect(_change_ingredient.bind("first",%First))
	%Second.item_selected.connect(_change_ingredient.bind("second",%Second))
	%Result.item_selected.connect(_change_ingredient.bind("result",%Result))
	%Science.value_changed.connect(_change_science)
	%Duplicate.pressed.connect(_duplicate)
	%Remove.pressed.connect(_remove)
	%ShowConflicts.pressed.connect(func(): conflicts_requested.emit())
	for record in [[%First,"first"],[%Second,"second"],[%Result,"result"]]:
		record[0].set_drag_forwarding(Callable(),_can_drop_ingredient.bind(record[1]),_drop_ingredient.bind(record[1]))

func configure(document: ForgeDiscoveryDocument) -> void:
	_document = document

func show_discovery(id: String, recipe_id := "") -> void:
	_discovery_id = id
	_recipe_id = recipe_id
	refresh()

func refresh() -> void:
	if not is_node_ready() or _document == null:
		return
	_binding = true
	var entry := _document.discovery(_discovery_id)
	%Tile.visible = not entry.is_empty()
	if not entry.is_empty():
		%TileId.text = str(entry.id)
		%TileName.text = str(entry.display_name)
		%Portrait.texture = ForgeDiscoveryLabels.icon(str(entry.icon))
		if not %Name.has_focus():
			%Name.text = str(entry.display_name)
		if not %IconPath.has_focus():
			%IconPath.text = str(entry.icon)
		if not %Description.has_focus():
			%Description.text = str(entry.description)
		%Category.select(clampi(int(entry.category),0,6))
	var recipe := _document.recipe(_recipe_id)
	%Recipe.visible = not recipe.is_empty()
	%NoRecipe.visible = recipe.is_empty()
	if not recipe.is_empty():
		var related := _document.index.related(_discovery_id)
		if not related.any(func(record: Dictionary): return record.id == _recipe_id):
			related.append(recipe)
		%RecipeChoice.clear()
		for record: Dictionary in related:
			%RecipeChoice.add_item(ForgeDiscoveryLabels.equation(_document.index,record))
			var index: int = %RecipeChoice.item_count-1
			%RecipeChoice.set_item_metadata(index,str(record.id))
			if record.id == _recipe_id:
				%RecipeChoice.select(index)
		_fill_discoveries(%First,str(recipe.first))
		_fill_discoveries(%Second,str(recipe.second))
		_fill_discoveries(%Result,str(recipe.result))
		%Science.set_value_no_signal(float(recipe.science_reward))
		%RecipeId.text = str(recipe.id)
		var errors := PackedStringArray()
		for problem: Dictionary in _document.problems():
			if _recipe_id in problem.recipe_ids:
				errors.append(ForgeDiscoveryLabels.problem_message(_document.index,problem))
		%Problems.text = "\n".join(errors)
		%Problems.visible = not errors.is_empty()
		%ShowConflicts.visible = not errors.is_empty()
	_binding = false

func commit_fields() -> void:
	if _binding or not is_node_ready() or _document == null:
		return
	if not _document.discovery(_discovery_id).is_empty():
		_document.update_discovery(_discovery_id,"display_name",%Name.text)
		_document.update_discovery(_discovery_id,"icon",%IconPath.text.strip_edges())
		_document.update_discovery(_discovery_id,"description",%Description.text)

func _fill_discoveries(control: OptionButton, selected: String) -> void:
	control.clear()
	control.add_item("Wybierz kafel…")
	control.set_item_metadata(0,"")
	control.select(0)
	var entries: Array = _document.capture().discoveries.filter(func(entry: Variant): return entry is Dictionary)
	entries.sort_custom(func(a: Dictionary,b: Dictionary): return str(a.display_name).naturalnocasecmp_to(str(b.display_name)) < 0)
	if not selected.is_empty() and _document.discovery(selected).is_empty():
		control.add_item("Brak: "+selected)
		control.set_item_metadata(1,selected)
		control.select(1)
	for entry: Dictionary in entries:
		control.add_item(str(entry.display_name))
		var index := control.item_count-1
		control.set_item_metadata(index,str(entry.id))
		if entry.id == selected:
			control.select(index)

func _change_category(index: int) -> void:
	if not _binding and _document != null:
		_document.update_discovery(_discovery_id,"category",index)

func _select_icon(path: String) -> void:
	%IconPath.text = path
	commit_fields()

func _choose_recipe(index: int) -> void:
	if not _binding:
		recipe_selected.emit(str(%RecipeChoice.get_item_metadata(index)))

func _change_ingredient(index: int, field: String, control: OptionButton) -> void:
	if not _binding and _document != null:
		_document.update_recipe(_recipe_id,field,str(control.get_item_metadata(index)))

func _change_science(value: float) -> void:
	if not _binding and _document != null:
		_document.update_recipe(_recipe_id,"science_reward",int(value))

func _duplicate() -> void:
	commit_fields()
	if _document != null:
		var id := _document.duplicate_recipe(_recipe_id)
		if not id.is_empty():
			recipe_selected.emit(id)

func _remove() -> void:
	commit_fields()
	if _document != null:
		_document.remove_recipe(_recipe_id)

func _can_drop_ingredient(_position: Vector2, data: Variant, _field: String) -> bool:
	return _document != null and data is Dictionary and data.get("forge_discovery") is String and not _document.discovery(data.forge_discovery).is_empty() and not _document.recipe(_recipe_id).is_empty()

func _drop_ingredient(position: Vector2, data: Variant, field: String) -> void:
	if _can_drop_ingredient(position,data,field):
		_document.update_recipe(_recipe_id,field,str(data.forge_discovery))
