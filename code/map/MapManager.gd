class_name  MapManager
extends Node2D

@export var map_size := Vector2i(512, 512)

@onready var terrain_controller: TerrainController = $Terrain
@onready var brush_controller: BrushController = $Brush

enum MODE {NONE, PAINT, BUILD}

var _mode: MODE = MODE.NONE
var _painting_active := false
var selected_material: int = 0 #"Grass", "Dirt", "Moss", "Sand", "Rock"

func set_mode(mode: MODE):
	_mode = mode
	brush_controller.activate(_mode == MODE.PAINT)

func _ready() -> void:
	if not terrain_controller.initialize(map_size):
		return
	InputManager.on_lmb.connect(_on_lmb)
	InputManager.on_mouse_move.connect(_on_mouse_move)
	InputManager.on_mouse_scroll.connect(_on_mouse_scroll)

func _on_lmb(pressed: bool) -> void:
	match _mode:
		MODE.NONE: 
			return
		MODE.PAINT:
			_painting_active = pressed
			terrain_controller.end_stroke()
			if _painting_active:
				_paint_at_mouse()
		MODE.BUILD:
			pass

func _on_mouse_move(_viewport_position: Vector2) -> void:
	if get_viewport().gui_get_hovered_control() != null:
		return
		
	if _painting_active and _painting_active:
		_paint_at_mouse()

func _paint_at_mouse() -> void:
	if get_viewport().gui_get_hovered_control() != null:
		return
	
	terrain_controller.paint(
		selected_material, get_global_mouse_position(),
		brush_controller.brush_radius, brush_controller.brush_hardness
	)

func _on_mouse_scroll(direction: int) -> void:
	if _mode == MODE.PAINT:
		brush_controller.change_size(direction)
