class_name MapCameraController
extends Camera3D

@export var minimum_zoom := 4.0
@export var maximum_zoom := 90.0
@export_range(0.001, 0.02, 0.001) var orbit_sensitivity := 0.005

var _world_size := Vector2(65.5, 65.5)
var _orbit_center := Vector3.ZERO
var _focused := false
var _restoring := false
var _focus_point := Vector3.ZERO
var _saved_transform := Transform3D.IDENTITY
var _saved_size := 9.0
var _focus_size := 5.0

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

func begin_orbit(surface: Node3D) -> bool:
	var screen := get_viewport().get_visible_rect().size * 0.5
	var focus = GroundPicker3D.from_screen(self, screen, surface)
	if focus == null:
		focus = Plane(Vector3.UP, surface.global_position).intersects_ray(project_ray_origin(screen), project_ray_normal(screen))
	if focus == null:
		return false
	_orbit_center = focus
	return true

func orbit(horizontal_delta: float) -> void:
	var turn := Basis(Vector3.UP, -horizontal_delta * orbit_sensitivity)
	global_position = _orbit_center + turn * (global_position - _orbit_center)
	global_basis = (turn * global_basis).orthonormalized()

func zoom(direction: int, screen_position: Vector2, surface: Node3D) -> void:
	if _focused:
		_focus_size = clampf(_focus_size*pow(0.9,direction),minimum_zoom,12.0)
		return
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

func focus_on(point: Vector3) -> void:
	if not _focused:
		_saved_transform = global_transform
		_saved_size = size
		_focus_size = clampf(minf(size,5.0),minimum_zoom,maximum_zoom)
	_focused = true
	_restoring = false
	_focus_point = point
	set_process(true)

func track_focus(point: Vector3) -> void:
	_focus_point = point

func release_focus() -> void:
	if not _focused:
		return
	_focused = false
	_restoring = true
	set_process(true)

func begin_navigation() -> void:
	_restoring = false
	set_process(_focused)

func _process(delta: float) -> void:
	var weight := 1.0-exp(-8.0*delta)
	if _focused:
		global_position = global_position.lerp(_focus_point+global_basis.z*20.0+global_basis.x*0.55,weight)
		size = lerpf(size,_focus_size,weight)
	elif _restoring:
		global_position = global_position.lerp(_saved_transform.origin,weight)
		global_basis = global_basis.slerp(_saved_transform.basis,weight).orthonormalized()
		size = lerpf(size,_saved_size,weight)
		if global_position.distance_to(_saved_transform.origin) < 0.01 and absf(size-_saved_size) < 0.01:
			global_transform = _saved_transform
			size = _saved_size
			_restoring = false
			set_process(false)
	else:
		set_process(false)
