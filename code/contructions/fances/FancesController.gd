class_name FenceController
extends Node3D

signal network_changed
signal selection_changed(index: int)
signal span_damaged(span_id: int, health: float)

const FANCES_DATABASE = preload("res://code/contructions/fances/FancesDatabase.tres")
const SPAN_SCENE = preload("res://scenes/constructions/fance_representation.tscn")
const MERGE_DISTANCE := 0.5
const PREVIEW_SHADER = preload("res://code/contructions/fances/fence_preview.gdshader")

@export var pixels_per_unit := 32.0
var map_bounds := Rect2(-1048, -1048, 2096, 2096)
var _preview_material: ShaderMaterial
var _terrain: TerrainController

@export_range(4.0, 32.0, 1.0) var snap_radius := 14.0
@export_range(2.0, 32.0, 1.0) var minimum_length := 8.0

var selected_fance := 0
var _posts: Dictionary[int, FencePostState] = {}
var _spans: Dictionary[int, FenceSpanState] = {}
var _post_views: Dictionary[int, FencePostView] = {}
var _span_views: Dictionary[int, Node3D] = {}
var _next_post_id := 1
var _next_span_id := 1
var _built_root: Node3D
var _preview_root: Node3D
var _preview_posts: Array[FencePostView] = []
var _preview_spans: Array[Node3D] = []
var _drawing := false
var _start_position := Vector2.ZERO
var _pending_points := PackedVector2Array()
var _preview_valid := false
var _preview_dirty := true
var _last_mouse := Vector2.INF
var _hovered_post_id := 0

func _ready() -> void:
	_preview_material = ShaderMaterial.new()
	_preview_material.shader = PREVIEW_SHADER
	_built_root = Node3D.new()
	_built_root.name = "Built"
	add_child(_built_root)
	_preview_root = Node3D.new()
	_preview_root.name = "Preview"
	add_child(_preview_root)
	set_process(false)

func _process(_delta: float) -> void:
	if get_viewport().gui_get_hovered_control() != null:
		_preview_root.hide()
		_set_hovered_post(0)
		return
	var target = _cursor_map_position()
	if target == null:
		_preview_root.hide()
		_set_hovered_post(0)
		return
	_preview_root.show()
	if _preview_dirty or target != _last_mouse:
		_update_preview_at(target)

func activate(active: bool) -> void:
	_drawing = false
	_pending_points.clear()
	_set_hovered_post(0)
	_preview_root.visible = active
	set_process(active)
	_preview_dirty = true
	if active:
		var target = _cursor_map_position()
		if target != null:
			_update_preview_at(target)

func select_fence(index: int) -> void:
	if index < 0 or index >= FANCES_DATABASE.fances.size():
		return
	selected_fance = index
	_drawing = false
	_preview_dirty = true
	if is_processing():
		var target = _cursor_map_position()
		if target != null:
			_update_preview_at(target)
	selection_changed.emit(index)

func begin_drawing(world_position: Vector3) -> void:
	if not is_processing():
		return
	var local_position := world_to_map(world_position)
	var post_id := _find_post_at(local_position)
	_start_position = _posts[post_id].position if post_id else local_position
	_drawing = true
	_update_preview_at(local_position)

func finish_drawing(world_position: Vector3, commit: bool = true) -> Array[int]:
	var created: Array[int] = []
	if not _drawing:
		return created
	_update_preview_at(world_to_map(world_position))
	if commit and _preview_valid:
		var points := _pending_points.duplicate()
		var data: FanceData = FANCES_DATABASE.fances[selected_fance]
		var ids: Array[int] = []
		for point in points:
			ids.append(_ensure_post(point, data))
		for index in range(ids.size() - 1):
			created.append(_add_span(ids[index], ids[index + 1], data))
		_finish_edit()
	_drawing = false
	_preview_dirty = true
	_update_preview_at(world_to_map(world_position))
	return created

func get_posts() -> Array:
	return _posts.values()

func get_spans() -> Array:
	return _spans.values()

func get_post(post_id: int) -> FencePostState:
	return _posts.get(post_id) as FencePostState

func damage_span(span_id: int, amount: float) -> bool:
	if not _spans.has(span_id) or amount <= 0.0:
		return false
	var span := _spans[span_id]
	span.health = maxf(0.0, span.health - amount)
	span_damaged.emit(span_id, span.health)
	if span.health <= 0.0:
		return remove_span(span_id)
	_span_views[span_id].refresh()
	return true

