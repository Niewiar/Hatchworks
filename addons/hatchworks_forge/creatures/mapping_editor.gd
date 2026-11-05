@tool
class_name ForgeCreatureMappingEditor
extends VBoxContainer

signal value_changed(value: Variant)
signal validation_changed(error: String)

const ROW := preload("res://addons/hatchworks_forge/creatures/mapping_row.tscn")

var _field: Dictionary = {}
var _values: Dictionary = {}
var _last_override: Dictionary = {}
var _labels: Dictionary = {}
var _known: Dictionary = {}
var _rows: Dictionary = {}
var _pending: Dictionary = {}
var _scale := 1.0
var _female := false
var _binding := false
var _raw_mode := false
var _error := ""

func _ready() -> void:
	%Override.toggled.connect(_override_changed)
	%Raw.text_changed.connect(_raw_changed)
	%ApplyRepair.pressed.connect(_apply_repair)

func configure(field: Dictionary, value: Variant) -> void:
	_field = field
	_scale = float(field.get("mapping_scale",1.0))
	_female = str(field.name)=="female_terrain_minimums" or bool(field.get("mapping_inherits",false))
	_labels.clear()
	_known.clear()
	for option: Dictionary in field.get("mapping_known_options",field.get("mapping_options",[])):
		_known[str(option.key)] = str(option.label)
	for option: Dictionary in field.get("mapping_options",[]):
		_labels[str(option.key)] = str(option.label)
	_binding = true
	_pending.clear()
	_last_override.clear()
	_raw_mode = not value is Dictionary
	_values = value.duplicate(true) if value is Dictionary else {}
	%Override.visible = _female and not _raw_mode
	%Override.set_pressed_no_signal(not _values.is_empty())
	if _raw_mode:
		%Raw.text = value if value is String else JSON.stringify(value,"\t")
	_binding = false
	_rebuild()

func validation_error() -> String:
	return _error

func has_uncommitted_value() -> bool:
	return not _pending.is_empty()

func update_inherited_value(value: Variant) -> void:
	_field["inherited_value"] = value.duplicate(true) if value is Dictionary else value
	if %Inherited.visible:
		%Inherited.text = _inherited_text()

func commit_field() -> void:
	if _raw_mode:
		if _parse_raw() is Dictionary:
			_apply_repair()
		return
	for key: String in _pending.keys():
		var number: SpinBox = _rows[key].get_node("ValueRow/Percent")
		var parsed: Variant = _parse_number(_pending[key])
		if parsed == null:
			_restore_pending_text.call_deferred()
			continue
		_binding = true
		number.value = parsed
		_binding = false
		_pending.erase(key)
		_set_value(key,float(parsed)/_scale)
	_refresh_validation()

func _restore_pending_text() -> void:
	for key: String in _pending:
		if _rows.has(key):
			_rows[key].get_node("ValueRow/Percent").get_line_edit().text = _pending[key]

func _rebuild() -> void:
	_rows.clear()
	_pending.clear()
	for child in %Rows.get_children():
		%Rows.remove_child(child)
		child.queue_free()
	%Repair.visible = _raw_mode
	var inherited: bool = _female and not %Override.button_pressed and not _raw_mode
	%Inheritance.visible = _female and not _raw_mode
	%Inherited.visible = inherited
	%Rows.visible = not _raw_mode and not inherited
	%Total.visible = not _raw_mode and not inherited and _is_terrain()
	if inherited:
		%Inherited.text = _inherited_text()
	elif not _raw_mode:
		for key: String in _labels:
			_add_row(key,false)
		for key: Variant in _values:
			if not _labels.has(str(key)):
				_add_row(str(key),true)
	_refresh_validation()

func _add_row(key: String, extra: bool) -> void:
	var row := ROW.instantiate() as VBoxContainer
	%Rows.add_child(row)
	_rows[key] = row
	row.get_node("ValueRow/Name").text = _known.get(key,_labels.get(key,key))
	var number := row.get_node("ValueRow/Percent") as SpinBox
	var raw: Variant = _get_value(key)
	if (raw is int or raw is float) and is_finite(float(raw)):
		number.set_value_no_signal(float(raw)*_scale)
	else:
		number.set_value_no_signal(0.0)
	_update_row_note(key,extra)
	var remove := row.get_node("ValueRow/Remove") as Button
	remove.visible = extra
	remove.pressed.connect(_remove_key.bind(key))
	number.value_changed.connect(_number_changed.bind(key))
	number.get_line_edit().text_changed.connect(_number_text_changed.bind(key))
	number.get_line_edit().focus_exited.connect(commit_field)

func _update_row_note(key: String, extra: bool) -> void:
	var note := _rows[key].get_node("Note") as Label
	var raw: Variant = _get_value(key)
	var notes := PackedStringArray()
	if extra:
		notes.append("Dodatkowy wpis z danych" if _known.has(key) else "Nieznany wpis — usuń go, aby poprawić dane.")
	if not (raw is int or raw is float) or not is_finite(float(raw)):
		notes.append("Nieprawidłowa zapisana wartość: "+str(raw))
	note.text = "\n".join(notes)
	note.visible = not notes.is_empty()
	note.theme_type_variation = &"ForgeMuted" if _known.has(key) else &"ForgeError"

