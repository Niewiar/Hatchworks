extends Node

signal pause_changed(paused: bool)

var _menu: Control
var _map: MapManager
var _previous_modal := false
var _busy := false
var _skip_load_once := false
var _presentation_mode := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputManager.on_esc.connect(_on_esc)
	get_tree().auto_accept_quit = false

func attach_game(menu: Control, map: MapManager) -> void:
	_menu = menu
	_map = map
	_start_session.call_deferred()

func _start_session() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_map) or not is_instance_valid(_menu):
		return
	if _skip_load_once:
		_skip_load_once = false
		return
	if not SaveGame.has_save():
		return
	_busy = true
	_previous_modal = _map.modal_active
	_map.set_modal(true)
	get_tree().paused = true
	var error: int = await SaveGame.load_game(_map)
	get_tree().paused = false
	_map.set_modal(_previous_modal)
	_busy = false
	if error != OK:
		open_menu()
		_menu.show_status("Could not load save: %s", SaveGame.last_error, true)
	elif not SaveGame.last_error.is_empty():
		open_menu()
		_menu.show_status(SaveGame.last_error)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()

func _on_esc() -> void:
	if _busy or not is_instance_valid(_menu):
		return
	if _menu.visible:
		if not _menu.cancel_confirmation():
			resume_game()
	else:
		open_menu()

func open_menu() -> void:
	if _busy or not is_instance_valid(_map) or not is_instance_valid(_menu) or _menu.visible:
		return
	_previous_modal = _map.modal_active
	_map.set_modal(true)
	var tips := _menu.get_parent().get_node_or_null("TooltipController")
	if tips != null:
		tips.hide_tooltip()
	var presentation := _map.hatch_presentation
	if presentation != null and presentation.visible and is_instance_valid(presentation._animation):
		_presentation_mode = presentation._animation.process_mode
		presentation._animation.process_mode = Node.PROCESS_MODE_PAUSABLE
	pause_changed.emit(true)
	get_tree().paused = true
	_menu.open_menu()

func resume_game() -> void:
	if _busy or not is_instance_valid(_menu):
		return
	_menu.close_menu()
	if is_instance_valid(_map):
		var presentation := _map.hatch_presentation
		if _presentation_mode >= 0 and presentation != null and is_instance_valid(presentation._animation):
			presentation._animation.process_mode = _presentation_mode
		_map.set_modal(_previous_modal)
	_presentation_mode = -1
	get_tree().paused = false
	pause_changed.emit(false)

func save_game() -> int:
	if _busy or not is_instance_valid(_map):
		return ERR_BUSY
	_busy = true
	_menu.set_busy(true)
	var error: int = SaveGame.save_game(_map)
	_menu.set_busy(false)
	_busy = false
	_menu.show_status("Game saved." if error == OK else "Saving failed: %s", "" if error == OK else SaveGame.last_error, error != OK)
	return error

func reset_game() -> void:
	if _busy:
		return
	var error: int = SaveGame.reset_save()
	if error != OK:
		_menu.show_status("Saving failed: %s", SaveGame.last_error, true)
		return
	_skip_load_once = true
	get_tree().paused = false
	pause_changed.emit(false)
	_menu.hide()
	var reload_error := get_tree().reload_current_scene()
	if reload_error != OK:
		_skip_load_once = false
		open_menu()
		_menu.show_status("Could not start a new world: %s", error_string(reload_error), true)

func request_quit() -> void:
	if _busy:
		return
	if not is_instance_valid(_menu):
		quit_game(false)
		return
	open_menu()
	_menu.confirm_quit()

func quit_game(save_first: bool) -> void:
	if _busy:
		return
	if save_first and save_game() != OK:
		return
	_busy = true
	if is_instance_valid(_menu):
		_menu.set_busy(true)
	var music := get_node_or_null("/root/Music") as AudioStreamPlayer
	if music != null:
		music.stop()
	await get_tree().create_timer(0.04,true).timeout
	get_tree().quit()
