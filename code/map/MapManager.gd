class_name MapManager
extends Node3D

@export var map_size := Vector2i(512, 512)
@export var pixels_per_unit := 32.0
@export var camera_controller: MapCameraController

@onready var terrain_controller: TerrainController = $Terrain
@onready var brush_controller: BrushController = $Brush
@onready var fances_controller: FenceController = %Fances

enum MODE { NONE, PAINT, FANCE }

var _mode: MODE = MODE.NONE
var _painting_active := false
var _panning := false
var _last_pointer := Vector2.ZERO
var selected_material := 0

func _ready() -> void:
	if not terrain_controller.initialize(map_size, pixels_per_unit):
		return
	fances_controller.configure_world(pixels_per_unit, Rect2(-Vector2(map_size) * 0.5, Vector2(map_size)))
	if camera_controller != null:
		camera_controller.configure(terrain_controller.world_size)
	InputManager.on_lmb.connect(_on_lmb)
	InputManager.on_mmb.connect(_on_mmb)
	InputManager.on_mouse_move.connect(_on_mouse_move)
	InputManager.on_mouse_scroll.connect(_on_mouse_scroll)
	_last_pointer = get_viewport().get_mouse_position()

func set_mode(mode: MODE) -> void:
	_mode = mode
	_painting_active = false
	terrain_controller.end_stroke()
	brush_controller.activate(mode == MODE.PAINT)
	fances_controller.activate(mode == MODE.FANCE)

func select_fence(index: int) -> void:
	fances_controller.select_fence(index)

func _pointer_position(prefer_post: bool = false) -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var screen := get_viewport().get_mouse_position()
	if prefer_post:
		var post_id := fances_controller.get_post_at_screen(screen, camera)
		if post_id:
			return fances_controller.map_to_world(fances_controller.get_post(post_id).position)
	var point = GroundPicker3D.from_screen(camera, screen, terrain_controller)
	if point == null or not terrain_controller.contains_world_point(point):
		return null
	return point

func _on_lmb(pressed: bool) -> void:
	match _mode:
		MODE.PAINT:
			_painting_active = pressed and not _panning and get_viewport().gui_get_hovered_control() == null
			terrain_controller.end_stroke()
			if _painting_active:
				_paint_at_mouse()
		MODE.FANCE:
			var over_ui := get_viewport().gui_get_hovered_control() != null
			var point = _pointer_position(true)
			if pressed:
				if not over_ui and not _panning and point != null:
					fances_controller.begin_drawing(point)
			else:
				fances_controller.finish_drawing(point if point != null else Vector3.ZERO, not over_ui and not _panning and point != null)

func _on_mmb(pressed: bool) -> void:
	if pressed and get_viewport().gui_get_hovered_control() != null:
		return
	_panning = pressed
	_last_pointer = get_viewport().get_mouse_position()
	if pressed:
		_painting_active = false
		terrain_controller.end_stroke()

func _on_mouse_move(viewport_position: Vector2) -> void:
	if _panning and camera_controller != null:
		camera_controller.pan(_last_pointer, viewport_position, terrain_controller)
	_last_pointer = viewport_position
	if get_viewport().gui_get_hovered_control() != null:
		terrain_controller.end_stroke()
		return
	if not _panning and _mode == MODE.PAINT and _painting_active:
		_paint_at_mouse()

func _paint_at_mouse() -> void:
	if get_viewport().gui_get_hovered_control() != null:
		terrain_controller.end_stroke()
		return
	var point = _pointer_position()
	if point == null:
		terrain_controller.end_stroke()
		return
	terrain_controller.paint(selected_material, point, brush_controller.brush_radius, brush_controller.brush_hardness)

func _on_mouse_scroll(direction: int) -> void:
	if get_viewport().gui_get_hovered_control() != null:
		return
	if _mode == MODE.PAINT:
		brush_controller.change_size(direction)
	elif camera_controller != null:
		camera_controller.zoom(direction, get_viewport().get_mouse_position(), terrain_controller)
