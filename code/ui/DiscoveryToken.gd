class_name DiscoveryToken
extends PanelContainer

signal remove_requested(token: DiscoveryToken)
signal drag_started(token: DiscoveryToken, offset: Vector2)
signal selected(token: DiscoveryToken)

var entry: DiscoveryDefinition
var in_workspace := false
var draggable := true
var _default_style: StyleBox

func configure(data: DiscoveryDefinition, unread: bool = false) -> void:
	entry = data
	$Row/Icon.texture = data.icon
	$Row/Name.text = data.display_name
	set_unread(unread)

func set_unread(value: bool) -> void:
	$Row/New.visible = value

func _gui_input(event: InputEvent) -> void:
	if in_workspace and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		remove_requested.emit(self)
		accept_event()
		return
	if not draggable and entry != null and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(self)
		accept_event()
		return
	if draggable and entry != null and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		drag_started.emit(self,event.position)
		accept_event()

func set_selected(value: bool) -> void:
	if _default_style == null:
		_default_style = get_theme_stylebox("panel")
	if value:
		add_theme_stylebox_override("panel",get_theme_stylebox("selected"))
	else:
		add_theme_stylebox_override("panel",_default_style)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and entry != null:
		$Row/Name.text = entry.display_name
