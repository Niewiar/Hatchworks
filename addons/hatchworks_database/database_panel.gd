@tool
extends PanelContainer

const SCHEMA := preload("res://addons/hatchworks_database/database_schema.gd")
const FIELD := preload("res://addons/hatchworks_database/database_field.tscn")

@onready var _categories: ItemList = %Categories
@onready var _table: Tree = %Entries
@onready var _fields: VBoxContainer = %Fields
@onready var _search: LineEdit = %Search
@onready var _preview: SubViewportContainer = %Preview

var _database: GameDatabase
var _history: EditorUndoRedoManager
var _category := "Flora"
var _selected: Resource
var _baseline: Dictionary = {}
var _disk_hashes: Dictionary = {}
var _known: Dictionary = {}
var _membership := ""
var _refreshing := false
var _table_refresh_queued := false
var _sort_column := 0
var _sort_ascending := true
var _asset_field: Control
var _pending_remove: Array = []

func _ready() -> void:
	_categories.item_selected.connect(_on_category_selected)
	_search.text_changed.connect(func(_text): _refresh_table())
	_table.item_selected.connect(_on_selection_changed)
	_table.multi_selected.connect(func(_item,_column,_selected): _on_selection_changed())
	_table.item_edited.connect(_on_cell_edited)
	_table.column_title_clicked.connect(_on_sort)
	%New.pressed.connect(_create_entry)
	%Duplicate.pressed.connect(_duplicate_entry)
	%Remove.pressed.connect(_ask_remove)
	%Save.pressed.connect(save_all)
	%Undo.pressed.connect(_undo)
	%Redo.pressed.connect(_redo)
	%Validate.pressed.connect(_show_validation)
	%Reload.pressed.connect(func(): %ReloadDialog.popup_centered())
	%ReloadDialog.confirmed.connect(_load_database)
	%RemoveDialog.confirmed.connect(_remove_entries)
	%BulkApply.pressed.connect(_apply_bulk)
	%AssetDialog.file_selected.connect(func(path): _accept_assets(PackedStringArray([path])))
	%AssetDialog.files_selected.connect(_accept_assets)
	%RecipeEditor.edited.connect(_request_edit)
	%DiscoveryRecipes.recipe_selected.connect(_navigate_recipe)
	%DiscoveryRecipes.add_requested.connect(_open_recipe_dialog)
	%RecipeDraft.validity_changed.connect(_on_recipe_validity_changed)
	%RecipeDialog.confirmed.connect(_create_recipe_from_dialog)
	%GraphMode.toggled.connect(_set_graph_mode)
	%DiscoveryGraph.entry_selected.connect(_graph_selection)
	%DiscoveryGraph.property_requested.connect(_request_edit)
	%DiscoveryGraph.discovery_requested.connect(_create_graph_discovery)
	%DiscoveryGraph.recipe_requested.connect(_create_graph_recipe)
	%DiscoveryGraph.removal_requested.connect(_ask_graph_remove)
	%DiscoveryGraph.message_requested.connect(_status)

func configure(history: EditorUndoRedoManager) -> void:
	_history = history
	_load_database()

func _load_database() -> void:
	_database = ResourceLoader.load(GameDatabase.DEFAULT_PATH,"",ResourceLoader.CACHE_MODE_REPLACE_DEEP) as GameDatabase
	if _database == null:
		_status("Unable to load the game database.",true)
		return
	_selected = null
	_baseline.clear()
	_disk_hashes.clear()
	_known.clear()
	for category in SCHEMA.CATEGORIES:
		for entry: Resource in _database.entries(category):
			if entry != null:
				_known[entry] = category
				_baseline[entry] = SCHEMA.fingerprint(entry)
				_watch_path(entry.resource_path)
	_watch_path(_database.resource_path)
	if _database.construction != null:
		_watch_path(_database.construction.resource_path)
	_membership = _membership_key()
	%DiscoveryGraph.configure(_database,_history)
	_categories.clear()
	for category in SCHEMA.CATEGORIES:
		_categories.add_item(category)
	_categories.select(SCHEMA.CATEGORIES.find(_category))
	_set_category(_category)
	_status("Loaded database. Changes take effect on the next game start.")
	_show_validation()

func _watch_path(path: String) -> void:
	_disk_hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""

func _membership_key() -> String:
	var groups: Array = []
	for category in SCHEMA.CATEGORIES:
		var records: Array = []
		for entry: Resource in _database.entries(category):
			records.append(entry.get_instance_id() if entry != null else 0)
		groups.append([category,records])
	return var_to_str(groups)

