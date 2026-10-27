class_name MapCameraController
extends Node3D

@export var minimum_zoom := 8.0
@export var maximum_zoom := 90.0
@onready var camera: Camera3D = $Camera3D

var _world_size := Vector2(65.5, 65.5)

func configure(world_size: Vector2) -> void:
	_world_size = world_size
	maximum_zoom = maxf(minimum_zoom, maxf(world_size.x, world_size.y) * 1.4)

func pan(previous: Vector2, current: Vector2, surface: Node3D) -> void:
	var from = GroundPicker3D.from_screen(camera, previous, surface)
	var to = GroundPicker3D.from_screen(camera, current, surface)
	if from != null and to != null:
		global_position += from - to
		_clamp_position()

func zoom(direction: int, screen_position: Vector2, surface: Node3D) -> void:
	var before = GroundPicker3D.from_screen(camera, screen_position, surface)
	camera.size = clampf(camera.size * pow(0.9, direction), minimum_zoom, maximum_zoom)
	var after = GroundPicker3D.from_screen(camera, screen_position, surface)
	if before != null and after != null:
		global_position += before - after
		_clamp_position()

func _clamp_position() -> void:
	position.x = clampf(position.x, -_world_size.x * 0.5, _world_size.x * 0.5)
	position.z = clampf(position.z, -_world_size.y * 0.5, _world_size.y * 0.5)
