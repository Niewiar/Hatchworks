@tool
class_name ForgeFileTransaction
extends RefCounted

var _directory := ""
var _project := ""
var _catalog := ""
var _folders := PackedStringArray()

func configure(directory: String, catalog: String, folders: PackedStringArray) -> void:
	_directory = directory.simplify_path()
	_project = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	_catalog = catalog
	_folders = folders

func staging_directory() -> String:
	var stamp := "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var path := _directory.path_join("transactions").path_join(stamp).path_join("staged")
	if DirAccess.make_dir_recursive_absolute(path) != OK:
		return ""
	return path

func recover() -> String:
	var path := _directory.path_join("transaction.json")
	if not FileAccess.file_exists(path):
		return ""
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("version") != 1 or value.get("project") != _project or value.get("catalog") != _catalog or not value.get("entries") is Array:
		return "Forge transaction journal is invalid. Source files were left untouched."
	if value.get("phase") == "committed":
		return _remove_journal(path)
	for entry: Variant in value.entries:
		if not entry is Dictionary or not _allowed_target(str(entry.get("target", ""))) or not _inside_work(str(entry.get("backup", ""))) or not entry.get("existed") is bool:
			return "Forge transaction journal contains an unsafe file path."
		var digest := _hash(entry.target)
		if digest not in [str(entry.get("before", "")), str(entry.get("after", "")), ""]:
			return "A source file changed after an interrupted Forge save: %s. Recovery is blocked to preserve the external edit." % entry.target
		if entry.existed and _hash(entry.backup) != entry.get("before"):
			return "Forge backup could not be verified: %s." % entry.target
	for entry: Dictionary in value.entries:
		var error: Error
		if entry.existed:
			error = _install(entry.backup, entry.target)
		else:
			error = DirAccess.remove_absolute(ProjectSettings.globalize_path(entry.target)) if FileAccess.file_exists(entry.target) else OK
		if error != OK:
			return "Forge could not restore %s: %s." % [entry.target, error_string(error)]
	return _remove_journal(path)

func commit(staging: String, outputs: Dictionary, removed: PackedStringArray, expected: Dictionary) -> String:
	if not _inside_work(staging):
		return "Forge staging directory is outside its workspace."
	for source: String in expected:
		if _hash(source) != expected[source]:
			return "Source files changed while the save was being prepared: %s." % source
	var targets: Array = outputs.keys()
	for target in removed:
		if not targets.has(target):
			targets.append(target)
	var entries: Array[Dictionary] = []
	for target: String in targets:
		if not _allowed_target(target):
			return "Forge refused an unsafe target path: %s." % target
		var original := staging.get_base_dir().path_join("originals").path_join(target.trim_prefix("res://"))
		var existed := FileAccess.file_exists(target)
		if existed:
			var error := DirAccess.make_dir_recursive_absolute(original.get_base_dir())
			if error == OK:
				error = DirAccess.copy_absolute(ProjectSettings.globalize_path(target), original)
			if error != OK:
				return "Forge could not back up %s: %s." % [target, error_string(error)]
		var output := str(outputs.get(target, ""))
		if not output.is_empty() and (not _inside_work(output) or not FileAccess.file_exists(output)):
			return "Forge staged resource is unavailable: %s." % target
		entries.append({"target": target, "backup": original, "existed": existed, "before": _hash(target), "after": _hash(output)})
	for source: String in expected:
		if _hash(source) != expected[source]:
			return "Source files changed while the save was being prepared: %s." % source
	var journal := {"version": 1, "project": _project, "catalog": _catalog, "phase": "prepared", "entries": entries}
	var journal_path := _directory.path_join("transaction.json")
	var error := write_atomic(journal_path, JSON.stringify(journal, "\t"))
	if error != OK:
		return "Forge could not write its recovery journal: %s." % error_string(error)
	for entry: Dictionary in entries:
		var output := str(outputs.get(entry.target, ""))
		if output.is_empty():
			error = DirAccess.remove_absolute(ProjectSettings.globalize_path(entry.target)) if FileAccess.file_exists(entry.target) else OK
		else:
			error = _install(output, entry.target)
		if error != OK or _hash(entry.target) != entry.after:
			var recovery := recover()
			return "Forge save failed at %s (%s). %s" % [entry.target, error_string(error), "Previous files restored." if recovery.is_empty() else recovery]
	journal.phase = "committed"
	error = write_atomic(journal_path, JSON.stringify(journal, "\t"))
	if error != OK:
		var recovery := recover()
		return "Forge could not finish its recovery journal. %s" % ["Previous files restored." if recovery.is_empty() else recovery]
	return _remove_journal(journal_path)

static func write_atomic(path: String, text: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return error
	var temporary := path + ".pending"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	error = file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(temporary, path)
	return error

func _install(source: String, target: String) -> Error:
	var absolute := ProjectSettings.globalize_path(target)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var temporary := absolute + ".forge-pending"
	if error == OK:
		error = DirAccess.copy_absolute(source, temporary)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, absolute)
	if error != OK and FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(temporary)
	return error

func _allowed_target(path: String) -> bool:
	if not path.begins_with("res://") or path.simplify_path() != path or path.get_extension() != "tres":
		return false
	if path == _catalog:
		return true
	for folder in _folders:
		if path.begins_with(folder + "/"):
			return true
	return false

func _inside_work(path: String) -> bool:
	return path.simplify_path().begins_with(_directory + "/") and not path.simplify_path().begins_with(_project + "/")

func _remove_journal(path: String) -> String:
	var error := DirAccess.remove_absolute(path)
	return "" if error == OK else "Forge could not remove its completed journal: %s." % error_string(error)

static func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if not path.is_empty() and FileAccess.file_exists(path) else ""
