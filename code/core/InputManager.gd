extends Node

signal on_lmb(pressed: bool)
signal on_mmb(pressed: bool)
signal on_rmb(pressed: bool)
signal on_mouse_move(position: Vector2)
signal on_mouse_scroll(direction: int)
signal on_esc()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			on_lmb.emit(button.pressed)
		elif button.button_index == MOUSE_BUTTON_MIDDLE:
			on_mmb.emit(button.pressed)
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			on_rmb.emit(button.pressed)
		elif button.pressed:
			if button.button_index == MOUSE_BUTTON_WHEEL_UP:
				on_mouse_scroll.emit(1)
			elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				on_mouse_scroll.emit(-1)
	elif event is InputEventMouseMotion:
		on_mouse_move.emit(event.position)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.is_echo():
			if key.keycode == KEY_ESCAPE:
				on_esc.emit()