func damage_post(post_id: int, amount: float) -> bool:
	if not _posts.has(post_id) or amount <= 0.0:
		return false
	var post := _posts[post_id]
	post.health = maxf(0.0, post.health - amount)
	if post.health <= 0.0:
		return remove_post(post_id)
	_post_views[post_id].refresh()
	return true

func remove_span(span_id: int) -> bool:
	if not _spans.has(span_id):
		return false
	_remove_span_internal(span_id)
	_finish_edit()
	return true

func remove_post(post_id: int) -> bool:
	if not _posts.has(post_id):
		return false
	var connected := _posts[post_id].span_ids.duplicate()
	for span_id in connected:
		_remove_span_internal(span_id)
	_finish_edit()
	return true

func _find_post_at(point: Vector2) -> int:
	var best_id := 0
	var best_distance := snap_radius * snap_radius
	for post: FencePostState in _posts.values():
		var distance := point.distance_squared_to(post.position)
		if distance < best_distance:
			best_distance = distance
			best_id = post.id
	return best_id

func _find_exact_post(point: Vector2) -> int:
	for post: FencePostState in _posts.values():
		if post.position.distance_squared_to(point) <= MERGE_DISTANCE * MERGE_DISTANCE:
			return post.id
	return 0

func _set_hovered_post(post_id: int) -> void:
	if post_id == _hovered_post_id:
		return
	if _post_views.has(_hovered_post_id):
		_post_views[_hovered_post_id].set_highlighted(false)
	_hovered_post_id = post_id
	if _post_views.has(post_id):
		_post_views[post_id].set_highlighted(true)

func _update_preview_at(mouse: Vector2) -> void:
	_last_mouse = mouse
	_preview_dirty = false
	var post_id := _find_post_at(mouse)
	_set_hovered_post(post_id)
	var target := _posts[post_id].position if post_id else mouse
	var data: FanceData = FANCES_DATABASE.fances[selected_fance]
	_pending_points = _make_path(_start_position, target, data.max_span_length) if _drawing else PackedVector2Array([target])
	_preview_valid = _drawing and _pending_points.size() > 1 and not _is_path_blocked(_pending_points[0], _pending_points[-1])
	_preview_material.set_shader_parameter("valid", not _drawing or _preview_valid)
	_update_preview_views(data)

func _make_path(start: Vector2, end: Vector2, spacing: float) -> PackedVector2Array:
	if start.distance_to(end) < minimum_length:
		return PackedVector2Array([start])
	var reversed := start.x > end.x or (start.x == end.x and start.y > end.y)
	if reversed:
		var swap := start
		start = end
		end = swap
	var delta := end - start
	var anchors: Array[Vector2] = [start, end]
	for post: FencePostState in _posts.values():
		var closest := Geometry2D.get_closest_point_to_segment(post.position, start, end)
		if closest.distance_to(post.position) <= MERGE_DISTANCE:
			anchors.append(post.position)
	anchors.sort_custom(func(first, second): return (first - start).dot(delta) < (second - start).dot(delta))
	var unique: Array[Vector2] = []
	for point in anchors:
		if unique.is_empty() or unique[-1].distance_to(point) > MERGE_DISTANCE:
			unique.append(point)
	var points := PackedVector2Array([unique[0]])
	for index in range(unique.size() - 1):
		var count := maxi(1, ceili(unique[index].distance_to(unique[index + 1]) / maxf(spacing, minimum_length)))
		for division in range(1, count + 1):
			points.append(unique[index].lerp(unique[index + 1], float(division) / count))
	if reversed:
		points.reverse()
	return points

func _is_path_blocked(start: Vector2, end: Vector2) -> bool:
	var direction := (end - start).normalized()
	var length := start.distance_to(end)
	for span: FenceSpanState in _spans.values():
		var first := _posts[span.start_post_id].position
		var last := _posts[span.end_post_id].position
		var first_offset := first - start
		var last_offset := last - start
		if absf(first_offset.cross(direction)) <= MERGE_DISTANCE and absf(last_offset.cross(direction)) <= MERGE_DISTANCE:
			var left := minf(first_offset.dot(direction), last_offset.dot(direction))
			var right := maxf(first_offset.dot(direction), last_offset.dot(direction))
			if minf(length, right) - maxf(0.0, left) > MERGE_DISTANCE:
				return true
		if _touches_segment_interior(start, first, last) or _touches_segment_interior(end, first, last):
			return true
		if _touches_segment_interior(first, start, end) or _touches_segment_interior(last, start, end):
			return true
		var hit = Geometry2D.segment_intersects_segment(start, end, first, last)
		if hit == null:
			continue
		var at_path_end: bool = hit.distance_to(start) <= MERGE_DISTANCE or hit.distance_to(end) <= MERGE_DISTANCE
		var at_post: bool = hit.distance_to(first) <= MERGE_DISTANCE or hit.distance_to(last) <= MERGE_DISTANCE
		if not at_path_end or not at_post:
			return true
	return false

