extends Node

signal language_changed
signal music_volume_changed(value: float)
signal sound_volume_changed(value: float)

const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES := ["en","pl"]

var _language := "en"
var _music_volume := 0.65
var _sound_volume := 0.7

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		var saved := str(settings.get_value("interface","language","en"))
		if saved in LANGUAGES:
			_language = saved
		var volume: Variant = settings.get_value("audio","music_volume",0.65)
		if (volume is float or volume is int) and is_finite(float(volume)):
			_music_volume = clampf(float(volume),0.0,1.0)
		var sound: Variant = settings.get_value("audio","sound_volume",0.7)
		if (sound is float or sound is int) and is_finite(float(sound)):
			_sound_volume = clampf(float(sound),0.0,1.0)
	TranslationServer.set_locale(_language)

func language() -> String:
	return _language

func set_language(locale: String) -> Error:
	if locale not in LANGUAGES:
		return ERR_INVALID_PARAMETER
	_language = locale
	TranslationServer.set_locale(_language)
	language_changed.emit()
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("interface","language",_language)
	return settings.save(SETTINGS_PATH)

func music_volume() -> float:
	return _music_volume

func set_music_volume(value: float) -> Error:
	if not is_finite(value):
		return ERR_INVALID_PARAMETER
	_music_volume = clampf(value,0.0,1.0)
	music_volume_changed.emit(_music_volume)
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("audio","music_volume",_music_volume)
	return settings.save(SETTINGS_PATH)

func sound_volume() -> float:
	return _sound_volume

func set_sound_volume(value: float) -> Error:
	if not is_finite(value):
		return ERR_INVALID_PARAMETER
	_sound_volume = clampf(value,0.0,1.0)
	sound_volume_changed.emit(_sound_volume)
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("audio","sound_volume",_sound_volume)
	return settings.save(SETTINGS_PATH)
