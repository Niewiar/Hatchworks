extends Node2D

@export var map_size := Vector2i(512, 512)
@export var painting_enabled := true:
	set(value):
		painting_enabled = value
		if is_node_ready():
			_apply_painting_mode()
@export_enum("Grass", "Dirt", "Moss", "Sand", "Rock") var selected_material: int = 1

@onready var terrain_controller: TerrainController = $Terrain
@onready var brush_controller: BrushController = $Brush

var _painting_active := false


func _ready() -> void:
	if not terrain_controller.initialize(map_size) or not brush_controller.is_ready_to_draw():
		return
	InputManager.on_lmb.connect(_on_lmb)
	InputManager.on_mouse_move.connect(_on_mouse_move)
	InputManager.on_mouse_scroll.connect(_on_mouse_scroll)
	_apply_painting_mode()


func _apply_painting_mode() -> void:
	_painting_active = false
	terrain_controller.end_stroke()
	brush_controller.activate_brush(painting_enabled)


func _on_lmb(pressed: bool) -> void:
	_painting_active = pressed and painting_enabled
	terrain_controller.end_stroke()
	if _painting_active:
		_paint_at_mouse()


func _on_mouse_move(_viewport_position: Vector2) -> void:
	if _painting_active and painting_enabled:
		_paint_at_mouse()


func _paint_at_mouse() -> void:
	terrain_controller.paint(
		selected_material, get_global_mouse_position(),
		brush_controller.brush_radius, brush_controller.brush_hardness
	)


func _on_mouse_scroll(direction: int) -> void:
	if painting_enabled:
		brush_controller.change_size(direction)