func _dirty(entry: Resource) -> bool:
	return not _baseline.has(entry) or _baseline[entry] != SCHEMA.fingerprint(entry)

func _on_category_selected(index: int) -> void:
	if SCHEMA.CATEGORIES[index] not in ["Discoveries","Recipes"]:
		%GraphMode.button_pressed = false
	_set_category(SCHEMA.CATEGORIES[index])

func _set_category(category: String) -> void:
	_category = category
	_selected = null
	_sort_column = 0
	_sort_ascending = true
	_categories.select(SCHEMA.CATEGORIES.find(category))
	%SectionTitle.text = category
	%Hint.text = "Select a recipe and choose its ingredients and result on the right.\n+ New opens the recipe composer." if category == "Recipes" else "Double-click a table cell to edit.\nCtrl / Shift: multi-select.\nCtrl+Z: undo."
	%New.disabled = category == "World Balance"
	%Duplicate.disabled = category == "World Balance"
	%Remove.disabled = category == "World Balance"
	%BulkField.clear()
	for data in SCHEMA.fields(category):
		if data.type == "number" and data.key != "kind":
			%BulkField.add_item(data.label)
			%BulkField.set_item_metadata(%BulkField.item_count-1,data.key)
	%BulkTools.visible = %BulkField.item_count > 0
	_refresh_table()

func _refresh_table() -> void:
	if _table_refresh_queued:
		return
	_table_refresh_queued = true
	_rebuild_table.call_deferred()

func _rebuild_table() -> void:
	_table_refresh_queued = false
	if _database == null or not is_inside_tree():
		return
	var selected := _selected_entries()
	_refreshing = true
	_table.clear()
	var columns: Array = SCHEMA.COLUMNS[_category]
	_table.columns = columns.size()
	for index in columns.size():
		_table.set_column_title(index,SCHEMA.label_for(_category,columns[index])+((" ↑" if _sort_ascending else " ↓") if index == _sort_column else ""))
		_table.set_column_expand(index,true)
		_table.set_column_custom_minimum_width(index,145 if index == 0 else 90)
	var records: Array = _database.entries(_category).duplicate()
	var key: String = columns[_sort_column]
	records.sort_custom(func(a,b):
		if a == null: return false
		if b == null: return true
		var first: Variant = a.get(key)
		var last: Variant = b.get(key)
		return first < last if _sort_ascending else first > last)
	var root := _table.create_item()
	var shown := 0
	var first_item: TreeItem
	for entry: Resource in records:
		if entry == null or (not _search.text.is_empty() and not (str(entry.id)+" "+entry.display_name).containsn(_search.text)):
			continue
		var row := _table.create_item(root)
		if first_item == null:
			first_item = row
		row.set_metadata(0,entry)
		for index in columns.size():
			row.set_text(index,SCHEMA.value_text(_database,entry,columns[index])+( " *" if index == 0 and _dirty(entry) else ""))
			var editable: bool = not (entry is ResourceDefinition and columns[index] == "kind" and entry.kind in ResourceInventory.KIND.values())
			for data in SCHEMA.fields(_category):
				if data.key == columns[index] and data.type in ["discovery","item","creature"]:
					editable = false
			row.set_editable(index,editable)
		if entry in selected or entry == _selected:
			row.select(0)
		shown += 1
	%Count.text = "%d / %d entries" % [shown,records.size()]
	if _table.get_selected() == null and first_item != null:
		first_item.select(0)
	_refreshing = false
	_on_selection_changed()
	_refresh_dirty()
	%DiscoveryGraph.refresh()

func _selected_entries() -> Array:
	var result: Array = []
	var item := _table.get_next_selected(null)
	while item != null:
		result.append(item.get_metadata(0))
		item = _table.get_next_selected(item)
	return result

func _on_selection_changed() -> void:
	if _refreshing:
		return
	var item := _table.get_selected()
	var entry: Resource = item.get_metadata(0) if item != null else null
	if entry != _selected:
		_select_entry(entry)
	%SelectionCount.text = "%d selected" % _selected_entries().size()

