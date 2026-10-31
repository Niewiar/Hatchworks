@tool
extends VBoxContainer

signal dirty_changed

const DOCUMENT := "res://docs/DESIGN.md"
const MAX_BYTES := 524288
var _baseline := ""
var _revision := ""
var _conflict := false
var _loading := false

func _ready() -> void:
	%Source.text_changed.connect(_on_edited)
	%Views.tab_changed.connect(func(_tab): _render())
	%Save.pressed.connect(save_document)
	%Reload.pressed.connect(func(): %DiscardDialog.popup_centered() if has_unsaved_changes() else _load_saved())
	%DiscardDialog.confirmed.connect(_load_saved)
	%Poll.timeout.connect(_check_external)
	_load_saved()
	if Engine.is_editor_hint():
		var draft: Dictionary = EditorInterface.get_editor_settings().get_project_metadata("hatchworks_database","design_draft",{})
		if draft.get("text") is String and draft.text != _baseline:
			_loading = true
			%Source.text = draft.text
			_loading = false
			_conflict = draft.get("revision","") != _revision
			_on_edited()

func _exit_tree() -> void:
	if Engine.is_editor_hint() and is_node_ready():
		EditorInterface.get_editor_settings().set_project_metadata("hatchworks_database","design_draft",{"text":%Source.text,"revision":_revision} if has_unsaved_changes() else {})

func has_unsaved_changes() -> bool:
	return is_node_ready() and %Source.text != _baseline

func _file_revision() -> String:
	return FileAccess.get_sha256(DOCUMENT) if FileAccess.file_exists(DOCUMENT) else ""

func _load_saved() -> void:
	_loading = true
	%Source.text = FileAccess.get_file_as_string(DOCUMENT) if FileAccess.file_exists(DOCUMENT) else ""
	_baseline = %Source.text
	_revision = _file_revision()
	_conflict = false
	_loading = false
	if Engine.is_editor_hint():
		EditorInterface.get_editor_settings().set_project_metadata("hatchworks_database","design_draft",{})
	_on_edited()
	%Status.text = "Shared project document · docs/DESIGN.md"

func _on_edited() -> void:
	if _loading:
		return
	%Save.disabled = not has_unsaved_changes() or _conflict
	%Conflict.visible = _conflict
	%State.text = "External changes" if _conflict else ("Unsaved draft" if has_unsaved_changes() else "Saved")
	_render()
	dirty_changed.emit()

func _check_external() -> void:
	if not visible or _loading:
		return
	if _file_revision() == _revision:
		return
	if has_unsaved_changes():
		_conflict = true
		_on_edited()
	else:
		_load_saved()

func _store_folder() -> String:
	var project := ProjectSettings.globalize_path("res://").replace("\\","/").simplify_path().trim_suffix("/")
	return project.get_base_dir().path_join("Hatchworks-workbench/design-doc-data/"+project.to_lower().sha256_text().left(16))

func save_document() -> bool:
	if not has_unsaved_changes():
		return true
	if _conflict:
		return false
	var data: PackedByteArray = %Source.text.to_utf8_buffer()
	if data.size() > MAX_BYTES or 0 in data:
		%Status.text = "Use UTF-8 text up to 512 KiB without null characters."
		return false
	var folder := _store_folder()
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		%Status.text = "Could not create document storage: "+error_string(error)
		return false
	var lock_path := folder.path_join("save.lock")
	if DirAccess.make_dir_absolute(lock_path) != OK:
		%Status.text = "Another editor is saving the document. Try again shortly."
		return false
	if _file_revision() != _revision:
		DirAccess.remove_absolute(lock_path)
		_conflict = true
		_on_edited()
		return false
	if FileAccess.file_exists(DOCUMENT):
		error = DirAccess.copy_absolute(ProjectSettings.globalize_path(DOCUMENT),folder.path_join("godot-"+_revision.left(12)+"-"+str(Time.get_ticks_usec())+".md"))
	if error == OK:
		error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs"))
	var temporary := DOCUMENT+"."+str(OS.get_process_id())+".tmp"
	if error == OK:
		var file := FileAccess.open(temporary,FileAccess.WRITE)
		if file == null:
			error = FileAccess.get_open_error()
		else:
			file.store_buffer(data)
			file.flush()
			error = file.get_error()
			file.close()
	if error == OK and _file_revision() != _revision:
		error = ERR_BUSY
		_conflict = true
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(DOCUMENT))
	if FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	DirAccess.remove_absolute(lock_path)
	if error != OK:
		%Status.text = "Document was not saved: "+error_string(error)
		_on_edited()
		return false
	_baseline = %Source.text
	_revision = _file_revision()
	if Engine.is_editor_hint():
		EditorInterface.get_editor_settings().set_project_metadata("hatchworks_database","design_draft",{})
	_on_edited()
	%Status.text = "Design Doc saved. The web editor will refresh its clean view automatically."
	return true

func _render() -> void:
	if not is_node_ready() or %Views.current_tab != 1:
		return
	var result := PackedStringArray()
	var code := false
	for raw: String in %Source.text.split("\n"):
		if raw.begins_with("```"):
			code = not code
			result.append("[code]" if code else "[/code]")
			continue
		var line: String = raw.replace("[","[lb]")
		if code:
			result.append(line)
			continue
		if line.begins_with("### "):
			result.append("\n[font_size=19][b]"+_inline(line.substr(4))+"[/b][/font_size]\n")
		elif line.begins_with("## "):
			result.append("\n[font_size=23][b]"+_inline(line.substr(3))+"[/b][/font_size]\n")
		elif line.begins_with("# "):
			result.append("[font_size=30][b]"+_inline(line.substr(2))+"[/b][/font_size]\n")
		else:
			result.append(_inline("• "+line.substr(2) if line.begins_with("- ") else line))
	if code:
		result.append("[/code]")
	%Preview.text = "\n".join(result)

func _inline(line: String) -> String:
	var bold := RegEx.new()
	bold.compile("\\*\\*(.+?)\\*\\*")
	line = bold.sub(line,"[b]$1[/b]",true)
	var code := RegEx.new()
	code.compile("`([^`]+)`")
	return code.sub(line,"[code]$1[/code]",true)
