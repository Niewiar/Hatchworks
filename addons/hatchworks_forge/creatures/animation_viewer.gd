@tool
extends Window

const REVIEW_STORE := preload("res://addons/hatchworks_forge/creatures/animation_review_store.gd")

var _opened := false
var _species_index := 0
var _female := false
var _partner_female := true
var _binding := false
var _selecting_note := false
var _editing_note := -1
var _store := REVIEW_STORE.new()
var _species: Array[CreatureSpecies] = []

@onready var _preview: ForgeCreaturePreview = %Preview

func _ready() -> void:
	close_requested.connect(hide)
	var database := load(GameDatabase.DEFAULT_PATH) as GameDatabase
	if database != null:
		for species: CreatureSpecies in database.creatures:
			if species != null:
				_species.append(species)
				%Species.add_item(species.display_name)
	%Species.item_selected.connect(_select_species)
	%Male.pressed.connect(_select_female.bind(false))
	%Female.pressed.connect(_select_female.bind(true))
	%PartnerSex.item_selected.connect(_select_partner)
	%VFX.toggled.connect(_effects_toggled)
	%SFX.toggled.connect(_effects_toggled)
	%SoundVolume.value_changed.connect(_sound_volume_changed)
	%Frame.value_changed.connect(_frame_changed)
	%FramesPerSecond.value_changed.connect(_fps_changed)
	_preview.time_changed.connect(_sync_frame)
	_preview.animation_changed.connect(_animation_changed)
	%ReviewNotes.item_selected.connect(_select_note)
	%NoteText.text_changed.connect(_update_note_actions)
	%AddNote.pressed.connect(_save_note)
	%NewNote.pressed.connect(_new_note)
	%DeleteNote.pressed.connect(_delete_note)
	%ExportReview.pressed.connect(_open_export)
	%SaveReport.file_selected.connect(_export_report)
	_preview.frames_per_second = %FramesPerSecond.value
	_configure_preview()
	var error := _store.load_draft()
	_refresh_notes()
	if error != OK:
		_message(_store.last_error, true)
	elif _species.is_empty():
		_message("Baza gry nie zawiera kreatur.", true)
	elif not _store.notes.is_empty():
		_message("Przywrócono uwagi: %d." % _store.notes.size())

func open_viewer() -> void:
	if not _opened:
		popup_centered()
		_opened = true
	else:
		show()
	grab_focus()

func selected_context() -> Dictionary:
	if _species.is_empty():
		return {}
	var species: CreatureSpecies = _species[_species_index]
	var model_root := _preview.find_child("ModelRoot", true, false)
	var model_path := ""
	if model_root != null and model_root.get_child_count() > 0:
		model_path = model_root.get_child(0).scene_file_path
	var context := {
		"species_id": str(species.id),
		"species_name": species.display_name,
		"female": _female,
		"animation": _preview.selected_animation(),
		"fps": roundi(%FramesPerSecond.value),
		"duration": _preview.duration(),
		"model_path": model_path,
		"vfx_enabled": %VFX.button_pressed,
		"sfx_enabled": %SFX.button_pressed,
		"sound_volume": float(%SoundVolume.value)
	}
	context.merge(_preview.pair_context())
	return context

func _select_species(index: int) -> void:
	_new_note()
	_species_index = index
	_configure_preview()

func _select_female(female: bool) -> void:
	_new_note()
	_female = female
	%Male.set_pressed_no_signal(not female)
	%Female.set_pressed_no_signal(female)
	_configure_preview()

func _configure_preview(reset_partner: bool = true) -> void:
	if reset_partner:
		_partner_female = not _female
	_preview.configure(_species[_species_index] if not _species.is_empty() else null, _female)
	_preview.configure_pair(true, _partner_female)
	_configure_effects()
	_refresh_partner_controls()

func _effects_toggled(_enabled: bool) -> void:
	_configure_effects()

func _sound_volume_changed(_value: float) -> void:
	_configure_effects()

func _configure_effects() -> void:
	_preview.configure_effects(%VFX.button_pressed, %SFX.button_pressed, float(%SoundVolume.value))
	%SoundVolumeValue.text = "%d%%" % roundi(%SoundVolume.value * 100.0)

func _animation_changed(_name: String) -> void:
	_sync_frame(_preview.current_time(), _preview.duration())
	_refresh_partner_controls()
	if not _selecting_note:
		_new_note()

func _sync_frame(position: float, length: float) -> void:
	_binding = true
	var count := roundi(length * %FramesPerSecond.value)
	%Frame.max_value = count
	%Frame.set_value_no_signal(roundi(position * %FramesPerSecond.value))
	%FrameCount.text = "/ %d" % count
	_binding = false