func _select_entry(entry: Resource) -> void:
	_selected = entry
	%DiscoveryGraph.select_entry(entry)
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	%DetailsTitle.text = entry.display_name if entry != null else "Select an entry"
	%EntryPath.text = entry.resource_path if entry != null else ""
	%Metrics.text = SCHEMA.summary(entry) if entry != null else ""
	%Usage.text = _usage_text(entry) if entry != null else ""
	%RecipeEditor.visible = entry is DiscoveryRecipe
	%DiscoveryRecipes.visible = entry is DiscoveryDefinition
	_preview.visible = not entry is DiscoveryRecipe
	%Metrics.visible = not entry is DiscoveryRecipe
	_preview.show_entry(entry)
	if entry is DiscoveryRecipe:
		%RecipeEditor.configure(_database,entry)
	if entry is DiscoveryDefinition:
		%DiscoveryRecipes.configure(_database,entry)
	if entry == null:
		return
	for data in SCHEMA.fields(_category):
		if entry is DiscoveryRecipe and data.key in ["first","second","result"]:
			continue
		var field := FIELD.instantiate()
		_fields.add_child(field)
		field.configure(entry,data,_database)
		field.edited.connect(_request_edit)
		field.asset_requested.connect(_browse_asset)

func _request_edit(entry: Resource, property: String, value: Variant) -> void:
	if entry is ResourceDefinition and property == "kind" and entry.kind in ResourceInventory.KIND.values():
		_status("Built-in resource numeric IDs are fixed gameplay roles.",true)
		entry.emit_changed()
		return
	if entry is CreatureSpecies and entry.id == &"tuftling" and property == "id" and value != &"tuftling":
		_status("The existing Tuftling scene uses stable ID tuftling.",true)
		entry.emit_changed()
		return
	var previous: Variant = entry.get(property)
	if previous == value:
		return
	_history.create_action("Database: "+str(entry.id)+"."+property,UndoRedo.MERGE_ENDS,_database)
	_history.add_do_method(self,"_apply_property",entry,property,value)
	_history.add_undo_method(self,"_apply_property",entry,property,previous)
	_history.commit_action()

func _apply_property(entry: Resource, property: String, value: Variant) -> void:
	entry.set(property,value)
	entry.emit_changed()
	if _selected == entry:
		%DetailsTitle.text = entry.display_name
		%Metrics.text = SCHEMA.summary(entry)
		if property in ["variants","scene","model","material","icon","ui_icon"]:
			_preview.show_entry(entry)
	_refresh_table()
	_show_validation()
	if entry is DiscoveryRecipe:
		var reason := SCHEMA.recipe_error(_database,entry.first,entry.second,entry.result,entry)
		_status(reason if not reason.is_empty() else ("Recipe updated. Save All to apply it to the game." if _dirty(entry) else "Recipe restored."),not reason.is_empty())

func _on_cell_edited() -> void:
	var row := _table.get_edited()
	var column := _table.get_edited_column()
	var entry: Resource = row.get_metadata(0)
	var key: String = SCHEMA.COLUMNS[_category][column]
	var text := row.get_text(column).trim_suffix(" *")
	var old: Variant = entry.get(key)
	if typeof(old) in [TYPE_INT,TYPE_FLOAT]:
		if not text.is_valid_float():
			_status("Enter a valid number.",true)
			_refresh_table()
			return
		_request_edit(entry,key,roundi(text.to_float()) if typeof(old) == TYPE_INT else text.to_float())
	else:
		_request_edit(entry,key,StringName(text) if typeof(old) == TYPE_STRING_NAME else text)

func _on_sort(column: int, _mouse_button: int) -> void:
	_sort_ascending = not _sort_ascending if _sort_column == column else true
	_sort_column = column
	_refresh_table()

func _create_entry() -> void:
	if _category == "Recipes":
		_open_recipe_dialog(null)
		return
	if not SCHEMA.SCRIPTS.has(_category):
		return
	var entry: Resource = SCHEMA.SCRIPTS[_category].new()
	if entry is ResourceDefinition:
		entry.kind = 11
		for resource in _database.resources:
			entry.kind = maxi(entry.kind,resource.kind+1)
	_register_new(entry,"new_"+SCHEMA.FOLDERS[_category])

func _duplicate_entry() -> void:
	if _selected == null or _category == "World Balance":
		return
	var entry := _selected.duplicate() as Resource
	if entry is ResourceDefinition:
		entry.kind = 11
		for resource in _database.resources:
			entry.kind = maxi(entry.kind,resource.kind+1)
	_register_new(entry,str(_selected.id)+"_copy")

