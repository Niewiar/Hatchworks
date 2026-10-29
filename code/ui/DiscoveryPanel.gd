class_name DiscoveryPanel
extends Control

@export var map_manager: MapManager
@export var tooltip_controller: TooltipController

const TOKEN = preload("res://scenes/ui/discovery_token.tscn")
var _drag_source: DiscoveryToken
var _drag_entry: DiscoveryDefinition
var _drag_offset := Vector2.ZERO

func _ready() -> void:
	hide()
	%Clear.pressed.connect(_clear_workspace)
	%Tabs.tab_changed.connect(func(_index): _cancel_drag())
	map_manager.discoveries.seen.connect(_on_seen)
	%Search.text_changed.connect(func(_text): _refresh_catalog())
	%ArchiveSearch.text_changed.connect(func(_text): _refresh_catalog())
	map_manager.mode_changed.connect(_mode_changed)
	map_manager.discoveries.discovered.connect(func(_entry): _refresh_catalog.call_deferred())
	%Workspace.resized.connect(_clamp_tokens)
	get_window().focus_exited.connect(_cancel_drag)

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
	var count := 0
	for entry: DiscoveryDefinition in map_manager.database.discoveries:
		if not map_manager.discoveries.knows(entry.id):
			continue
		count += 1
		if %Search.text.is_empty() or entry.display_name.to_lower().contains(%Search.text.to_lower()):
			%Catalog.add_child(_make_token(entry,false))
		if %ArchiveSearch.text.is_empty() or entry.display_name.to_lower().contains(%ArchiveSearch.text.to_lower()):
			var archived := _make_token(entry,false)
			archived.draggable = false
			archived.mouse_default_cursor_shape = Control.CURSOR_ARROW
			%Archive.add_child(archived)
	%Count.text = "%d %s" % [count,"discovery" if count == 1 else "discoveries"]
	var lines := PackedStringArray()
	for recipe: DiscoveryRecipe in map_manager.database.recipes:
		if map_manager.discoveries.recipe_known(recipe.id):
			lines.append("%s + %s → %s" % [map_manager.database.discovery(recipe.first).display_name,map_manager.database.discovery(recipe.second).display_name,map_manager.database.discovery(recipe.result).display_name])
	%Recipes.text = "\n\n".join(lines) if not lines.is_empty() else "Known combinations appear here."

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
	var entry := _drag_entry
	var source: DiscoveryToken = _drag_source if is_instance_valid(_drag_source) else null
	var offset := _drag_offset
	_cancel_drag()
	var pointer := get_canvas_transform().affine_inverse()*viewport_position
	if entry == null or not visible or not %Workspace.get_global_rect().has_point(pointer):
		return
	var point: Vector2 = %Workspace.get_global_transform().affine_inverse()*pointer
	var tokens := %Workspace.get_children()
	tokens.reverse()
	for token: DiscoveryToken in tokens:
		if token != source and token.get_rect().has_point(point):
			_combine_tokens({"discovery":entry.id,"source":source},token)
			return
	_drop_token(entry.id,source,point-%Workspace.get_global_transform().basis_xform_inv(offset))

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
	var first: StringName = data.discovery
	var second := target.entry.id
	var known_before: Dictionary[StringName, bool] = {}
	for entry in map_manager.database.discoveries:
		known_before[entry.id] = map_manager.discoveries.knows(entry.id)
	var result := map_manager.discoveries.combine(first,second)
	if result.is_empty():
		%Outcome.text = "Nothing discovered. Try a different combination."
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
	%Outcome.text = "%s + %s → %s" % [map_manager.database.discovery(first).display_name,map_manager.database.discovery(second).display_name,map_manager.database.discovery(result).display_name]
	var entry := map_manager.database.discovery(result)
	if not known_before.get(result,false):
		%Outcome.text = "New discovery! "+%Outcome.text
		if entry.reward_count > 0:
			%Outcome.text += " · +%d %s added to inventory" % [entry.reward_count,"egg" if map_manager.database.egg(entry.reward_item) != null else "construction kit"]
	elif entry.reward_count > 0:
		%Outcome.text += " · Already known; no extra item reward"
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
