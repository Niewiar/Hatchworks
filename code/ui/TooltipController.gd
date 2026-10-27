class_name TooltipController
extends Control

@export var cursor_offset := Vector2(22, 16)
@export var screen_margin := 12.0

@onready var _text_tooltip: PanelContainer = $TextTooltip
@onready var _text_label: Label = $TextTooltip/Label

var _active_tooltip: Control

func _ready() -> void:
	set_process(false)

func show_text(text: String) -> void:
	_text_label.text = text
	show_tooltip(_text_tooltip)

func show_tooltip(content: Control) -> void:
	if _active_tooltip != null and _active_tooltip != content:
		_active_tooltip.hide()
	_active_tooltip = content
	_active_tooltip.show()
	_active_tooltip.reset_size()
	_position_tooltip()
	set_process(true)

func hide_tooltip(content: Control = null) -> void:
	if content != null and content != _active_tooltip:
		return
	if _active_tooltip != null:
		_active_tooltip.hide()
	_active_tooltip = null
	set_process(false)

func hide_text() -> void:
	hide_tooltip(_text_tooltip)

func _process(_delta: float) -> void:
	_position_tooltip()

func _position_tooltip() -> void:
	if not is_instance_valid(_active_tooltip):
		set_process(false)
		return
	var viewport_size := get_viewport_rect().size
	var mouse := get_viewport().get_mouse_position()
	var target := mouse + cursor_offset
	if target.x + _active_tooltip.size.x > viewport_size.x - screen_margin:
		target.x = mouse.x - cursor_offset.x - _active_tooltip.size.x
	var maximum := (viewport_size - _active_tooltip.size - Vector2.ONE * screen_margin).max(Vector2.ONE * screen_margin)
	_active_tooltip.position = target.clamp(Vector2.ONE * screen_margin, maximum)
