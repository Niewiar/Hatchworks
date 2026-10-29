class_name CreatureNavigation
extends Node

signal navigation_changed

@export_range(0.25, 1.0, 0.25) var cell_size := 0.5

var _map: Node3D
var _astar: AStarGrid2D
var _building: AStarGrid2D
var _size := Vector2i.ZERO
var _extent := Vector2.ZERO
var _depths := PackedFloat32Array()
var _ids := PackedInt32Array()
var _cursor := -1
var _pending := false
var _delay := 0.0
var ready_for_paths := false
var revision := 0

func initialize(map: Node3D) -> void:
	_map = map
	_size = Vector2i(ceil(map.terrain_controller.world_size/cell_size))
	_extent = map.terrain_controller.world_size/Vector2(_size)
	map.regions_controller.regions_changed.connect(_queue_rebuild)
	map.terrain_controller.height_changed.connect(_queue_rebuild)
	map.water_controller.water_level_changed.connect(_queue_rebuild)
	map.vegetation_controller.obstacles_changed.connect(_queue_rebuild)
	map.rock_controller.obstacles_changed.connect(_queue_rebuild)
	map.building_controller.obstacles_changed.connect(_queue_rebuild)
	_queue_rebuild()

func _queue_rebuild() -> void:
	ready_for_paths = false
	_pending = true
	_delay = 0.15
	set_process(true)

func _process(delta: float) -> void:
	if _cursor < 0:
		if not _pending:
			set_process(false)
			return
		_delay -= delta
		if _delay > 0.0 or _map.regions_controller._rebuild_pending:
			return
		_pending = false
		_cursor = 0
		_building = AStarGrid2D.new()
		_building.region = Rect2i(Vector2i.ZERO,_size)
		_building.cell_size = _extent
		_building.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_building.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_building.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_building.update()
		_depths.resize(_size.x*_size.y)
		_ids.resize(_size.x*_size.y)
	var deadline := Time.get_ticks_usec()+1800
	while _cursor < _size.x*_size.y and Time.get_ticks_usec() < deadline:
		var cell := Vector2i(_cursor%_size.x,_cursor/_size.x)
		var world := cell_position(cell)
		var id: int = _map.regions_controller.region_id_at(world)
		_ids[_cursor] = id
		_depths[_cursor] = _map.water_controller.water_level-_map.terrain_controller.to_local(world).y
		var blocked: bool = id <= 0 or _map.terrain_controller.slope_at(world) > 1.0
		for offset in [Vector3(0.4,0,0),Vector3(-0.4,0,0),Vector3(0,0,0.4),Vector3(0,0,-0.4)]:
			if not blocked and _map.regions_controller.region_id_at(world+offset) != id:
				blocked = true
		var local: Vector3 = _map.terrain_controller.to_local(world)
		blocked = blocked or _map.vegetation_controller.occupied(Vector2(local.x,local.z),0.65) or _map.rock_controller.occupied(world,0.5)
		blocked = blocked or _map.building_controller.occupied(world,0.2)
		_building.set_point_solid(cell,blocked)
		_cursor += 1
	if _cursor == _size.x*_size.y:
		_cursor = -1
		_astar = _building
		revision += 1
		ready_for_paths = not _pending
		navigation_changed.emit()

func cell_position(cell: Vector2i) -> Vector3:
	var point: Vector2 = (Vector2(cell)+Vector2(0.5,0.5))*_extent-_map.terrain_controller.world_size*0.5
	return _map.terrain_controller.surface_position(_map.terrain_controller.to_global(Vector3(point.x,0,point.y)))

func _cell(world: Vector3) -> Vector2i:
	var local: Vector3 = _map.terrain_controller.to_local(world)
	return Vector2i(((Vector2(local.x,local.z)+_map.terrain_controller.world_size*0.5)/_extent).floor()).clamp(Vector2i.ZERO,_size-Vector2i.ONE)

func _open_near(cell: Vector2i) -> Vector2i:
	var region_id := _ids[cell.y*_size.x+cell.x]
	if region_id <= 0:
		return Vector2i(-1,-1)
	if not _astar.is_point_solid(cell):
		return cell
	for radius in range(1,5):
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				var next := cell+Vector2i(x,y)
				if _astar.region.has_point(next) and not _astar.is_point_solid(next) and _ids[next.y*_size.x+next.x] == region_id:
					var start := cell_position(cell)
					var end := cell_position(next)
					var steps := ceili(start.distance_to(end)/0.1)
					var clear := true
					for step in range(1,steps+1):
						if _map.regions_controller.region_id_at(start.lerp(end,float(step)/steps)) != region_id:
							clear = false
							break
					if clear:
						return next
	return Vector2i(-1,-1)

func path_to(from: Vector3, destination: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	if not ready_for_paths:
		return result
	var first := _open_near(_cell(from))
	var last := _cell(destination)
	if first.x < 0 or _astar.is_point_solid(last) or _ids[first.y*_size.x+first.x] != _ids[last.y*_size.x+last.x]:
		return result
	for cell in _astar.get_id_path(first,last):
		result.append(cell_position(cell))
	return result

func route_to_water(from: Vector3, minimum_depth: float) -> PackedVector3Array:
	return _find_route(from,true,minimum_depth)

func route_to_sowing_ground(from: Vector3) -> PackedVector3Array:
	return _find_route(from,false,0.0)

func _find_route(from: Vector3, water: bool, minimum_depth: float) -> PackedVector3Array:
	if not ready_for_paths:
		return PackedVector3Array()
	var first := _open_near(_cell(from))
	if first.x < 0:
		return PackedVector3Array()
	var region_id := _ids[first.y*_size.x+first.x]
	var candidates: Array[Vector2i] = []
	for index in _depths.size():
		if _ids[index] != region_id or (water and _depths[index] < minimum_depth) or (not water and _depths[index] > -0.03):
			continue
		var cell := Vector2i(index%_size.x,index/_size.x)
		if not _astar.is_point_solid(cell):
			candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i,b: Vector2i): return first.distance_squared_to(a) < first.distance_squared_to(b))
	var attempts := 0
	for cell in candidates:
		var point := cell_position(cell)
		if not water and not _map.vegetation_controller.can_seed_grass(point):
			continue
		var path := path_to(from,point)
		if not path.is_empty():
			return path
		attempts += 1
		if attempts >= 24:
			break
	return PackedVector3Array()

func spawn_position(around: Vector3) -> Variant:
	if not ready_for_paths:
		return null
	for index in 16:
		var point := around+Vector3(cos(index*TAU/16),0,sin(index*TAU/16))*2.2
		var cell := _cell(point)
		if not _astar.is_point_solid(cell) and _depths[cell.y*_size.x+cell.x] < -0.05:
			return cell_position(cell)+Vector3.UP*0.6
	return null

func route_to_feeder(from: Vector3, species: CreatureSpecies) -> Dictionary:
	var nearest := INF
	var result := {}
	for building in _map.building_controller.get_buildings():
		if not building is FeederController or not building.can_feed(species):
			continue
		for point in building.feeding_positions():
			if _map.water_controller.global_position.y >= _map.terrain_controller.surface_position(point).y:
				continue
			var path := path_to(from,point)
			if path.is_empty():
				continue
			var length := 0.0
			for index in range(1,path.size()):
				length += path[index-1].distance_to(path[index])
			if length < nearest:
				nearest = length
				result = {"feeder":building,"path":path}
	return result