func _frame_changed(frame: float) -> void:
	if not _binding:
		_preview.seek(frame / %FramesPerSecond.value)

func _fps_changed(fps: float) -> void:
	_preview.frames_per_second = fps
	_sync_frame(_preview.current_time(), _preview.duration())

func _select_partner(index: int) -> void:
	_new_note()
	_partner_female = index == 1
	_preview.configure_pair(true, _partner_female)
	_refresh_partner_controls()

func _refresh_partner_controls() -> void:
	%PartnerControls.visible = not _preview.pair_context().is_empty()
	%PartnerSex.select(1 if _partner_female else 0)

func _new_note() -> void:
	_editing_note = -1
	%ReviewNotes.deselect_all()
	%NoteText.clear()
	_update_note_actions()
	_message("")

func _update_note_actions() -> void:
	%AddNote.disabled = %NoteText.text.strip_edges().is_empty() or _preview.selected_animation().is_empty()
	%AddNote.text = "Zapisz uwagę" if _editing_note >= 0 else "Dodaj uwagę"
	%DeleteNote.disabled = _editing_note < 0
	%ExportReview.disabled = _store.notes.is_empty()

func _refresh_notes() -> void:
	%ReviewNotes.clear()
	for note: Dictionary in _store.notes:
		var label := "%s · %s · %s" % [note.species_name, "Samica" if note.female else "Samiec", note.animation]
		if note.has("partner_female"):
			label += " + " + ("Samica" if note.partner_female else "Samiec")
		%ReviewNotes.add_item(label)
	if _editing_note >= 0 and _editing_note < _store.notes.size():
		%ReviewNotes.select(_editing_note)
	_update_note_actions()

func _save_note() -> void:
	var context := selected_context()
	if _editing_note >= 0 and str(_store.notes[_editing_note].animation) != _preview.selected_animation():
		context = _store.notes[_editing_note].duplicate()
		context.erase("text")
	var index := _store.set_note(context, %NoteText.text, _editing_note)
	if index < 0:
		_message(_store.last_error, true)
		return
	_editing_note = index
	_refresh_notes()
	_persist_notes("Zapisano uwagę.")

func _select_note(index: int) -> void:
	if index < 0 or index >= _store.notes.size():
		return
	var note: Dictionary = _store.notes[index]
	var species_index := -1
	for candidate in _species.size():
		if str(_species[candidate].id) == str(note.species_id):
			species_index = candidate
			break
	if species_index < 0:
		_new_note()
		_message("Model zapisanej uwagi jest niedostępny.", true)
		return
	_selecting_note = true
	_species_index = species_index
	_female = note.female
	_partner_female = bool(note.get("partner_female", not _female))
	%Species.select(species_index)
	%Male.set_pressed_no_signal(not _female)
	%Female.set_pressed_no_signal(_female)
	%FramesPerSecond.set_value_no_signal(note.fps)
	if note.has("vfx_enabled"):
		%VFX.set_pressed_no_signal(note.vfx_enabled)
	if note.has("sfx_enabled"):
		%SFX.set_pressed_no_signal(note.sfx_enabled)
	if note.has("sound_volume"):
		%SoundVolume.set_value_no_signal(float(note.sound_volume))
	_preview.frames_per_second = note.fps
	_configure_preview(false)
	_preview.play_animation(note.animation)
	_selecting_note = false
	_editing_note = index
	%NoteText.text = note.text
	_update_note_actions()
	if _preview.selected_animation() != str(note.animation):
		_preview.seek(0.0)
		_message("Animacja została usunięta. Możesz nadal edytować lub wyeksportować tę uwagę.", true)
		return
	_message("Edytujesz uwagę do całej animacji.")

func _delete_note() -> void:
	if not _store.remove_note(_editing_note):
		return
	_new_note()
	_refresh_notes()
	_persist_notes("Usunięto uwagę.")

func _persist_notes(message: String) -> void:
	if _store.save_draft() != OK:
		_message(_store.last_error, true)
	else:
		_message(message)

func _open_export() -> void:
	%SaveReport.current_path = _store.default_report_path()
	%SaveReport.popup_centered()

func _export_report(path: String) -> void:
	if _store.export_report(path) != OK:
		_message(_store.last_error, true)
	else:
		_message("Zapisano raport: %s" % path)

func _message(text: String, error: bool = false) -> void:
	%Status.text = text
	%Status.theme_type_variation = &"ForgeError" if error else &"ForgeMuted"
