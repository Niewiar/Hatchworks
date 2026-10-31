class_name MapCameraController
extends Camera3D

signal moved(distance: float)
signal rotated(angle: float)
signal focus_changed(focused: bool)

@export var minimum_zoom := 4.0
@export var maximum_zoom := 90.0
@export var focus_minimum_zoom := 1.6
@export var focus_maximum_zoom := 5.0
@export var focus_start_zoom := 3.2
@export_range(1.0, 2.0, 0.05) var focus_release_zoom_factor := 1.2
@export_range(0.001, 0.02, 0.001) var orbit_sensitivity := 0.005

var _world_size := Vector2(65.5, 65.5)
var _orbit_center := Vector3.ZERO
var _focused := false
var _releasing := false
var _focus_point := Vector3.ZERO
var _release_size := 4.0
var _focus_size := 5.0

func configure(world_size: Vector2) -> void:
	_world_size = world_size
	maximum_zoom = maxf(minimum_zoom, maxf(world_size.x, world_size.y) * 1.4)
	size = clampf(size, minimum_zoom, maximum_zoom)

func pan(previous: Vector2, current: Vector2, surface: Node3D) -> void:
	if _focused:
		return
	begin_navigation()
	var from = GroundPicker3D.from_screen(self, previous, surface)
	var to = GroundPicker3D.from_screen(self, current, surface)
	if from != null and to != null:
		var previous_position := global_position
		global_position += from - to
		_clamp_position(surface)
		moved.emit(global_position.distance_to(previous_position))

func pan_direction(direction: Vector2, delta: float, surface: Node3D) -> void:
	if _focused or direction.is_zero_approx():
		return
	begin_navigation()
	var right := Vector3(global_basis.x.x,0,global_basis.x.z).normalized()
	var down := Vector3(global_basis.z.x,0,global_basis.z.z).normalized()
	var previous_position := global_position
	global_position += (right*direction.x+down*direction.y)*maxf(size*0.65,3.0)*delta
	_clamp_position(surface)
	moved.emit(global_position.distance_to(previous_position))

func begin_orbit(surface: Node3D) -> bool:
	if _focused:
		return true
	var screen := get_viewport().get_visible_rect().size * 0.5
	var focus = GroundPicker3D.from_screen(self, screen, surface)
	if focus == null:
		focus = Plane(Vector3.UP, surface.global_position).intersects_ray(project_ray_origin(screen), project_ray_normal(screen))
	if focus == null:
		return false
	_orbit_center = focus
	return true

func orbit(horizontal_delta: float) -> void:
	if not _focused:
		begin_navigation()
	var turn := Basis(Vector3.UP, -horizontal_delta * orbit_sensitivity)
	var center := _focus_point if _focused else _orbit_center
	global_position = center + turn * (global_position - center)
	global_basis = (turn * global_basis).orthonormalized()
	rotated.emit(-horizontal_delta * orbit_sensitivity)

func zoom(direction: int, screen_position: Vector2, surface: Node3D) -> void:
	if _focused:
		_focus_size = clampf(_focus_size * pow(0.9,direction),focus_minimum_zoom,focus_maximum_zoom)
		return
	begin_navigation()
	var before = GroundPicker3D.from_screen(self, screen_position, surface)
	size = clampf(size * pow(0.9, direction), minf(size,minimum_zoom), maximum_zoom)
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

func focus_on(point: Vector3) -> void:
	if not _focused:
		_focus_size = clampf(focus_start_zoom,focus_minimum_zoom,focus_maximum_zoom)
	_focused = true
	focus_changed.emit(true)
	_releasing = false
	_focus_point = point
	global_position = _focus_point+global_basis.z*20.0
	set_process(true)

func track_focus(point: Vector3) -> void:
	_focus_point = point
	if _focused:
		global_position = _focus_point+global_basis.z*20.0

func release_focus() -> void:
	if not _focused:
		return
	_focused = false
	focus_changed.emit(false)
	_release_size = clampf(size*focus_release_zoom_factor,focus_minimum_zoom,maximum_zoom)
	_releasing = true
	set_process(true)

func begin_navigation() -> void:
	_releasing = false
	set_process(_focused)

func _process(delta: float) -> void:
	var weight := 1.0-exp(-8.0*delta)
	if _focused:
		global_position = _focus_point+global_basis.z*20.0
		size = lerpf(size,_focus_size,weight)
	elif _releasing:
		size = lerpf(size,_release_size,weight)
		if absf(size-_release_size) < 0.01:
			size = _release_size
			_releasing = false
			set_process(false)
	else:
		set_process(false)

func capture_view() -> Dictionary:
	var saved_size := clampf(size*focus_release_zoom_factor,focus_minimum_zoom,maximum_zoom) if _focused else (_release_size if _releasing else size)
	return {"transform":global_transform,"size":saved_size}

func restore_view(value: Dictionary) -> void:
	_focused = false
	focus_changed.emit(false)
	_releasing = false
	if value.get("transform") is Transform3D:
		global_transform = value.transform
	size = clampf(float(value.get("size",size)),focus_minimum_zoom,maximum_zoom)
	set_process(false)