func _touches_segment_interior(point: Vector2, first: Vector2, last: Vector2) -> bool:
	var closest := Geometry2D.get_closest_point_to_segment(point, first, last)
	return point.distance_to(closest) <= MERGE_DISTANCE and closest.distance_to(first) > MERGE_DISTANCE and closest.distance_to(last) > MERGE_DISTANCE

func _update_preview_views(data: FanceData) -> void:
	while _preview_posts.size() < _pending_points.size():
		var view := FencePostView.new()
		view.preview_mode = true
		view.material_override = _preview_material
		_preview_root.add_child(view)
		_preview_posts.append(view)
	while _preview_spans.size() < maxi(0, _pending_points.size() - 1):
		var view := SPAN_SCENE.instantiate() as Node3D
		view.preview_mode = true
		view.material_override = _preview_material
		_preview_root.add_child(view)
		_preview_spans.append(view)
	for index in _preview_posts.size():
		var view := _preview_posts[index]
		view.visible = index < _pending_points.size()
		if not view.visible:
			continue
		var existing_id := _find_exact_post(_pending_points[index])
		if existing_id and _posts[existing_id].data.post_priority >= data.post_priority:
			view.hide()
			continue
		var state := FencePostState.new()
		state.position = _pending_points[index]
		state.data = data
		state.health = data.post_max_health
		view.configure(state, pixels_per_unit, _post_rotation_at(state.position, _pending_points), _terrain)
	for index in _preview_spans.size():
		var view := _preview_spans[index]
		view.visible = index < _pending_points.size() - 1
		if view.visible:
			var state := FenceSpanState.new()
			state.data = data
			state.health = data.max_health
			view.configure(state, _pending_points[index], _pending_points[index + 1], pixels_per_unit, _terrain)

func _ensure_post(point: Vector2, data: FanceData) -> int:
	var existing := _find_exact_post(point)
	if existing:
		return existing
	var post := FencePostState.new()
	post.id = _next_post_id
	_next_post_id += 1
	post.position = point
	post.data = data
	post.health = data.post_max_health
	_posts[post.id] = post
	var view := FencePostView.new()
	_built_root.add_child(view)
	_post_views[post.id] = view
	view.configure(post, pixels_per_unit, 0.0, _terrain)
	return post.id

func _add_span(start_id: int, end_id: int, data: FanceData, integrity: float = 1.0) -> int:
	if start_id == end_id:
		return 0
	for span_id in _posts[start_id].span_ids:
		var existing := _spans[span_id]
		if existing.start_post_id == end_id or existing.end_post_id == end_id:
			return span_id
	var span := FenceSpanState.new()
	span.id = _next_span_id
	_next_span_id += 1
	span.start_post_id = start_id
	span.end_post_id = end_id
	span.data = data
	span.health = data.max_health * integrity
	_spans[span.id] = span
	_posts[start_id].span_ids.append(span.id)
	_posts[end_id].span_ids.append(span.id)
	var view := SPAN_SCENE.instantiate() as Node3D
	_built_root.add_child(view)
	_span_views[span.id] = view
	view.configure(span, _posts[start_id].position, _posts[end_id].position, pixels_per_unit, _terrain)
	return span.id

func _remove_span_internal(span_id: int) -> void:
	var span := _spans[span_id]
	_posts[span.start_post_id].span_ids.erase(span_id)
	_posts[span.end_post_id].span_ids.erase(span_id)
	_span_views[span_id].hide()
	_span_views[span_id].queue_free()
	_span_views.erase(span_id)
	_spans.erase(span_id)

