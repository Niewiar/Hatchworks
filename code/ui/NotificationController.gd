class_name NotificationController
extends Control

@export var map_manager: MapManager
@export var tooltip_controller: TooltipController
@export_range(1,10,1) var maximum_notifications := 10

const CARD = preload("res://scenes/ui/game_notification.tscn")
var _cards: Array[GameNotification] = []

func _ready() -> void:
	%Stack.sort_children.connect(_scroll_to_latest,CONNECT_DEFERRED)
	%Scroll.sort_children.connect(_scroll_to_latest,CONNECT_DEFERRED)
	_sync_visibility()
	map_manager.mode_changed.connect(_on_mode_changed)
	map_manager.modal_changed.connect(func(_active): _sync_visibility())
	map_manager.discoveries.discovered.connect(_on_discovered)
	map_manager.building_controller.building_attacked.connect(_on_building_attacked)
	GameManager.pause_changed.connect(_on_pause_changed)
	for entry: DiscoveryDefinition in map_manager.database.discoveries:
		if map_manager.discoveries.knows(entry.id) and map_manager.discoveries.is_unread(entry.id):
			_on_discovered(entry)

func _on_discovered(entry: DiscoveryDefinition) -> void:
	if map_manager.current_mode() != MapManager.MODE.DISCOVERIES:
		_add(tr("New discovery"),entry.display_name,entry.icon,MapManager.MODE.DISCOVERIES,func(): return {"title":tr("New discovery"),"message":entry.display_name})

func _on_building_attacked(building: Node3D, attacker: Creature, _damage: float) -> void:
	if not is_instance_valid(building) or not is_instance_valid(attacker):
		return
	var data := map_manager.building_controller.building_definition(building)
	var species := attacker.species_data()
	if data == null or species == null:
		return
	var render := _attack_content.bind(data,species)
	var content: Dictionary = render.call()
	var activate := _show_attack.bind(weakref(building),_world_bounds(building),weakref(attacker),_world_bounds(attacker))
	_add(content.title,content.message,data.icon,-1,render,activate)

func _attack_content(building: BuildingDefinition, species: CreatureSpecies) -> Dictionary:
	return {"title":tr("Building attacked"),"message":tr("%s is attacking %s") % [species.display_name,building.display_name]}

func _show_attack(building: WeakRef, building_bounds: AABB, attacker: WeakRef, attacker_bounds: AABB) -> void:
	if not is_instance_valid(map_manager) or not map_manager.is_inside_tree():
		return
	var bounds := _live_bounds(building,building_bounds).merge(_live_bounds(attacker,attacker_bounds))
	map_manager.frame_area(bounds)

func _live_bounds(reference: WeakRef, fallback: AABB) -> AABB:
	var actor := reference.get_ref() as Node3D
	if is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.is_inside_tree() and actor.get_viewport() == get_viewport() and map_manager.get_parent().is_ancestor_of(actor):
		return _world_bounds(actor)
	return fallback

func _world_bounds(actor: Node3D) -> AABB:
	var local: AABB = actor.inspection_bounds()
	return actor.global_transform*local

func _add(title: String, message: String, icon: Texture2D, mode: int, render_content: Callable = Callable(), activate: Callable = Callable()) -> void:
	while _cards.size() >= maximum_notifications:
		_dismiss(_cards[0])
	var card := CARD.instantiate() as GameNotification
	card.configure(title,message,icon,mode,render_content,activate)
	card.activated.connect(_activate)
	card.dismissed.connect(_dismiss)
	%Stack.add_child(card)
	_cards.append(card)
	var close: Button = card.get_node("%Close")
	close.mouse_entered.connect(func(): tooltip_controller.show_text(tr("Dismiss notification"),close))
	close.mouse_exited.connect(tooltip_controller.hide_text.bind(close))
	_sync_visibility()

func _activate(card: GameNotification) -> void:
	var mode := card.target_mode
	var action := card.action
	_dismiss(card)
	if action.is_valid():
		action.call()
	elif mode >= 0:
		map_manager.set_mode(mode)

func _dismiss(card: GameNotification) -> void:
	if not is_instance_valid(card) or not _cards.has(card):
		return
	tooltip_controller.hide_text(card.get_node("%Close"))
	_cards.erase(card)
	%Stack.remove_child(card)
	card.queue_free()
	_sync_visibility()

func _process(_delta: float) -> void:
	_sync_visibility()

func _scroll_to_latest() -> void:
	for index in range(_cards.size()-1,-1,-1):
		if _cards[index].is_visible_in_tree():
			%Scroll.ensure_control_visible(_cards[index])
			return

func _sync_visibility() -> void:
	var focused := map_manager.inspection_panel != null and map_manager.inspection_panel.focused
	var pending := false
	for card in _cards:
		card.visible = card.target_mode < 0 or not focused
		pending = pending or card.visible
	%Scroll.visible = pending
	visible = pending and _can_show()
	set_process(not _cards.is_empty())

func _on_mode_changed(mode: MapManager.MODE) -> void:
	for card in _cards.duplicate():
		if card.target_mode >= 0 and card.target_mode == mode:
			_dismiss(card)
	_sync_visibility()

func _on_pause_changed(paused: bool) -> void:
	if paused:
		hide()
	else:
		_sync_visibility()

func _can_show() -> bool:
	if get_tree().paused or (map_manager.hatch_presentation != null and map_manager.hatch_presentation.is_visible_in_tree()):
		return false
	return not map_manager.modal_active or map_manager.current_mode() in [MapManager.MODE.DISCOVERIES,MapManager.MODE.BACKPACK]
