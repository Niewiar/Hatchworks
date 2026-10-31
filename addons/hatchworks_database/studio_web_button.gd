@tool
extends Button

signal status_changed(message: String, error: bool)

var catalog := "Creatures"
var design_document := false
var ai_graph := false
var _project := ""
var _base_url := ""
var _page_url := ""
var _launcher_pid := -1
var _deadline := 0
var _launch_attempted := false

func _ready() -> void:
	pressed.connect(open_studio)
	gui_input.connect(_on_button_input)
	$Settings.confirmed.connect(_save_settings)
	$Settings/Fields/Launcher/Browse.pressed.connect(func(): $LauncherDialog.popup_centered())
	$LauncherDialog.file_selected.connect(func(path): $Settings/Fields/Launcher/Path.text = path)
	$Request.request_completed.connect(_on_response)
	$Retry.timeout.connect(_request_connection)
	if Engine.is_editor_hint():
		var settings := EditorInterface.get_editor_settings()
		if not settings.has_setting("hatchworks_database/web/port"):
			settings.set_setting("hatchworks_database/web/port",8769)
		if not settings.has_setting("hatchworks_database/web/launcher"):
			settings.set_setting("hatchworks_database/web/launcher","")

func open_studio() -> void:
	if disabled:
		return
	_project = ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	var port := int(_setting("hatchworks_database/web/port",8769))
	if port < 1024 or port > 65535:
		status_changed.emit("Choose a web port from 1024 to 65535 by right-clicking Open Web Studio.",true)
		return
	_base_url = "http://127.0.0.1:%d/" % port
	var slug: String = {"World Balance":"world","Creature Research":"research"}.get(catalog,catalog.to_lower().replace(" ","_"))
	var page := "design.html" if design_document else ("index.html" if catalog == "Creatures" else ("discoveries.html" if catalog in ["Discoveries","Recipes"] else "database.html?catalog="+slug))
	_page_url = _base_url+page
	if ai_graph:
		_page_url = _base_url+"ai.html"
	_deadline = Time.get_ticks_msec()+300000
	_launch_attempted = false
	_launcher_pid = -1
	disabled = true
	status_changed.emit("Connecting to Web Studio...",false)
	_request_connection()

func _setting(key: String, fallback: Variant) -> Variant:
	if Engine.is_editor_hint():
		var settings := EditorInterface.get_editor_settings()
		var inherited: Variant = settings.get_setting(key) if settings.has_setting(key) else fallback
		return settings.get_project_metadata("hatchworks_database","web_"+key.get_file(),inherited)
	return fallback

func _request_connection() -> void:
	if Time.get_ticks_msec() >= _deadline:
		_finish("Web Studio did not become ready. Check its launcher and port by right-clicking Open Web Studio.",true)
		return
	if $Request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		var error: int = $Request.request(_base_url+"api/catalog")
		if error != OK:
			_finish("Could not connect to Web Studio: "+error_string(error),true)

func _on_response(result: int, response: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response == 200:
		var value: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not value is Dictionary or not value.get("project") is String:
			_finish("The selected web port belongs to another service. Choose another port by right-clicking Open Web Studio.",true)
			return
		if _canonical(value.project) != _canonical(_project):
			_finish("Web Studio is serving another project. Choose another web port by right-clicking Open Web Studio.",true)
			return
		var error := OS.shell_open(_page_url)
		_finish("Opened Web Studio for this project." if error == OK else "Could not open your browser: "+error_string(error),error != OK)
		return
	if response != 0:
		_finish("The selected web port did not return a compatible local Studio (HTTP %d)." % response,true)
		return
	if not _launch_attempted:
		_launch()
	elif _launcher_pid > 0 and not OS.is_process_running(_launcher_pid):
		_finish("The Studio launcher stopped before the server became ready. Check its path and port by right-clicking Open Web Studio.",true)

func _canonical(path: String) -> String:
	return path.replace("\\","/").simplify_path().trim_suffix("/").to_lower()

func _launch() -> void:
	if OS.get_name() != "Windows":
		_finish("Automatic Studio launch currently requires Windows. Start the local server manually, then click again.",true)
		return
	var automatic := _project.get_base_dir().path_join("Hatchworks-workbench/creature-editor/Open Creature Editor.ps1")
	var launcher := str(_setting("hatchworks_database/web/launcher",""))
	if launcher.is_empty():
		launcher = automatic
	if not FileAccess.file_exists(launcher):
		_finish("Set the Open Creature Editor.ps1 path by right-clicking Open Web Studio.",true)
		return
	var executable := _powershell()
	if executable.is_empty():
		_finish("PowerShell 7 was not found. Install it or start Web Studio manually.",true)
		return
	var port := _base_url.trim_suffix("/").get_slice(":",2)
	var arguments := PackedStringArray(["-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File",launcher,"-Project",_project,"-Port",port,"-NoBrowser","-OpenOnly"])
	_launcher_pid = OS.create_process(executable,arguments,false)
	_launch_attempted = true
	if _launcher_pid < 0:
		_finish("Could not start the Studio launcher.",true)
		return
	status_changed.emit("Starting Web Studio and preparing previews...",false)
	$Retry.start()

func _powershell() -> String:
	var candidates := PackedStringArray()
	for folder in OS.get_environment("PATH").split(";",false):
		candidates.append(folder.path_join("pwsh.exe"))
	candidates.append(OS.get_environment("ProgramFiles").path_join("PowerShell/7/pwsh.exe"))
	candidates.append(OS.get_environment("USERPROFILE").path_join(".cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe"))
	for path in candidates:
		if FileAccess.file_exists(path):
			return path
	return ""

func _finish(message: String, error: bool) -> void:
	$Retry.stop()
	disabled = false
	status_changed.emit(message,error)

func _on_button_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		$Settings/Fields/Port.value = int(_setting("hatchworks_database/web/port",8769))
		$Settings/Fields/Launcher/Path.text = str(_setting("hatchworks_database/web/launcher",""))
		$Settings.popup_centered()
		accept_event()

func _save_settings() -> void:
	if Engine.is_editor_hint():
		var settings := EditorInterface.get_editor_settings()
		settings.set_project_metadata("hatchworks_database","web_port",int($Settings/Fields/Port.value))
		settings.set_project_metadata("hatchworks_database","web_launcher",$Settings/Fields/Launcher/Path.text.strip_edges())
	status_changed.emit("Studio connection saved for this project.",false)
