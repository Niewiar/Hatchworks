class_name GameNotification
extends PanelContainer

signal activated(notification: GameNotification)
signal dismissed(notification: GameNotification)

var target_mode := -1
var action: Callable
var _render_content: Callable

func _ready() -> void:
	%Hit.pressed.connect(func(): activated.emit(self))
	%Close.pressed.connect(func(): dismissed.emit(self))
	%Expiry.timeout.connect(func(): dismissed.emit(self))
	visibility_changed.connect(_sync_clock)
	%Lifetime.max_value = %Expiry.wait_time
	%Lifetime.value = %Expiry.wait_time
	%Expiry.start()
	_sync_clock()

func configure(title: String, message: String, icon: Texture2D, mode: int, render_content: Callable = Callable(), activate: Callable = Callable()) -> void:
	_render_content = render_content
	action = activate
	target_mode = mode
	%Title.text = title
	%Message.text = message
	%Icon.texture = icon

func _process(_delta: float) -> void:
	%Lifetime.value = %Expiry.time_left

func _sync_clock() -> void:
	var shown := is_visible_in_tree()
	%Expiry.paused = not shown
	set_process(shown)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _render_content.is_valid():
		var content: Dictionary = _render_content.call()
		%Title.text = content.title
		%Message.text = content.message
