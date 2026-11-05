@tool
class_name ForgeAnimationReviewStore
extends RefCounted

const DRAFT_PATH := "user://hatchworks_forge/animation_review.json"

var notes: Array[Dictionary] = []
var last_error := ""
var _draft_writable := true

func load_draft() -> Error:
	notes.clear()
	last_error = ""
	_draft_writable = true
	if not FileAccess.file_exists(DRAFT_PATH):
		return OK
	var file := FileAccess.open(DRAFT_PATH,FileAccess.READ)
	if file == null:
		return _draft_error(FileAccess.get_open_error(),"Nie można odczytać zapisanych uwag.")
	if file.get_length() > 33554432:
		return _draft_error(ERR_FILE_CORRUPT,"Plik uwag jest zbyt duży.")
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _draft_error(ERR_FILE_CORRUPT,"Nieprawidłowy plik uwag. Eksport nadal jest dostępny.")
	var data: Variant = parser.data
	if not data is Dictionary or data.get("version") != 1 or not data.get("notes") is Array or data.notes.size() > 1024:
		return _draft_error(ERR_FILE_CORRUPT,"Nieprawidłowy plik uwag. Eksport nadal jest dostępny.")
	var restored: Array[Dictionary] = []
	for note: Variant in data.notes:
		if not _valid_note(note):
			return _draft_error(ERR_FILE_CORRUPT,"Nieprawidłowy wpis w pliku uwag.")
		restored.append(note)
	notes = restored
	return OK

func save_draft() -> Error:
	if not _draft_writable:
		return _fail(ERR_FILE_CORRUPT,"Poprzedni plik uwag jest chroniony. Zapisz nowe uwagi przez eksport.")
	var directory := ProjectSettings.globalize_path(DRAFT_PATH.get_base_dir())
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return _fail(error,"Nie można utworzyć folderu uwag.")
	var temporary := DRAFT_PATH+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		return _fail(FileAccess.get_open_error(),"Nie można zapisać uwag.")
	file.store_string(JSON.stringify({"version":1,"notes":notes},"\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(DRAFT_PATH))
	if error != OK:
		return _fail(error,"Nie można zapisać uwag.")
	last_error = ""
	return OK

func set_note(context: Dictionary, text: String, index: int = -1) -> int:
	var note := context.duplicate(true)
	note["text"] = text.strip_edges()
	if not _valid_note(note) or index < -1 or index >= notes.size() or (index < 0 and notes.size() >= 1024):
		_fail(ERR_INVALID_DATA,"Wybierz animację i wpisz uwagę.")
		return -1
	if index < 0:
		notes.append(note)
		index = notes.size()-1
	else:
		notes[index] = note
	last_error = ""
	return index

func remove_note(index: int) -> bool:
	if index < 0 or index >= notes.size():
		return false
	notes.remove_at(index)
	return true

func default_report_path() -> String:
	return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).path_join("Hatchworks-animation-review.md")

func export_report(path: String) -> Error:
	if notes.is_empty():
		return _fail(ERR_INVALID_DATA,"Dodaj przynajmniej jedną uwagę.")
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		return _fail(FileAccess.get_open_error(),"Nie można zapisać raportu w wybranym miejscu.")
	file.store_string(report_text())
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return _fail(error,"Nie można zapisać raportu w wybranym miejscu.")
	last_error = ""
	return OK

func report_text() -> String:
	var lines := PackedStringArray([
		"# Hatchworks — uwagi do animacji",
		"",
		"Wygenerowano: "+Time.get_datetime_string_from_system(false,true),
		"Projekt: "+ProjectSettings.globalize_path("res://"),
		"",
		"Uwagi dotyczą całych animacji. Numery klatek mogą być dopisane w treści; podgląd numeruje je od 0. FPS przy uwadze określa sposób przeliczania klatek.",
		""
	])
	var ordered := notes.duplicate()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary): return _sort_key(a).naturalnocasecmp_to(_sort_key(b)) < 0)
	var group := ""
	var number := 0
	for note: Dictionary in ordered:
		var key := _sort_key(note)
		if key != group:
			group = key
			number = 0
			lines.append("## %s · %s · %s" % [note.species_name,"Samica" if note.female else "Samiec",note.animation])
			lines.append("")
			lines.append("Gatunek: `%s` · Model: `%s`" % [note.species_id,note.model_path])
			lines.append("")
			if note.has("partner_female"):
				lines.append("Partner: %s · Animacja partnera: `%s`" % ["Samica" if note.partner_female else "Samiec",note.partner_animation])
				lines.append("")
		number += 1
		lines.append("%d. **FPS: %d · długość: %.3f s**" % [number,int(note.fps),float(note.duration)])
		if note.has("vfx_enabled"):
			lines.append("   VFX: "+("włączone" if note.vfx_enabled else "wyłączone"))
		if note.has("sfx_enabled"):
			lines.append("   Dźwięk: "+("włączony" if note.sfx_enabled else "wyłączony"))
		if note.has("sound_volume"):
			lines.append("   Głośność podglądu: %d%%" % roundi(float(note.sound_volume)*100.0))
		for line in str(note.text).split("\n"):
			lines.append("   "+line)
		lines.append("")
	return "\n".join(lines)

func _sort_key(note: Dictionary) -> String:
	return str(note.species_name)+"/"+str(note.female)+"/"+str(note.animation)+"/"+str(note.get("partner_female","solo"))+"/"+str(note.get("partner_animation",""))

func _valid_note(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["species_id","species_name","animation","model_path","text"]:
		if not value.get(key) is String or value[key].is_empty() or value[key].length() > (16384 if key == "text" else 1024):
			return false
	if value.has("partner_female") or value.has("partner_animation"):
		if not value.get("partner_female") is bool or not value.get("partner_animation") is String or value.partner_animation.is_empty() or value.partner_animation.length() > 1024:
			return false
	for key in ["vfx_enabled","sfx_enabled"]:
		if value.has(key) and not value[key] is bool:
			return false
	if value.has("sound_volume"):
		var volume: Variant = value.sound_volume
		if (not volume is float and not volume is int) or not is_finite(float(volume)) or volume < 0.0 or volume > 1.0:
			return false
	var fps: Variant = value.get("fps")
	var duration: Variant = value.get("duration")
	if not value.get("female") is bool or (not fps is int and not fps is float) or (not duration is float and not duration is int):
		return false
	return (is_finite(float(fps)) and float(fps) == floorf(float(fps)) and fps >= 1 and fps <= 120
		and is_finite(float(duration)) and duration >= 0.0 and duration <= 86400.0)

func _draft_error(error: Error, message: String) -> Error:
	_draft_writable = false
	return _fail(error,message)

func _fail(error: Error, message: String) -> Error:
	last_error = message
	return error