func _get_value(key: String) -> Variant:
	for stored: Variant in _values:
		if str(stored)==key:
			return _values[stored]
	return 0.0

func _stored_key(key: String) -> Variant:
	for stored: Variant in _values:
		if str(stored)==key:
			return stored
	return key

func _set_value(key: String, value: float) -> void:
	var stored: Variant = _stored_key(key)
	if is_zero_approx(value) and not _female and _labels.has(key):
		_values.erase(stored)
	else:
		_values[stored] = value
	_update_row_note(key,not _labels.has(key))
	_refresh_validation()
	value_changed.emit(_values.duplicate(true))

func _number_changed(value: float, key: String) -> void:
	if _binding:
		return
	_pending.erase(key)
	_set_value(key,value/_scale)

func _number_text_changed(text: String, key: String) -> void:
	if _binding:
		return
	_pending[key] = text
	_refresh_validation()

func _parse_number(text: String) -> Variant:
	var cleaned := text.replace("%","").replace(",",".").strip_edges()
	if not cleaned.is_valid_float():
		return null
	var value := cleaned.to_float()
	return value if is_finite(value) and value>=0.0 and value<=100.0 else null

func _remove_key(key: String) -> void:
	commit_field()
	_values.erase(_stored_key(key))
	_pending.erase(key)
	var row: Control = _rows[key]
	_rows.erase(key)
	%Rows.remove_child(row)
	row.queue_free()
	if _female and %Override.button_pressed and _values.is_empty() and not _labels.is_empty():
		var first: String = _labels.keys()[0]
		_values[first] = 0.0
		if not _rows.has(first):
			_add_row(first,false)
	_refresh_validation()
	value_changed.emit(_values.duplicate(true))

func _override_changed(active: bool) -> void:
	if _binding:
		return
	commit_field()
	if not _pending.is_empty():
		%Override.set_pressed_no_signal(not active)
		return
	if active:
		_values = _last_override.duplicate(true)
		if _values.is_empty():
			var inherited: Variant = _field.get("inherited_value",{})
			for key: String in _labels:
				_values[key] = float(inherited.get(key,0.0)) if inherited is Dictionary else 0.0
	else:
		_last_override = _values.duplicate(true)
		_values = {}
	_rebuild()
	value_changed.emit(_values.duplicate(true))

func _inherited_text() -> String:
	var inherited: Variant = _field.get("inherited_value",{})
	if not inherited is Dictionary:
		return "Profil wspólny wymaga poprawienia."
	var lines := PackedStringArray()
	for key: Variant in inherited:
		var value: Variant = inherited[key]
		lines.append(str(_known.get(str(key),key))+": "+(String.num(float(value)*_scale,2)+"%" if value is int or value is float else str(value)))
	return "Profil wspólny: brak wymagań." if lines.is_empty() else "Profil wspólny:\n"+"\n".join(lines)

func _is_terrain() -> bool:
	return str(_field.name) in ["terrain_minimums","female_terrain_minimums"]

func _parse_raw() -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(%Raw.text)==OK and parser.data is Dictionary else null

func _raw_changed() -> void:
	if _binding:
		return
	_refresh_validation()
	value_changed.emit(%Raw.text)

func _apply_repair() -> void:
	var parsed: Variant = _parse_raw()
	if not parsed is Dictionary:
		return
	_values = parsed.duplicate(true)
	_raw_mode = false
	%Override.visible = _female
	%Override.set_pressed_no_signal(not _values.is_empty())
	_rebuild()
	value_changed.emit(_values.duplicate(true))

func _refresh_validation() -> void:
	_error = ""
	var total := 0.0
	if _raw_mode:
		_error = "Wymagany obiekt JSON. Zachowano szkic do poprawienia."
		%ApplyRepair.disabled = not _parse_raw() is Dictionary
	else:
		for key: Variant in _values:
			var value: Variant = _values[key]
			if not _known.has(str(key)):
				_error = "Nieznany wpis: "+str(key)+". Usuń go z danych."
			elif not (value is int or value is float) or not is_finite(float(value)):
				_error = str(key)+": wpisz poprawną liczbę."
			elif float(value)<0.0 or float(value)*_scale>100.0:
				_error = str(key)+": wartość musi mieścić się między 0 a 100%."
			else:
				total += float(value)*_scale
		if _error.is_empty() and _is_terrain() and total>100.00001:
			_error = "Suma udziałów terenu nie może przekraczać 100%."
		for key: String in _pending:
			if _parse_number(_pending[key])==null:
				_error = key+": wpisz wartość od 0 do 100%."
	%Total.text = "Suma: "+String.num(total,2)+"%"
	%Error.text = _error
	%Error.visible = not _error.is_empty()
	validation_changed.emit(_error)