func _register_new(entry: Resource, base_id: String) -> void:
	var suffix := 1
	var id := base_id
	var folder: String = "res://resources/database/"+SCHEMA.FOLDERS[_category]
	var path := folder+"/"+id+".tres"
	var ids: Array = _database.entries(_category).map(func(data): return str(data.id))
	while ids.has(id) or ResourceLoader.exists(path) or FileAccess.file_exists(path) or ResourceLoader.has_cached(path):
		suffix += 1
		id = base_id+"_"+str(suffix)
		path = folder+"/"+id+".tres"
	entry.id = StringName(id)
	entry.display_name = (_selected.display_name+" copy") if base_id.ends_with("_copy") and _selected != null else "New "+_category.to_lower().trim_suffix("s")
	if entry is DiscoveryRecipe and _database.discovery(entry.first) != null and _database.discovery(entry.second) != null and _database.discovery(entry.result) != null:
		entry.display_name = "%s + %s → %s" % [_database.discovery(entry.first).display_name,_database.discovery(entry.second).display_name,_database.discovery(entry.result).display_name]
	entry.take_over_path(path)
	_known[entry] = _category
	_disk_hashes[path] = ""
	var previous := _database.entries(_category).duplicate()
	var current := previous.duplicate()
	current.append(entry)
	_history.create_action("Database: add entry",UndoRedo.MERGE_DISABLE,_database)
	_history.add_do_method(self,"_replace_entries",_category,current,entry)
	_history.add_undo_method(self,"_replace_entries",_category,previous,_selected)
	_history.commit_action()
	_status("New entry added. Complete its fields and save the database.")

func _replace_entries(category: String, values: Array, selection: Resource) -> void:
	_database.replace_entries(category,values)
	if _category == category:
		_table.deselect_all()
		_selected = null
		_select_entry(selection)
	_refresh_table()
	_show_validation()

func _usage_text(entry: Resource) -> String:
	var uses := _usages(entry)
	return "Used by: "+("; ".join(uses) if not uses.is_empty() else "Catalog only")

func _usages(entry: Resource) -> PackedStringArray:
	var result := PackedStringArray()
	if entry is WorldBalance:
		result.append("MapManager world settings")
	if entry is ResourceDefinition:
		if entry.kind in ResourceInventory.KIND.values():
			result.append("Built-in gameplay resource")
		for building: BuildingDefinition in _database.buildings:
			if building.costs().get(entry.kind,0) > 0:
				result.append("Buildings / "+building.display_name)
		for category in ["Flora","Deposits","Construction","Creatures"]:
			for other: Resource in _database.entries(category):
				if other.get({"Construction":"construction_resource","Creatures":"food_resource"}.get(category,"harvest_resource")) == entry.kind:
					result.append(category+" / "+other.display_name)
	if entry is DiscoveryDefinition:
		for recipe in _database.recipes:
			if entry.id in [recipe.first,recipe.second,recipe.result]:
				result.append("Recipes / "+recipe.display_name)
		for building in _database.buildings:
			if building.required_discovery == entry.id:
				result.append("Buildings / "+building.display_name)
	if entry is EggDefinition:
		result.append("Life Workshop crafting and creature breeding")
		for discovery in _database.discoveries:
			if discovery.reward_item == entry.id:
				result.append("Discoveries / "+discovery.display_name)
	if entry is CreatureResearch:
		result.append("ScienceController first species action rewards")
	if entry is CreatureSpecies:
		for other: CreatureSpecies in _database.creatures:
			if other != entry and other.species_aversions.has(entry.id):
				result.append("Creatures / "+other.display_name+" · species aversion")
		for research in _database.research:
			if research.creature_id == entry.id:
				result.append("Creature Research / "+research.display_name)
	if entry is BuildingDefinition:
		result.append("Building mode")
	if entry is FloraSpecies and entry.kind == FloraSpecies.KIND.GRASS:
		result.append("Tuftling sowing")
	if entry is GlossaryEntry and str(entry.id) in ["soil","water","grass","fiber"]:
		result.append("Shared gameplay tooltips")
	if entry is CreatureSpecies and entry.id == &"tuftling":
		result.append("Tuftling scene Species ID")
	for path in _data_files("res://"):
		if path in [entry.resource_path,_database.resource_path,_database.construction.resource_path]:
			continue
		for dependency in ResourceLoader.get_dependencies(path):
			if dependency.get_slice("::",dependency.get_slice_count("::")-1) == entry.resource_path:
				result.append(path.trim_prefix("res://"))
				break
	return result

