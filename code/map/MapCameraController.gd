class_name MapCameraController
extends Camera3D

@export var minimum_zoom := 4.0
@export var maximum_zoom := 90.0

var _world_size := Vector2(65.5, 65.5)

func configure(world_size: Vector2) -> void:
	_world_size = world_size
	maximum_zoom = maxf(minimum_zoom, maxf(world_size.x, world_size.y) * 1.4)
	size = clampf(size, minimum_zoom, maximum_zoom)

func pan(previous: Vector2, current: Vector2, surface: Node3D) -> void:
	var from = GroundPicker3D.from_screen(self, previous, surface)
	var to = GroundPicker3D.from_screen(self, current, surface)
	if from != null and to != null:
		global_position += from - to
		_clamp_position(surface)

func zoom(direction: int, screen_position: Vector2, surface: Node3D) -> void:
	var before = GroundPicker3D.from_screen(self, screen_position, surface)
	size = clampf(size * pow(0.9, direction), minimum_zoom, maximum_zoom)
	var after = GroundPicker3D.from_screen(self, screen_position, surface)
	if before != null and after != null:
		global_position += before - after
		_clamp_position(surface)

func _clamp_position(surface: Node3D) -> void:
	var focus = GroundPicker3D.from_screen(self, get_viewport().get_visible_rect().size * 0.5, surface)
	if focus == null:
		return
	var local := surface.to_local(focus)
	local.x = clampf(local.x, -_world_size.x * 0.5, _world_size.x * 0.5)
	local.z = clampf(local.z, -_world_size.y * 0.5, _world_size.y * 0.5)
	global_position += surface.to_global(local) - focus
