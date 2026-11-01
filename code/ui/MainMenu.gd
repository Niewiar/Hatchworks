extends Control

var _starting := false

func _ready() -> void:
	%Continue.disabled = not SaveGame.has_save()
	%Continue.pressed.connect(_start.bind(false))
	%NewGame.pressed.connect(_new_game)
	%Options.pressed.connect(_show_options)
	%Back.pressed.connect(_show_main)
	%Cancel.pressed.connect(_show_main)
	%ConfirmNewGame.pressed.connect(_start.bind(true))
	%Quit.pressed.connect(GameManager.quit_game)
	%Music.set_value_no_signal(Localization.music_volume())
	%Sound.set_value_no_signal(Localization.sound_volume())
	%Music.value_changed.connect(Localization.set_music_volume)
	%Sound.value_changed.connect(Localization.set_sound_volume)
	%Language.item_selected.connect(_select_language)
	Localization.language_changed.connect(_refresh_language)
	InputManager.on_esc.connect(_show_main)
	_refresh_language()
	_show_main()
	if not GameManager.start_error.is_empty():
		_show_start_error(GameManager.start_error)

func _show_main() -> void:
	if _starting:
		return
	%Main.show()
	%Settings.hide()
	%Confirmation.hide()
	if %Continue.disabled:
		%NewGame.grab_focus()
	else:
		%Continue.grab_focus()

func _show_options() -> void:
	%Main.hide()
	%Settings.show()
	%Music.grab_focus()

func _new_game() -> void:
	if not SaveGame.has_save():
		_start(true)
		return
	%Main.hide()
	%Confirmation.show()
	%Cancel.grab_focus()

func _start(new_game: bool) -> void:
	if _starting:
		return
	_starting = true
	var error: Error = GameManager.start_game(new_game)
	if error == OK:
		return
	_starting = false
	_show_start_error(GameManager.start_error if not GameManager.start_error.is_empty() else error_string(error))
	%Continue.disabled = not SaveGame.has_save()
	_show_main()

func _show_start_error(message: String) -> void:
	%Status.text = tr("Could not start the game: %s") % message
	%Status.show()

func _select_language(index: int) -> void:
	Localization.set_language("en" if index == 0 else "pl")

func _refresh_language() -> void:
	%Language.select(1 if Localization.language() == "pl" else 0)
