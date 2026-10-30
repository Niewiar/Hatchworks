class_name DiscoveryPanel
extends Control

@export var map_manager: MapManager
@export var tooltip_controller: TooltipController

const TOKEN = preload("res://scenes/ui/discovery_token.tscn")
const RECIPE_ROW = preload("res://scenes/ui/discovery_recipe_row.tscn")
var _selected_id: StringName
var _drag_source: DiscoveryToken
var _drag_entry: DiscoveryDefinition
var _drag_offset := Vector2.ZERO

func _ready() -> void:
	hide()
	%Clear.pressed.connect(_clear_workspace)
	for picker: OptionButton in [%Category,%ArchiveCategory,%Sort,%ArchiveSort]:
		picker.item_selected.connect(func(_index): _refresh_catalog())
	%Tabs.tab_changed.connect(func(_index): _cancel_drag())
	map_manager.discoveries.seen.connect(_on_seen)
	%Search.text_changed.connect(func(_text): _refresh_catalog())
	%ArchiveSearch.text_changed.connect(func(_text): _refresh_catalog())
	map_manager.mode_changed.connect(_mode_changed)
	map_manager.discoveries.discovered.connect(func(_entry): _refresh_catalog.call_deferred())
	map_manager.discoveries.combined.connect(func(_a,_b,_c,_new): _refresh_catalog.call_deferred())
	%Workspace.resized.connect(_clamp_tokens)
	get_window().focus_exited.connect(_cancel_drag)
	get_node("/root/GameManager").connect("pause_changed",_on_pause_changed)

func _clamp_tokens() -> void:
	for token: DiscoveryToken in %Workspace.get_children():
		token.position = _clamp_position(token.position,token.size)

func _mode_changed(mode: MapManager.MODE) -> void:
	_cancel_drag()
	visible = mode == MapManager.MODE.DISCOVERIES
	if visible:
		_refresh_catalog()
	else:
		tooltip_controller.hide_tooltip()

func _refresh_catalog() -> void:
	for catalog in [%Catalog,%Archive]:
		for child in catalog.get_children():
			catalog.remove_child(child)
			child.queue_free()
	for entry: DiscoveryDefinition in _filtered_entries(%Search,%Category,%Sort):
		%Catalog.add_child(_make_token(entry,false))
	for entry: DiscoveryDefinition in _filtered_entries(%ArchiveSearch,%ArchiveCategory,%ArchiveSort):
		var archived := _make_token(entry,false)
		archived.draggable = false
		archived.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		archived.selected.connect(_select_archive)
		archived.set_selected(entry.id == _selected_id)
		%Archive.add_child(archived)
	var count := map_manager.discoveries.known_entries().size()
	%Count.text = tr("Discoveries: %d") % count
	var entries := _filtered_entries(%ArchiveSearch,%ArchiveCategory,%ArchiveSort)
	if not entries.any(func(entry): return entry.id == _selected_id):
		_selected_id = entries[0].id if not entries.is_empty() else &""
	_refresh_recipe_details()

func _filtered_entries(search: LineEdit, category: OptionButton, sorting: OptionButton) -> Array[DiscoveryDefinition]:
	var result: Array[DiscoveryDefinition] = []
	var query := search.text.strip_edges().to_lower()
	for entry: DiscoveryDefinition in map_manager.discoveries.known_entries():
		if category.selected > 0 and entry.category != category.selected-1:
			continue
		if not query.is_empty() and not entry.display_name.to_lower().contains(query):
			continue
		result.append(entry)
	if sorting.selected == 2:
		result.reverse()
	else:
		result.sort_custom(func(first: DiscoveryDefinition, second: DiscoveryDefinition):
			if sorting.selected == 1 and first.category != second.category:
				return first.category < second.category
			return first.display_name.naturalnocasecmp_to(second.display_name) < 0)
	return result

func _make_token(entry: DiscoveryDefinition, on_board: bool) -> DiscoveryToken:
	var token := TOKEN.instantiate() as DiscoveryToken
	token.configure(entry,map_manager.discoveries.is_unread(entry.id))
	token.in_workspace = on_board
	token.drag_started.connect(_begin_drag)
	token.remove_requested.connect(_remove_token)
	token.mouse_entered.connect(map_manager.discoveries.mark_seen.bind(entry.id))
	return token

func _on_seen(id: StringName) -> void:
	for container in [%Catalog,%Archive,%Workspace]:
		for token: DiscoveryToken in container.get_children():
			if token.entry.id == id:
				token.set_unread(false)
	if %DragPreview.entry != null and %DragPreview.entry.id == id:
		%DragPreview.set_unread(false)

func _begin_drag(token: DiscoveryToken, offset: Vector2) -> void:
	if not visible:
		return
	_cancel_drag()
	_drag_source = token
	_drag_entry = token.entry
	_drag_offset = token.get_global_transform().basis_xform(offset)
	%DragPreview.configure(_drag_entry,false)
	if token.in_workspace:
		token.hide()
	tooltip_controller.hide_tooltip()
	%DragPreview.show()
	_update_drag(token.get_global_transform_with_canvas()*offset)

func _input(event: InputEvent) -> void:
	if _drag_entry == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var source: DiscoveryToken = _drag_source if is_instance_valid(_drag_source) else null
		_cancel_drag()
		if source != null and source.in_workspace:
			_remove_token(source)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_update_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(event.position)
		get_viewport().set_input_as_handled()