func _data_files(folder: String) -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open(folder)
	if directory == null:
		return result
	for file in directory.get_files():
		if file.get_extension() in ["tscn","tres"]:
			result.append(folder.path_join(file))
	for child in directory.get_directories():
		if child.begins_with(".") or child == "addons":
			continue
		result.append_array(_data_files(folder.path_join(child)))
	return result

func _ask_remove() -> void:
	_pending_remove = _selected_entries()
	if _pending_remove.is_empty() or _category == "World Balance":
		return
	for entry: Resource in _pending_remove:
		var uses := _usages(entry)
		if not uses.is_empty():
			_status("Cannot remove "+entry.display_name+": "+"; ".join(uses),true)
			return
	%RemoveDialog.dialog_text = "Remove %d entries from the catalog? Their files will be deleted when you save. This action supports Undo." % _pending_remove.size()
	%RemoveDialog.popup_centered()

func _remove_entries() -> void:
	var previous := _database.entries(_category).duplicate()
	var current := previous.duplicate()
	for entry in _pending_remove:
		current.erase(entry)
	_history.create_action("Database: remove entries",UndoRedo.MERGE_DISABLE,_database)
	_history.add_do_method(self,"_replace_entries",_category,current,null)
	_history.add_undo_method(self,"_replace_entries",_category,previous,_selected)
	_history.commit_action()
	_pending_remove.clear()

func _apply_bulk() -> void:
	var selection := _selected_entries()
	if selection.size() < 2:
		_status("Select at least two rows with Ctrl or Shift.",true)
		return
	var key: String = %BulkField.get_item_metadata(%BulkField.selected)
	_history.create_action("Database: scale "+key,UndoRedo.MERGE_DISABLE,_database)
	for entry: Resource in selection:
		var old: Variant = entry.get(key)
		var value: Variant = float(old)*%BulkFactor.value
		if typeof(old) == TYPE_INT:
			value = roundi(value)
		_history.add_do_method(self,"_apply_property",entry,key,value)
		_history.add_undo_method(self,"_apply_property",entry,key,old)
	_history.commit_action()

func _browse_asset(field: Control, multiple: bool, type: String) -> void:
	_asset_field = field
	%AssetDialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES if multiple else FileDialog.FILE_MODE_OPEN_FILE
	%AssetDialog.filters = PackedStringArray(["*.res, *.tres, *.tscn, *.glb, *.gltf, *.png, *.svg, *.webp ; "+type+" assets"])
	%AssetDialog.popup_centered_ratio(0.7)

func _accept_assets(paths: PackedStringArray) -> void:
	if is_instance_valid(_asset_field) and not paths.is_empty():
		_asset_field.accept_paths(paths)

func _refresh_dirty() -> void:
	var count := 0
	for category in SCHEMA.CATEGORIES:
		for entry: Resource in _database.entries(category):
			if entry != null and _dirty(entry):
				count += 1
	var changed := count > 0 or _membership != _membership_key()
	%Dirty.text = "%d changed · unsaved" % count if changed else "All changes saved"
	%Dirty.modulate = Color(0.95,0.75,0.4) if changed else Color(0.53,0.73,0.57)
	%Save.disabled = not changed

func _show_validation() -> void:
	var errors := SCHEMA.validate(_database)
	var count := 0
	for category in SCHEMA.CATEGORIES:
		count += _database.entries(category).size()
	%Validation.text = "Validation passed · %d definitions" % count if errors.is_empty() else "
".join(errors)
	%Validation.modulate = Color(0.53,0.73,0.57) if errors.is_empty() else Color(1,0.61,0.49)

func save_all() -> void:
	if _database == null or %Save.disabled:
		return
	var errors := SCHEMA.validate(_database)
	if not errors.is_empty():
		_show_validation()
		_status("Save blocked. Fix the validation errors below the table.",true)
		return
	for path: String in _disk_hashes:
		var current := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		if current != _disk_hashes[path]:
			_status("File changed outside this panel: "+path+". Reload before saving.",true)
			return
	var active: Array = []
	for category in SCHEMA.CATEGORIES:
		active.append_array(_database.entries(category))
	for entry: Resource in active:
		if not _dirty(entry) and FileAccess.file_exists(entry.resource_path):
			continue
		var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(entry.resource_path.get_base_dir()))
		if error != OK or ResourceSaver.save(entry,entry.resource_path) != OK:
			_status("Unable to save "+entry.resource_path,true)
			return
		_watch_path(entry.resource_path)
	if ResourceSaver.save(_database.construction,_database.construction.resource_path) != OK or ResourceSaver.save(_database,_database.resource_path) != OK:
		_status("Unable to save database catalogs.",true)
		return
	_watch_path(_database.resource_path)
	_watch_path(_database.construction.resource_path)
	for entry: Resource in _known:
		if entry not in active and FileAccess.file_exists(entry.resource_path):
			if DirAccess.remove_absolute(ProjectSettings.globalize_path(entry.resource_path)) != OK:
				_status("Catalog saved, but unable to delete "+entry.resource_path,true)
				return
			_watch_path(entry.resource_path)
	_baseline.clear()
	for entry: Resource in active:
		_baseline[entry] = SCHEMA.fingerprint(entry)
	_membership = _membership_key()
	EditorInterface.get_resource_filesystem().scan()
	_refresh_table()
	_status("Database saved. Start a new game to use the updated balance.")

