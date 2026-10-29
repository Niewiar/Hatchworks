class_name DiscoveryToken
extends PanelContainer

signal remove_requested(token: DiscoveryToken)
signal drag_started(token: DiscoveryToken, offset: Vector2)

var entry: DiscoveryDefinition
var in_workspace := false
var draggable := true

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
	if draggable and entry != null and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		drag_started.emit(self,event.position)
		accept_event()
