class_name TooltipController
extends Control

@export var cursor_offset := Vector2(22,16)
@export var screen_margin := 12.0
@export var button_gap := 12.0

var _active_tooltip: MarginContainer
var _anchor: WeakRef
var _cursor_hint := false

func _ready() -> void:
	set_process(false)

func show_text(text: String, anchor: Control) -> void:
	$ButtonTooltip/Panel/Label.text = text
	_cursor_hint = false
	_show($ButtonTooltip,anchor)

func show_hint(text: String, source: Control) -> void:
	$HintTooltip/Panel/Label.text = text
	_cursor_hint = true
	_show($HintTooltip,source)

func _show(content: MarginContainer, anchor: Control) -> void:
	if is_instance_valid(_active_tooltip) and _active_tooltip != content:
		_active_tooltip.hide()
	_anchor = weakref(anchor) if anchor != null else null
	_active_tooltip = content
	_active_tooltip.show()
	_position_tooltip()
	set_process(true)

func hide_tooltip() -> void:
	if is_instance_valid(_active_tooltip):
		_active_tooltip.hide()
	_active_tooltip = null
	_anchor = null
	set_process(false)

func hide_text(anchor: Control) -> void:
	if _anchor != null and _anchor.get_ref() == anchor:
		hide_tooltip()

func _process(_delta: float) -> void:
	_position_tooltip()

func _position_tooltip() -> void:
	if not is_instance_valid(_active_tooltip):
		hide_tooltip()
		return
	var anchor := _anchor.get_ref() as Control if _anchor != null else null
	if _anchor != null and (anchor == null or not anchor.is_visible_in_tree()):
		hide_tooltip()
		return
	var extent: Vector2 = _active_tooltip.get_node("Panel").size
	var viewport_size := get_viewport_rect().size
	var target: Vector2
	if anchor != null and not _cursor_hint:
		var bounds := get_global_transform().affine_inverse()*anchor.get_global_rect()
		target = Vector2(bounds.get_center().x-extent.x*0.5,bounds.position.y-extent.y-button_gap)
	else:
		var mouse := get_local_mouse_position()
		target = mouse+cursor_offset
		if target.x+extent.x > viewport_size.x-screen_margin:
			target.x = mouse.x-cursor_offset.x-extent.x
	var maximum := (viewport_size-extent-Vector2.ONE*screen_margin).max(Vector2.ONE*screen_margin)
	_active_tooltip.position = target.clamp(Vector2.ONE*screen_margin,maximum)