func _status(message: String, error: bool = false) -> void:
	%Status.text = message
	%Status.modulate = Color(1,0.61,0.49) if error else Color(0.67,0.73,0.68)

func _undo() -> void:
	var history := _history.get_history_undo_redo(_history.get_object_history_id(_database))
	if history.has_undo():
		history.undo()

func _redo() -> void:
	var history := _history.get_history_undo_redo(_history.get_object_history_id(_database))
	if history.has_redo():
		history.redo()

func _open_recipe_dialog(discovery: DiscoveryDefinition) -> void:
	%RecipeDraft.configure(_database,null,discovery.id if discovery != null else &"")
	%RecipeDialog.get_ok_button().disabled = not %RecipeDraft.valid_selection
	%RecipeDialog.popup_centered()

func _on_recipe_validity_changed(valid: bool) -> void:
	%RecipeDialog.get_ok_button().disabled = not valid

func _create_recipe_from_dialog() -> void:
	if not %RecipeDraft.valid_selection:
		return
	var values: Array[StringName] = %RecipeDraft.values()
	var recipe := DiscoveryRecipe.new()
	recipe.first = values[0]
	recipe.second = values[1]
	recipe.result = values[2]
	_set_category("Recipes")
	_categories.select(SCHEMA.CATEGORIES.find("Recipes"))
	_register_new(recipe,str(recipe.result)+"_from_"+str(recipe.first)+"_and_"+str(recipe.second))

func _navigate_recipe(recipe: DiscoveryRecipe) -> void:
	_set_category("Recipes")
	_categories.select(SCHEMA.CATEGORIES.find("Recipes"))
	_table.deselect_all()
	_select_entry(recipe)
	_refresh_table()

func open_discovery_graph() -> void:
	%GraphMode.button_pressed = true
	_set_graph_mode(true)

func _set_graph_mode(active: bool) -> void:
	if active and _database != null and not (_selected is DiscoveryDefinition or _selected is DiscoveryRecipe) and not _database.discoveries.is_empty():
		_graph_selection(_database.discoveries[0])
	%Sidebar.visible = not active
	%DiscoveryGraph.visible = active
	%TablePanel.visible = not active
	%DiscoveryGraph.refresh()
	if active:
		%DiscoveryGraph._fit.call_deferred()

func _graph_selection(entry: Resource) -> void:
	if entry == null:
		return
	var category := "Recipes" if entry is DiscoveryRecipe else "Discoveries"
	if _category != category:
		_set_category(category)
	_table.deselect_all()
	_select_entry(entry)
	_refresh_table()

func _create_graph_discovery() -> void:
	_set_category("Discoveries")
	_create_entry()

func _create_graph_recipe() -> void:
	_set_category("Recipes")
	_register_new(DiscoveryRecipe.new(),"new_combination")
	_status("Connect two discoveries to A / B, then connect the recipe result to a discovery. Save All when the recipe is complete.")

func _ask_graph_remove(entries: Array) -> void:
	if entries.is_empty():
		return
	var category := "Recipes" if entries[0] is DiscoveryRecipe else "Discoveries"
	for entry: Resource in entries:
		if (entry is DiscoveryRecipe) != (category == "Recipes"):
			_status("Remove recipes and discoveries separately. Remove a discovery's recipes first.",true)
			return
		var uses := _usages(entry)
		if not uses.is_empty():
			_status("Cannot remove "+entry.display_name+": "+"; ".join(uses),true)
			return
	_set_category(category)
	_pending_remove = entries
	%RemoveDialog.dialog_text = "Remove %d entries from the catalog? Their files will be deleted when you save. This action supports Undo." % entries.size()
	%RemoveDialog.popup_centered()
