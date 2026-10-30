class_name GameMenu
extends Control

@export var map_manager: MapManager

var _status_key := ""
var _status_detail := ""
var _status_error := false
var _confirmation_kind := 0

func _ready() -> void:
	hide()
	%Resume.pressed.connect(GameManager.resume_game)
	%Save.pressed.connect(GameManager.save_game)
	%Reset.pressed.connect(_confirm_reset)
	%Quit.pressed.connect(GameManager.request_quit)
	%Language.item_selected.connect(_select_language)
	%Music.value_changed.connect(_set_music)
	%Sound.value_changed.connect(Localization.set_sound_volume)
	%ConfirmReset.pressed.connect(GameManager.reset_game)
	%SaveQuit.pressed.connect(GameManager.quit_game.bind(true))
	%QuitWithoutSaving.pressed.connect(GameManager.quit_game.bind(false))
	%Cancel.pressed.connect(cancel_confirmation)
	Localization.language_changed.connect(_refresh_language)
	%Music.set_value_no_signal(Localization.music_volume())
	%Sound.set_value_no_signal(Localization.sound_volume())
	_refresh_language()
	GameManager.attach_game(self, map_manager)

func open_menu() -> void:
	%Main.show()
	%Confirmation.hide()
	show()
	%Resume.grab_focus()

func close_menu() -> void:
	hide()
	_status_key = ""
	%Status.hide()

func set_busy(busy: bool) -> void:
	for control in [%Resume, %Save, %Reset, %Quit, %Language, %ConfirmReset, %SaveQuit, %QuitWithoutSaving, %Cancel]:
		control.disabled = busy

func show_status(key: String, detail: String = "", failure: bool = false) -> void:
	_status_key = key
	_status_detail = detail
	_status_error = failure
	_refresh_status()

func _refresh_status() -> void:
	%Status.visible = not _status_key.is_empty()
	%Status.text = tr(_status_key) % tr(_status_detail) if _status_key.contains("%s") else tr(_status_key)
	%Status.modulate = Color(1.0,0.54,0.47) if _status_error else Color(0.77,0.88,0.60)

func _select_language(index: int) -> void:
	Localization.set_language("en" if index == 0 else "pl")

func _refresh_language() -> void:
	%Language.select(1 if Localization.language() == "pl" else 0)
	_refresh_status()
	if %Confirmation.visible:
		%ConfirmTitle.text = tr("Reset the world?" if _confirmation_kind == 1 else "Save before quitting?")
		%ConfirmDescription.text = tr("This removes the current save and starts a new world." if _confirmation_kind == 1 else "Choose whether to keep your current progress.")

func _set_music(value: float) -> void:
	Localization.set_music_volume(value)

func _confirm_reset() -> void:
	_confirmation_kind = 1
	%Main.hide()
	%Confirmation.show()
	%ConfirmTitle.text = tr("Reset the world?")
	%ConfirmDescription.text = tr("This removes the current save and starts a new world.")
	%ConfirmReset.show()
	%SaveQuit.hide()
	%QuitWithoutSaving.hide()
	%Cancel.grab_focus()

func confirm_quit() -> void:
	_confirmation_kind = 2
	%Main.hide()
	%Confirmation.show()
	%ConfirmTitle.text = tr("Save before quitting?")
	%ConfirmDescription.text = tr("Choose whether to keep your current progress.")
	%ConfirmReset.hide()
	%SaveQuit.show()
	%QuitWithoutSaving.show()
	%Cancel.grab_focus()

func cancel_confirmation() -> bool:
	if not %Confirmation.visible:
		return false
	%Confirmation.hide()
	%Main.show()
	%Resume.grab_focus()
	return true
