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
	map_manager.discoveries.discovered.connect(_on_discovered)
	for entry: DiscoveryDefinition in map_manager.database.discoveries:
		if map_manager.discoveries.knows(entry.id) and map_manager.discoveries.is_unread(entry.id):
			_on_discovered(entry)

func _on_discovered(entry: DiscoveryDefinition) -> void:
	if map_manager.current_mode() != MapManager.MODE.DISCOVERIES:
		_add(tr("New discovery"),entry.display_name,entry.icon,MapManager.MODE.DISCOVERIES,func(): return {"title":tr("New discovery"),"message":entry.display_name})

func _add(title: String, message: String, icon: Texture2D, mode: MapManager.MODE, render_content: Callable = Callable()) -> void:
	while _cards.size() >= maximum_notifications:
		_dismiss(_cards[0])
	var card := CARD.instantiate() as GameNotification
	card.configure(title,message,icon,mode,render_content)
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
	_dismiss(card)
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
	visible = _can_show()

func _scroll_to_latest() -> void:
	if not _cards.is_empty():
		%Scroll.ensure_control_visible(_cards.back())

func _sync_visibility() -> void:
	var pending := not _cards.is_empty()
	%Scroll.visible = pending
	visible = pending and _can_show()
	set_process(pending)

func _on_mode_changed(mode: MapManager.MODE) -> void:
	for card in _cards.duplicate():
		if card.target_mode == mode:
			_dismiss(card)

func _can_show() -> bool:
	return not map_manager.inspection_panel.focused and (not map_manager.modal_active or map_manager.current_mode() in [MapManager.MODE.DISCOVERIES,MapManager.MODE.BACKPACK])