func _finish_edit() -> void:
	for post_id in _posts.keys():
		var post := _posts[post_id]
		if post.span_ids.is_empty():
			_post_views[post_id].hide()
			_post_views[post_id].queue_free()
			_post_views.erase(post_id)
			_posts.erase(post_id)
			continue
		var best: FanceData = _spans[post.span_ids[0]].data
		for span_id in post.span_ids:
			var candidate := _spans[span_id].data
			if candidate.post_priority > best.post_priority or (candidate.post_priority == best.post_priority and String(candidate.id) < String(best.id)):
				best = candidate
		var integrity := post.integrity()
		post.data = best
		post.health = best.post_max_health * integrity
		_post_views[post_id].configure(post, pixels_per_unit, _post_rotation_at(post.position), _terrain)
	_preview_dirty = true
	network_changed.emit()

func _post_rotation_at(point: Vector2, preview_path := PackedVector2Array()) -> float:
	var directions: Array[Vector2] = []
	var post_id := _find_exact_post(point)
	if post_id:
		for span_id in _posts[post_id].span_ids:
			var span := _spans[span_id]
			var other_id := span.end_post_id if span.start_post_id == post_id else span.start_post_id
			_append_post_direction(directions, _posts[other_id].position - point)
	for index in preview_path.size():
		if point.distance_to(preview_path[index]) > MERGE_DISTANCE:
			continue
		if index > 0:
			_append_post_direction(directions, preview_path[index - 1] - point)
		if index + 1 < preview_path.size():
			_append_post_direction(directions, preview_path[index + 1] - point)
	if directions.is_empty():
		return 0.0
	var angle := fposmod(directions[0].angle(), PI)
	var best_dot := 2.0
	for first in range(directions.size() - 1):
		for last in range(first + 1, directions.size()):
			var dot := directions[first].dot(directions[last])
			var candidate := fposmod((directions[first] - directions[last]).angle(), PI)
			if candidate > PI - 0.00001:
				candidate = 0.0
			if dot < best_dot - 0.00001 or (absf(dot - best_dot) <= 0.00001 and candidate < angle):
				best_dot = dot
				angle = candidate
	return -angle if angle <= PI * 0.5 else PI - angle

func _append_post_direction(directions: Array[Vector2], delta: Vector2) -> void:
	if delta.length_squared() <= MERGE_DISTANCE * MERGE_DISTANCE:
		return
	var direction := delta.normalized()
	for existing in directions:
		if existing.dot(direction) > 0.99999:
			return
	directions.append(direction)

func configure_world(pixel_density: float, bounds: Rect2) -> void:
	pixels_per_unit = pixel_density
	map_bounds = bounds

func world_to_map(world_position: Vector3) -> Vector2:
	var local := to_local(world_position)
	return Vector2(local.x, local.z) * pixels_per_unit

func map_to_world(point: Vector2) -> Vector3:
	var world := to_global(Vector3(point.x, 0, point.y) / pixels_per_unit)
	return _terrain.surface_position(world) if _terrain != null else world

func get_post_at_screen(screen_position: Vector2, camera: Camera3D) -> int:
	if camera == null:
		return 0
	var best_id := 0
	var best_distance := INF
	var best_depth := INF
	for post: FencePostState in _posts.values():
		var base := map_to_world(post.position)
		if camera.is_position_behind(base):
			continue
		var top := base + global_basis.y * ((post.data.height + 3) / pixels_per_unit)
		var first := camera.unproject_position(base)
		var last := camera.unproject_position(top)
		var closest := Geometry2D.get_closest_point_to_segment(screen_position, first, last)
		var distance := screen_position.distance_squared_to(closest)
		var side := camera.unproject_position(base + camera.global_basis.x * ((post.data.post_width + 4) * 0.5 / pixels_per_unit))
		var radius := maxf(6, first.distance_to(side) + 4)
		var depth := camera.global_position.distance_squared_to(base)
		if distance <= radius * radius and (distance < best_distance - 1 or (absf(distance - best_distance) <= 1 and depth < best_depth)):
			best_id = post.id
			best_distance = distance
			best_depth = depth
	return best_id

func _cursor_map_position() -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var screen := get_viewport().get_mouse_position()
	var post_id := get_post_at_screen(screen, camera)
	if post_id:
		return _posts[post_id].position
	var point = GroundPicker3D.from_screen(camera, screen, _terrain if _terrain != null else self)
	if point == null:
		return null
	var local := world_to_map(point)
	return local if map_bounds.has_point(local) else null

func configure_surface(terrain: TerrainController) -> void:
	_terrain = terrain
	_terrain.height_changed.connect(_update_ground)

func _update_ground() -> void:
	for view: FencePostView in _post_views.values():
		view.refresh()
	for view: Node3D in _span_views.values():
		view.refresh()
	_preview_dirty = true
