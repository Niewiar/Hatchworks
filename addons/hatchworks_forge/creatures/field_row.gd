@tool
class_name ForgeCreatureFieldRow
extends VBoxContainer

signal value_changed(name: String, value: Variant)
signal validation_changed(name: String, error: String)

const MAPPINGS := ["terrain_minimums","female_terrain_minimums","species_aversions"]

var _field: Dictionary = {}
var _binding := false
var _error := ""
var _numeric_pending := false
var _numeric_text := ""

func _ready() -> void:
	%Line.text_changed.connect(_text_changed)
	%Multiline.text_changed.connect(_multiline_changed)
	%Number.value_changed.connect(_number_changed)
	%Number.get_line_edit().text_changed.connect(_number_text_changed)
	%Number.get_line_edit().focus_exited.connect(commit_field)
	%Choice.item_selected.connect(_choice_changed)
	%Toggle.toggled.connect(_toggle_changed)
	%Mapping.value_changed.connect(_mapping_changed)
	%Mapping.validation_changed.connect(_mapping_validation)

func configure(field: Dictionary, value: Variant, changed: bool) -> void:
	_field = field
	_binding = true
	_error = ""
	_numeric_pending = false
	_numeric_text = ""
	%FieldName.text = str(field.label)
	%Changed.visible = changed
	%Unit.text = str(field.get("unit",""))
	%Unit.visible = not %Unit.text.is_empty()
	%Description.text = str(field.get("description",""))
	%Description.visible = not %Description.text.is_empty()
	for control in [%Line,%Multiline,%Number,%Choice,%Toggle,%Readonly,%Mapping]:
		control.hide()
	if not field.editable:
		%Readonly.text = str(value)
		%Readonly.show()
	elif str(field.name) in MAPPINGS:
		%Mapping.show()
		%Mapping.configure(field,value)
		_error = %Mapping.validation_error()
	elif not field.options.is_empty():
		%Choice.clear()
		for option: Dictionary in field.options:
			%Choice.add_item(str(option.label))
			var index: int = %Choice.item_count-1
			%Choice.set_item_metadata(index,option.value)
			if option.value==value:
				%Choice.select(index)
		%Choice.show()
	elif int(field.type)==TYPE_BOOL:
		%Toggle.set_pressed_no_signal(bool(value))
		%Toggle.show()
	elif int(field.type) in [TYPE_INT,TYPE_FLOAT]:
		%Number.min_value = -1000000000.0
		%Number.max_value = 1000000000.0
		%Number.step = 1.0 if int(field.type)==TYPE_INT else 0.001
		if int(field.hint)==PROPERTY_HINT_RANGE:
			var limits: PackedStringArray = str(field.hint_string).split(",")
			%Number.min_value = float(limits[0])
			%Number.max_value = float(limits[1])
			if limits.size()>2:
				%Number.step = float(limits[2]) if int(field.type)==TYPE_INT else minf(float(limits[2]),0.001)
		%Number.value = float(value)
		%Number.show()
	elif int(field.type)==TYPE_DICTIONARY or int(field.hint)==PROPERTY_HINT_MULTILINE_TEXT or field.name=="description":
		%Multiline.text = JSON.stringify(value,"\t") if value is Dictionary else str(value)
		%Multiline.show()
		if int(field.type)==TYPE_DICTIONARY:
			_parse_dictionary(false)
	elif int(field.type) in [TYPE_STRING,TYPE_STRING_NAME]:
		%Line.text = str(value)
		%Line.show()
	else:
		%Readonly.text = str(value)
		%Readonly.show()
		_error = "Brak obsługi edycji tego typu danych."
	_binding = false
	_show_error()

func validation_error() -> String:
	return _error

func has_uncommitted_value() -> bool:
	return %Mapping.has_uncommitted_value() if %Mapping.visible else (%Number.visible and _numeric_pending)

func update_inherited_value(value: Variant) -> void:
	_field["inherited_value"] = value
	%Mapping.update_inherited_value(value)

func commit_field() -> void:
	if %Mapping.visible:
		%Mapping.commit_field()
	elif %Number.visible and _numeric_pending:
		var parsed: Variant = _parse_number(_numeric_text)
		if parsed==null:
			_restore_numeric_text.call_deferred()
			return
		_binding = true
		%Number.value = parsed
		_binding = false
		_numeric_pending = false
		_numeric_text = ""
		_error = ""
		_show_error()
		_emit(int(parsed) if int(_field.type)==TYPE_INT else float(parsed))
		validation_changed.emit(str(_field.name),_error)

func _restore_numeric_text() -> void:
	if _numeric_pending:
		%Number.get_line_edit().text = _numeric_text

func _text_changed(value: String) -> void:
	if not _binding:
		_emit(value)

func _multiline_changed() -> void:
	if _binding:
		return
	if int(_field.type)==TYPE_DICTIONARY:
		_parse_dictionary(true)
	else:
		_emit(%Multiline.text)

func _parse_dictionary(emit_value: bool) -> void:
	var parser := JSON.new()
	var parsed: int = parser.parse(%Multiline.text)
	var value: Variant = parser.data if parsed==OK else null
	_error = "" if value is Dictionary else "Wpisz poprawny obiekt JSON."
	if value is Dictionary and str(_field.name)=="ai_graph":
		_error = CreatureAiGraph.validate(value)
	_show_error()
	if emit_value:
		_emit(value if value is Dictionary else %Multiline.text)
		validation_changed.emit(str(_field.name),_error)

func _parse_number(text: String) -> Variant:
	var cleaned := text.replace(",",".").strip_edges()
	if not cleaned.is_valid_float():
		return null
	var value := cleaned.to_float()
	if not is_finite(value) or value<%Number.min_value or value>%Number.max_value or (int(_field.type)==TYPE_INT and value!=floorf(value)):
		return null
	return value

func _number_changed(value: float) -> void:
	if not _binding:
		_numeric_pending = false
		_error = ""
		_show_error()
		_emit(int(value) if int(_field.type)==TYPE_INT else value)
		validation_changed.emit(str(_field.name),_error)

func _number_text_changed(text: String) -> void:
	if not _binding:
		_numeric_pending = true
		_numeric_text = text
		_error = "Wpisz liczbę z dozwolonego zakresu." if _parse_number(text)==null else ""
		_show_error()
		validation_changed.emit(str(_field.name),_error)

func _choice_changed(index: int) -> void:
	if not _binding:
		_emit(%Choice.get_item_metadata(index))

func _toggle_changed(value: bool) -> void:
	if not _binding:
		_emit(value)

func _mapping_changed(value: Variant) -> void:
	if not _binding:
		_emit(value)

func _mapping_validation(error: String) -> void:
	_error = error
	_show_error()
	validation_changed.emit(str(_field.get("name","")),_error)

func _emit(value: Variant) -> void:
	%Changed.visible = value!=_field.get("value")
	value_changed.emit(str(_field.name),value)

func _show_error() -> void:
	%Error.text = _error
	%Error.visible = not _error.is_empty() and not %Mapping.visible
