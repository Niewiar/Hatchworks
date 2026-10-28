class_name TooltipController
extends Control

@export var cursor_offset := Vector2(22, 16)
@export var screen_margin := 12.0
@export var button_gap := 12.0

@onready var _button_tooltip: PanelContainer = $ButtonTooltip
@onready var _button_label: Label = $ButtonTooltip/Label

var _active_tooltip: Control
var _anchor: WeakRef

func _ready() -> void:
	set_process(false)

func show_text(text: String, anchor: Control) -> void:
	_button_label.text = text
	show_tooltip(_button_tooltip, anchor)

func show_tooltip(content: Control, anchor: Control = null) -> void:
	if is_instance_valid(_active_tooltip) and _active_tooltip != content:
		_active_tooltip.hide()
	_anchor = weakref(anchor) if anchor != null else null
	_active_tooltip = content
	_active_tooltip.show()
	_active_tooltip.reset_size()
	_position_tooltip()
	set_process(_active_tooltip != null)

func hide_tooltip(content: Control = null) -> void:
	if content != null and content != _active_tooltip:
		return
	if is_instance_valid(_active_tooltip):
		_active_tooltip.hide()
	_active_tooltip = null
	_anchor = null
	set_process(false)

func hide_text(anchor: Control) -> void:
	if _anchor != null and _anchor.get_ref() == anchor:
		hide_tooltip(_button_tooltip)

func _process(_delta: float) -> void:
	_position_tooltip()

func _position_tooltip() -> void:
	if not is_instance_valid(_active_tooltip):
		_active_tooltip = null
		_anchor = null
		set_process(false)
		return
	var viewport_size := get_viewport_rect().size
	var target: Vector2
	if _anchor != null:
		var anchor := _anchor.get_ref() as Control
		if anchor == null or not anchor.is_visible_in_tree():
			hide_tooltip()
			return
		var anchor_rect := get_global_transform().affine_inverse() * anchor.get_global_rect()
		target = Vector2(anchor_rect.get_center().x - _active_tooltip.size.x * 0.5, anchor_rect.position.y - _active_tooltip.size.y - button_gap)
	else:
		var mouse := get_local_mouse_position()
		target = mouse + cursor_offset
		if target.x + _active_tooltip.size.x > viewport_size.x - screen_margin:
			target.x = mouse.x - cursor_offset.x - _active_tooltip.size.x
	var maximum := (viewport_size - _active_tooltip.size - Vector2.ONE * screen_margin).max(Vector2.ONE * screen_margin)
	_active_tooltip.position = target.clamp(Vector2.ONE * screen_margin, maximum)
