extends Node

signal on_lmb(pressed: bool)
signal on_mmb(pressed: bool)
signal on_rmb(pressed: bool)
signal on_mouse_move(position: Vector2)
signal on_mouse_scroll(direction: int)
signal on_camera_move(direction: Vector2)
signal on_camera_turn(direction: float)
signal on_esc()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_ESCAPE:
		on_esc.emit()
		return
	if get_tree().paused:
		return
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
		var left := Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
		var right := Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
		var forward := Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
		var back := Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
		on_camera_move.emit(Vector2(int(right)-int(left),int(back)-int(forward)).limit_length())
		on_camera_turn.emit(float(int(Input.is_physical_key_pressed(KEY_E))-int(Input.is_physical_key_pressed(KEY_Q))))