func _update_drag(viewport_position: Vector2) -> void:
	var point := get_canvas_transform().affine_inverse()*viewport_position
	%DragPreview.global_position = point-_drag_offset

func _finish_drag(viewport_position: Vector2) -> void:
	_update_drag(viewport_position)
	var entry := _drag_entry
	var source: DiscoveryToken = _drag_source if is_instance_valid(_drag_source) else null
	var drag_rect: Rect2 = %DragPreview.get_global_rect()
	_cancel_drag()
	var board_rect: Rect2 = %Workspace.get_global_rect()
	if entry == null or not visible or not board_rect.intersects(drag_rect):
		return
	var best: DiscoveryToken
	var best_area := 0.0
	var tokens := %Workspace.get_children()
	tokens.reverse()
	for token: DiscoveryToken in tokens:
		if token == source:
			continue
		var overlap := drag_rect.intersection(token.get_global_rect()).intersection(board_rect)
		var area := overlap.get_area()
		if area > best_area:
			best_area = area
			best = token
	if best != null:
		_combine_tokens({"discovery":entry.id,"source":source},best)
		return
	_drop_token(entry.id,source,%Workspace.get_global_transform().affine_inverse()*drag_rect.position)

func _cancel_drag() -> void:
	if is_instance_valid(_drag_source):
		_drag_source.show()
	_drag_source = null
	_drag_entry = null
	%DragPreview.hide()

func _drop_token(id: StringName, source: Control, point: Vector2) -> void:
	var entry := map_manager.database.discovery(id)
	if entry == null or not map_manager.discoveries.knows(id):
		return
	if is_instance_valid(source) and source.get_parent() == %Workspace:
		source.position = _clamp_position(point,source.size)
		return
	var token := _make_token(entry,true)
	%Workspace.add_child(token)
	token.position = _clamp_position(point,token.get_combined_minimum_size())

func _clamp_position(point: Vector2, token_size: Vector2) -> Vector2:
	return point.clamp(Vector2(8,8),(%Workspace.size-token_size-Vector2(8,8)).max(Vector2(8,8)))

func _combine_tokens(data: Dictionary, target: DiscoveryToken) -> void:
	var result := map_manager.discoveries.combine(data.discovery,target.entry.id,target.get_global_rect().get_center())
	if result.is_empty():
		return
	var point := target.position
	var source: Control = data.get("source")
	tooltip_controller.hide_tooltip()
	%Workspace.remove_child(target)
	target.queue_free()
	if is_instance_valid(source) and source != target and source.get_parent() == %Workspace:
		%Workspace.remove_child(source)
		source.queue_free()
	_drop_token(result,null,point)
	_refresh_catalog.call_deferred()

func _clear_workspace() -> void:
	_cancel_drag()
	tooltip_controller.hide_tooltip()
	for child in %Workspace.get_children():
		%Workspace.remove_child(child)
		child.queue_free()


func _remove_token(token: DiscoveryToken) -> void:
	if not is_instance_valid(token) or token.get_parent() != %Workspace:
		return
	if token == _drag_source:
		_cancel_drag()
	tooltip_controller.hide_tooltip()
	%Workspace.remove_child(token)
	token.queue_free()

func _select_archive(token: DiscoveryToken) -> void:
	_selected_id = token.entry.id
	_refresh_recipe_details()

func _refresh_recipe_details() -> void:
	for child in %Recipes.get_children():
		%Recipes.remove_child(child)
		child.queue_free()
	for token: DiscoveryToken in %Archive.get_children():
		token.set_selected(token.entry.id == _selected_id)
	var entry := map_manager.database.discovery(_selected_id)
	%DetailContent.visible = entry != null
	%DetailEmpty.visible = entry == null
	if entry == null:
		return
	%DetailName.text = tr(entry.display_name)
	%DetailIcon.texture = entry.icon
	var matching: Array[DiscoveryRecipe] = []
	for recipe: DiscoveryRecipe in map_manager.database.recipes:
		if entry.id in [recipe.first,recipe.second,recipe.result]:
			matching.append(recipe)
	var known := 0
	for discovered in [false,true]:
		for recipe in matching:
			if map_manager.discoveries.recipe_known(recipe.id) != discovered:
				continue
			if discovered:
				known += 1
			var row := RECIPE_ROW.instantiate()
			%Recipes.add_child(row)
			var visible_part := 2 if recipe.result == entry.id else (0 if recipe.first == entry.id else 1)
			row.configure(map_manager.database,recipe,discovered,visible_part)
	%DetailCount.text = tr("%d / %d combinations discovered") % [known,matching.size()]

func owns_secondary_action() -> bool:
	if not visible:
		return false
	if _drag_entry != null:
		return true
	var control := get_viewport().gui_get_hovered_control()
	while control != null:
		if control is DiscoveryToken and control.in_workspace and %Workspace.is_ancestor_of(control):
			return true
		control = control.get_parent() as Control
	return false

func capture_workspace() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for token: DiscoveryToken in %Workspace.get_children():
		result.append({"id":token.entry.id,"position":token.position})
	return result

func restore_workspace(values: Array) -> void:
	_clear_workspace()
	for value in values:
		if value is Dictionary and value.get("id") is StringName and value.get("position") is Vector2:
			_drop_token(value.id,null,value.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_cancel_drag()
		_refresh_catalog.call_deferred()
		for token: DiscoveryToken in %Workspace.get_children():
			token.configure(token.entry,map_manager.discoveries.is_unread(token.entry.id))

func _on_pause_changed(paused: bool) -> void:
	if paused:
		_cancel_drag()
