@tool
extends Window

signal asset_saved(path: String)

const Processor = preload("atlas_processor.gd")
enum OutputType { TEXTURE_ARRAY, PNG_ATLAS }

var _source_path := ""
var _source_image: Image
var _processed: Dictionary = {}
var _pending_resource: Texture2DArray
var _pending_image: Image
var _pending_format: int = OutputType.TEXTURE_ARRAY
var _last_output_dir := ""

@onready var _path_field: LineEdit = %PathField
@onready var _tile_width: SpinBox = %TileWidth
@onready var _tile_height: SpinBox = %TileHeight
@onready var _gap: SpinBox = %Gap
@onready var _margin: SpinBox = %Margin
@onready var _format: OptionButton = %Format
@onready var _summary: Label = %Summary
@onready var _status: Label = %Status
@onready var _source_preview: TextureRect = %SourcePreview
@onready var _output_preview: TextureRect = %OutputPreview
@onready var _save_button: Button = %Save
@onready var _source_dialog: FileDialog = $SourceDialog
@onready var _save_dialog: FileDialog = $SaveDialog
@onready var _refresh_timer: Timer = $RefreshTimer


func _choose_source() -> void:
	_source_dialog.current_dir = _source_path.get_base_dir() if not _source_path.is_empty() else ProjectSettings.globalize_path("res://")
	_source_dialog.popup_centered_ratio(0.8)


func _load_source(path: String) -> void:
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		_status.text = "Could not load image: %s." % error_string(error)
		return
	_source_path = path
	_source_image = image
	_path_field.text = path
	_path_field.tooltip_text = path
	_source_preview.texture = ImageTexture.create_from_image(image)
	_refresh_timer.stop()
	_refresh_preview()


func _settings_changed(_value: float) -> void:
	_save_button.disabled = true
	_refresh_timer.start()


func _refresh_preview() -> void:
	_status.text = ""
	_processed = Processor.pack_image(_source_image, Vector2i(int(_tile_width.value), int(_tile_height.value)), int(_gap.value), int(_margin.value))
	_save_button.disabled = not _processed.ok
	if not _processed.ok:
		_output_preview.texture = null
		_summary.text = _processed.error
		return
	_output_preview.texture = ImageTexture.create_from_image(_processed.image)
	_summary.text = "Source: %d × %d px  |  Grid: %d × %d  |  Layers: %d\nPacked PNG: %d × %d px  |  Array layer: %d × %d px. Layers ordered left to right, row by row." % [_source_image.get_width(), _source_image.get_height(), _processed.columns, _processed.rows, _processed.layers, _processed.output_size.x, _processed.output_size.y, _processed.tile_size.x, _processed.tile_size.y]


func _create_and_choose_path() -> void:
	_refresh_timer.stop()
	_refresh_preview()
	if not _processed.ok:
		return
	_clear_pending()
	_pending_format = _format.get_selected_id()
	_save_dialog.current_dir = _last_output_dir if not _last_output_dir.is_empty() else ProjectSettings.globalize_path("res://")
	if _pending_format == OutputType.TEXTURE_ARRAY:
		var result := Processor.create_array(_processed.tiles)
		if not result.ok:
			_status.text = result.error
			return
		_pending_resource = result.resource
		_save_dialog.filters = PackedStringArray(["*.res;Texture2DArray"])
		_save_dialog.current_file = _source_path.get_file().get_basename() + "_array.res"
	else:
		_pending_image = _processed.image
		_save_dialog.filters = PackedStringArray(["*.png;PNG"])
		_save_dialog.current_file = _source_path.get_file().get_basename() + "_packed.png"
	_save_dialog.popup_centered_ratio(0.8)


func _save_selected(path: String) -> void:
	var extension := "res" if _pending_format == OutputType.TEXTURE_ARRAY else "png"
	if path.get_extension().is_empty():
		path += "." + extension
	if path.get_extension().to_lower() != extension:
		_status.text = "Choose a filename with the .%s extension." % extension
		_clear_pending()
		return
	var target := ProjectSettings.globalize_path(path).simplify_path()
	var source := ProjectSettings.globalize_path(_source_path).simplify_path()
	if OS.has_feature("windows"):
		target = target.to_lower()
		source = source.to_lower()
	if target == source:
		_status.text = "Choose a different filename. The source texture cannot be overwritten."
		_clear_pending()
		return
	var error := ERR_INVALID_DATA
	if _pending_format == OutputType.TEXTURE_ARRAY and _pending_resource != null:
		error = ResourceSaver.save(_pending_resource, path, ResourceSaver.FLAG_COMPRESS)
	elif _pending_format == OutputType.PNG_ATLAS and _pending_image != null:
		error = _pending_image.save_png(path)
	_clear_pending()
	if error != OK:
		_status.text = "Could not save texture: %s." % error_string(error)
		return
	_last_output_dir = path.get_base_dir()
	_status.text = "Saved: " + path
	asset_saved.emit(path)


func _clear_pending() -> void:
	_pending_resource = null
	_pending_image = null
