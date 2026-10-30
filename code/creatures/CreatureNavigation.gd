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
var _building_depths := PackedFloat32Array()
var _building_ids := PackedInt32Array()
var _snapshot: Dictionary = {}
var _snapshot_blockers: Dictionary[Vector2i,Array] = {}
var _failed_places: Dictionary[Creature,Array] = {}
var _cursor := -1
var _pending := false
var _delay := 0.0
var ready_for_paths := false
var revision := 0
var _actors: Array[Creature] = []
var _claims: Dictionary[Creature,Vector3] = {}
var _buckets: Dictionary[Vector2i,Array] = {}
var _traffic_frame := -1
var _intentions: Dictionary[Creature,Vector2] = {}
var _traffic_intentions: Dictionary[Creature,Vector2] = {}
var _traffic_velocities: Dictionary[Creature,Vector2] = {}
var _traffic_positions: Dictionary[Creature,Vector3] = {}
var _priorities: Dictionary[Creature,int] = {}
var _next_priority := 0
var _traffic_radii: Dictionary[Creature,float] = {}
var _motion_cache: Dictionary[Creature,Dictionary] = {}
var _sweep_shape := SphereShape3D.new()
var _sweep_query := PhysicsShapeQueryParameters3D.new()

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
	_pending = true
	_delay = 0.15
	_motion_cache.clear()
	ready_for_paths = _astar != null
	set_process(true)

func _process(delta: float) -> void:
	_delay = maxf(0.0,_delay-delta)
	if _cursor < 0:
		if not _pending:
			set_process(false)
			return
		if _delay > 0.0 or _map.regions_controller._rebuild_pending:
			return
		_pending = false
		_cursor = 0
		_capture_navigation_snapshot()
		_building = AStarGrid2D.new()
		_building.region = Rect2i(Vector2i.ZERO,_size)
		_building.cell_size = _extent
		_building.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_building.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_building.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_building.update()
		_building_depths.resize(_size.x*_size.y)
		_building_ids.resize(_size.x*_size.y)
	var deadline := Time.get_ticks_usec()+1800
	while _cursor < _size.x*_size.y and Time.get_ticks_usec() < deadline:
		var cell := Vector2i(_cursor%_size.x,_cursor/_size.x)
		var point: Vector2 = (Vector2(cell)+Vector2(0.5,0.5))*_extent-_snapshot.world_size*0.5
		var id := _snapshot_region(point)
		_building_ids[_cursor] = id
		_building_depths[_cursor] = _snapshot.water_level-_snapshot_height(point)
		var dx := _snapshot_height(point+Vector2(0.25,0))-_snapshot_height(point-Vector2(0.25,0))
		var dz := _snapshot_height(point+Vector2(0,0.25))-_snapshot_height(point-Vector2(0,0.25))
		var blocked := id <= 0 or Vector2(dx,dz).length()/0.5 > 1.0
		for offset in [Vector2(0.4,0),Vector2(-0.4,0),Vector2(0,0.4),Vector2(0,-0.4)]:
			if not blocked and _snapshot_region(point+offset) != id:
				blocked = true
		_building.set_point_solid(cell,blocked or _snapshot_blocked(point))
		_cursor += 1
	if _cursor == _size.x*_size.y:
		_cursor = -1
		_astar = _building
		_depths = _building_depths
		_ids = _building_ids
		_building_depths = PackedFloat32Array()
		_building_ids = PackedInt32Array()
		_building = null
		_snapshot.clear()
		_snapshot_blockers.clear()
		_failed_places.clear()
		revision += 1
		ready_for_paths = true
		navigation_changed.emit()
		set_process(_pending)

func _capture_navigation_snapshot() -> void:
	var terrain: TerrainController = _map.terrain_controller
	var regions: RegionsController = _map.regions_controller
	_snapshot = {"heights":terrain._heights.duplicate(),"height_size":terrain._height_size,"height_cell":terrain._height_cell,"world_size":terrain.world_size,"region_ids":regions._region_ids.duplicate(),"region_size":regions._grid_size,"region_extent":regions._cell_extent,"water_level":_map.water_controller.water_level}
	_snapshot_blockers.clear()
	for plant: FloraPlant in _map.vegetation_controller._plants:
		if not plant.removed and plant.growth > 0.025 and plant.species.kind <= FloraSpecies.KIND.SHRUB:
			_add_snapshot_blocker(plant.point,0.65)
	for rock in _map.rock_controller.get_children():
		if rock is HarvestableDeposit and not rock.exhausted and rock.mesh != null:
			var local := terrain.to_local(rock.global_position)
			var reach: float = maxf(rock.mesh.get_aabb().size.x,rock.mesh.get_aabb().size.z)*rock.scale.x*0.45+0.5
			_add_snapshot_blocker(Vector2(local.x,local.z),reach)
	for building: Node3D in _map.building_controller.get_buildings():
		var data: BuildingDefinition = _map.building_controller.building_definition(building)
		if data != null:
			var local := terrain.to_local(building.global_position)
			_add_snapshot_blocker(Vector2(local.x,local.z),data.footprint_radius+0.2)

func _add_snapshot_blocker(point: Vector2, radius: float) -> void:
	var first := Vector2i(((point-Vector2.ONE*radius)/2.0).floor())
	var last := Vector2i(((point+Vector2.ONE*radius)/2.0).floor())
	var obstacle := Vector3(point.x,point.y,radius)
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var key := Vector2i(x,y)
			var bucket: Array = _snapshot_blockers.get(key,[])
			bucket.append(obstacle)
			_snapshot_blockers[key] = bucket

func _snapshot_blocked(point: Vector2) -> bool:
	for obstacle: Vector3 in _snapshot_blockers.get(Vector2i((point/2.0).floor()),[]):
		if point.distance_squared_to(Vector2(obstacle.x,obstacle.y)) < obstacle.z*obstacle.z:
			return true
	return false

func _snapshot_region(point: Vector2) -> int:
	var world_size: Vector2 = _snapshot.world_size
	if not Rect2(-world_size*0.5,world_size).has_point(point):
		return 0
	var size: Vector2i = _snapshot.region_size
	var extent: Vector2 = _snapshot.region_extent
	var cell := Vector2i(((point+world_size*0.5)/extent).floor()).clamp(Vector2i.ZERO,size-Vector2i.ONE)
	var ids: PackedInt32Array = _snapshot.region_ids
	return ids[cell.y*size.x+cell.x]

func _snapshot_height(point: Vector2) -> float:
	var size: Vector2i = _snapshot.height_size
	var extent: Vector2 = _snapshot.height_cell
	var world_size: Vector2 = _snapshot.world_size
	var heights: PackedFloat32Array = _snapshot.heights
	var grid := ((point+world_size*0.5)/extent).clamp(Vector2.ZERO,Vector2(size-Vector2i.ONE))
	var cell := Vector2i(grid.floor()).min(size-Vector2i(2,2))
	var fraction := grid-Vector2(cell)
	var index := cell.y*size.x+cell.x
	var first := heights[index]
	var right := heights[index+1]
	var front := heights[index+size.x]
	if fraction.x+fraction.y <= 1.0:
		return first+(right-first)*fraction.x+(front-first)*fraction.y
	var last := heights[index+size.x+1]
	return last+(front-last)*(1.0-fraction.x)+(right-last)*(1.0-fraction.y)

func cell_position(cell: Vector2i) -> Vector3:
	var point: Vector2 = (Vector2(cell)+Vector2(0.5,0.5))*_extent-_map.terrain_controller.world_size*0.5
	return _map.terrain_controller.surface_position(_map.terrain_controller.to_global(Vector3(point.x,0,point.y)))

func _cell(world: Vector3) -> Vector2i:
	var local: Vector3 = _map.terrain_controller.to_local(world)
	return Vector2i(((Vector2(local.x,local.z)+_map.terrain_controller.world_size*0.5)/_extent).floor()).clamp(Vector2i.ZERO,_size-Vector2i.ONE)

func _open_near(world: Vector3) -> Vector2i:
	var cell := _cell(world)
	var region_id: int = _map.regions_controller.region_id_at(world)
	if region_id <= 0:
		return Vector2i(-1,-1)
	if not _astar.is_point_solid(cell) and _ids[cell.y*_size.x+cell.x] == region_id:
		return cell
	for radius in range(1,5):
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				var next := cell+Vector2i(x,y)
				if _astar.region.has_point(next) and not _astar.is_point_solid(next) and _ids[next.y*_size.x+next.x] == region_id:
					var start := world
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
	var region_id: int = _map.regions_controller.region_id_at(from)
	if region_id <= 0 or _map.regions_controller.region_id_at(destination) != region_id or not _live_point_clear(destination):
		return result
	var first := _open_near(from)
	var last := _cell(destination)
	if first.x < 0 or _astar.is_point_solid(last) or _ids[first.y*_size.x+first.x] != _ids[last.y*_size.x+last.x]:
		return result
	for cell in _astar.get_id_path(first,last):
		result.append(cell_position(cell))
	if (_pending or _cursor >= 0) and not _live_path_clear(from,result,region_id):
		return PackedVector3Array()
	return result

func _live_point_clear(point: Vector3) -> bool:
	var terrain: TerrainController = _map.terrain_controller
	if not terrain.contains_world_point(point) or _map.regions_controller.region_id_at(point) <= 0 or terrain.slope_at(point) > 1.0:
		return false
	var local := terrain.to_local(point)
	return not _map.vegetation_controller.occupied(Vector2(local.x,local.z),0.65) and not _map.rock_controller.occupied(point,0.5) and not _map.building_controller.occupied(point,0.2)

func _live_path_clear(origin: Vector3, path: PackedVector3Array, region_id: int) -> bool:
	var previous: Vector3 = _map.terrain_controller.surface_position(origin)+Vector3.UP*0.5
	for point in path:
		if _map.regions_controller.region_id_at(point) != region_id:
			return false
		var next := point+Vector3.UP*0.5
		if previous.distance_squared_to(next) > 0.0001:
			var query := PhysicsRayQueryParameters3D.create(previous,next,6)
			if not _map.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				return false
		previous = next
	return true

func route_to_water(from: Vector3, minimum_depth: float, actor: Creature = null) -> PackedVector3Array:
	return _find_route(from,true,minimum_depth,actor)

func route_to_sowing_ground(from: Vector3, actor: Creature = null) -> PackedVector3Array:
	return _find_route(from,false,0.0,actor)

func route_to_resting_ground(from: Vector3, actor: Creature = null) -> PackedVector3Array:
	return _find_route(from,false,0.0,actor,false)

func _find_route(from: Vector3, water: bool, minimum_depth: float, actor: Creature = null, sowing: bool = true) -> PackedVector3Array:
	if not ready_for_paths:
		return PackedVector3Array()
	var first := _open_near(from)
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
		var depth: float = _map.water_controller.water_level-_map.terrain_controller.to_local(point).y
		if (water and depth < minimum_depth) or (not water and depth > -0.03):
			continue
		if actor != null and (not space_available(point,actor) or _avoids_failed_place(actor,point)):
			continue
		if not water and sowing and not _map.vegetation_controller.can_seed_grass(point):
			continue
		var path := path_to(from,point)
		if not path.is_empty() and (actor == null or _route_is_new(actor,path)):
			return path
		attempts += 1
		if attempts >= (64 if actor != null and _failed_places.has(actor) else 24):
			break
	return PackedVector3Array()

func spawn_position(around: Vector3, radius_needed: float = 0.5) -> Variant:
	if not ready_for_paths:
		return null
	var region_id: int = _map.regions_controller.region_id_at(around)
	for radius in [2.2,3.2,4.2]:
		for index in 24:
			var point: Vector3 = around+Vector3(cos(index*TAU/24),0,sin(index*TAU/24))*radius
			if not _map.terrain_controller.contains_world_point(point):
				continue
			var cell := _cell(point)
			var ground := cell_position(cell)
			if ground.y <= _map.water_controller.global_position.y+0.05:
				continue
			if _astar.is_point_solid(cell) or _depths[cell.y*_size.x+cell.x] >= -0.05 or not space_available(ground,null,radius_needed):
				continue
			if region_id > 0 and _map.regions_controller.region_id_at(ground) != region_id:
				continue
			var shape := SphereShape3D.new()
			shape.radius = radius_needed
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform.origin = ground+Vector3.UP*(radius_needed+0.08)
			query.collision_mask = 6
			if _map.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
				return ground+Vector3.UP*(radius_needed+0.1)
	return null

func route_to_feeder(from: Vector3, species: CreatureSpecies, actor: Creature = null) -> Dictionary:
	var nearest := INF
	var result := {}
	for building in _map.building_controller.get_buildings():
		if not building is FeederController or not building.can_feed(species):
			continue
		for point in building.feeding_positions():
			if _map.water_controller.global_position.y >= _map.terrain_controller.surface_position(point).y:
				continue
			var path := path_to(from,point)
			if path.is_empty() or (actor != null and not space_available(path[-1],actor)):
				continue
			var length := 0.0
			for index in range(1,path.size()):
				length += path[index-1].distance_to(path[index])
			if length < nearest:
				nearest = length
				result = {"feeder":building,"path":path}
	return result

func register_actor(actor: Creature) -> void:
	if _actors.has(actor):
		return
	_actors.append(actor)
	_priorities[actor] = _next_priority
	_next_priority += 1
	actor.tree_exiting.connect(_unregister_actor.bind(actor))
	_traffic_frame = -1

func _unregister_actor(actor: Creature) -> void:
	release_place(actor)
	_failed_places.erase(actor)
	_actors.erase(actor)
	_intentions.erase(actor)
	_traffic_intentions.erase(actor)
	_traffic_positions.erase(actor)
	_traffic_velocities.erase(actor)
	_priorities.erase(actor)
	_traffic_radii.erase(actor)
	_traffic_frame = -1

func reserve_place(actor: Creature, point: Vector3) -> bool:
	var current := Vector2(point.x-actor.global_position.x,point.z-actor.global_position.z).length_squared() <= 0.0009
	if not _live_point_clear(point) or (not current and not space_available(point,actor)):
		return false
	_claims[actor] = point
	return true

func release_place(actor: Creature) -> void:
	_claims.erase(actor)

func _update_traffic() -> void:
	var frame := Engine.get_physics_frames()
	if _traffic_frame == frame:
		return
	_traffic_frame = frame
	_buckets.clear()
	_motion_cache.clear()
	_traffic_intentions = _intentions.duplicate()
	for actor: Creature in _actors:
		if not actor.blocks_space():
			continue
		_traffic_positions[actor] = actor.global_position
		_traffic_radii[actor] = actor.body_radius()
		var movement := actor.get_real_velocity()
		_traffic_velocities[actor] = Vector2(movement.x,movement.z)
		var key := Vector2i((Vector2(actor.global_position.x,actor.global_position.z)/2.0).floor())
		if not _buckets.has(key):
			_buckets[key] = []
		_buckets[key].append(actor)

func _nearby(point: Vector3) -> Array:
	_update_traffic()
	var key := Vector2i((Vector2(point.x,point.z)/2.0).floor())
	var result: Array = []
	for y in range(key.y-1,key.y+2):
		for x in range(key.x-1,key.x+2):
			result.append_array(_buckets.get(Vector2i(x,y),[]))
	return result

func space_available(point: Vector3, actor: Creature = null, radius: float = 0.5) -> bool:
	if actor != null:
		radius = actor.body_radius()
	for other: Creature in _nearby(point):
		if other == actor or not other.blocks_space():
			continue
		var distance := Vector2(point.x-other.global_position.x,point.z-other.global_position.z).length()
		if distance < radius+other.body_radius()+0.08:
			return false
	for other: Creature in _claims:
		if other == actor:
			continue
		var reserved := _claims[other]
		if Vector2(point.x-reserved.x,point.z-reserved.z).length() < radius+other.body_radius()+0.1:
			return false
	return true

func steer(actor: Creature, desired: Vector2, _delta: float) -> Vector2:
	var neighbors := _nearby(actor.global_position)
	_intentions[actor] = desired
	var preferred := _courtesy_velocity(actor,desired,neighbors)
	if preferred.is_equal_approx(desired) and _motion_fraction(actor,desired*0.4) >= 0.98:
		return desired
	var speed := maxf(desired.length(),preferred.length())
	if speed < 0.01:
		return Vector2.ZERO
	var best := Vector2.ZERO
	var best_score := INF
	var position: Vector3 = _traffic_positions.get(actor,actor.global_position)
	for angle in [0.0,0.4,-0.4,0.8,-0.8,1.3,-1.3,PI]:
		var candidate := preferred.rotated(angle) if angle != PI else Vector2.ZERO
		candidate *= _motion_fraction(actor,candidate*0.4)
		var score: float = candidate.distance_to(preferred)/speed+candidate.distance_to(desired)/speed*0.12+absf(angle)*0.015
		for other: Creature in neighbors:
			if other == actor or not other.blocks_space():
				continue
			var other_position: Vector3 = _traffic_positions.get(other,other.global_position)
			if absf(position.y-other_position.y) > _traffic_radii[actor]+_traffic_radii[other]+0.2:
				continue
			var relative := Vector2(position.x-other_position.x,position.z-other_position.z)
			if relative.length_squared() > pow(_traffic_radii[actor]+_traffic_radii[other]+1.7,2.0):
				continue
			var motion: Vector2 = candidate-_traffic_velocities.get(other,Vector2.ZERO)
			var nearest_time := clampf(-relative.dot(motion)/maxf(motion.length_squared(),0.001),0.0,0.65)
			var distance := (relative+motion*nearest_time).length()
			var clearance := _traffic_radii[actor]+_traffic_radii[other]+0.04
			if distance < clearance:
				score += 12.0*(clearance-distance)/clearance+2.0
			elif distance < clearance+0.3:
				score += (clearance+0.3-distance)*0.5
		if score < best_score:
			best_score = score
			best = candidate
	return best

func _courtesy_velocity(actor: Creature, desired: Vector2, neighbors: Array) -> Vector2:
	var preferred := desired
	var position: Vector3 = _traffic_positions.get(actor,actor.global_position)
	var strongest := 0.0
	var separation := Vector2.ZERO
	for other: Creature in neighbors:
		if other == actor or not other.blocks_space():
			continue
		var other_position: Vector3 = _traffic_positions.get(other,other.global_position)
		if absf(position.y-other_position.y) > _traffic_radii[actor]+_traffic_radii[other]+0.2:
			continue
		var relative := Vector2(other_position.x-position.x,other_position.z-position.z)
		var distance := relative.length()
		var clearance := _traffic_radii[actor]+_traffic_radii[other]+0.12
		if distance < clearance and distance > 0.001:
			separation -= relative/distance*minf((clearance-distance)*3.0,0.7)
		if _map.breeding.are_partners(actor,other):
			continue
		var other_desired: Vector2 = _traffic_intentions.get(other,Vector2.ZERO)
		var incoming: Vector2 = other_desired if other_desired.length_squared() > 0.01 else _traffic_velocities.get(other,Vector2.ZERO)
		var motion := desired-incoming
		var nearest_time := clampf(relative.dot(motion)/maxf(motion.length_squared(),0.001),0.0,1.1)
		if distance > clearance+1.7 or (relative-motion*nearest_time).length() > clearance+0.12:
			continue
		var urgency := 1.0/maxf(distance,0.2)
		if urgency <= strongest:
			continue
		if desired.length_squared() < 0.01 and incoming.length_squared() > 0.01 and relative.dot(incoming) < 0.15:
			var direction := incoming.normalized()
			var side := Vector2(direction.y,-direction.x)
			if (-relative).dot(side) < -0.1:
				side = -side
			var side_room := _motion_fraction(actor,side*0.8)
			var opposite_room := _motion_fraction(actor,-side*0.8)
			if opposite_room > side_room+0.2:
				side = -side
				side_room = opposite_room
			preferred = side*0.75 if side_room > 0.3 else direction*minf(incoming.length(),0.75)
			strongest = urgency
		elif desired.length_squared() > 0.01 and relative.dot(desired) > 0.0:
			var direction := desired.normalized()
			var side := Vector2(-direction.y,direction.x)
			var room := _motion_fraction(actor,side*0.75)*0.75
			var other_room := _motion_fraction(other,-side*0.75)*0.75
			var lateral := absf(relative.dot(side))
			if incoming.normalized().dot(direction) < -0.5 and room+other_room+lateral < clearance+0.08:
				if _priorities.get(actor,0) > _priorities.get(other,0):
					preferred = -direction*minf(maxf(desired.length(),0.75),1.0)
				else:
					preferred = desired*0.5
			else:
				preferred = desired*0.7+side*minf(desired.length()*0.8,0.8)
			strongest = urgency
	return (preferred+separation).limit_length(maxf(desired.length(),0.85))

func _motion_fraction(actor: Creature, motion: Vector2) -> float:
	if motion.length_squared() < 0.0001:
		return 1.0
	var key := Vector2i((motion*128.0).round())
	var cache: Dictionary = _motion_cache.get(actor,{})
	if cache.has(key):
		return cache[key]
	var origin: Vector3 = _traffic_positions.get(actor,actor.global_position)
	var terrain: TerrainController = _map.terrain_controller
	var region_id: int = _map.regions_controller.region_id_at(origin)
	var maximum_slope := maxf(1.0,terrain.slope_at(origin)+0.05)
	var half_size := terrain.world_size*0.5-Vector2.ONE*_traffic_radii[actor]
	for index in range(1,4):
		var point := origin+Vector3(motion.x,0,motion.y)*float(index)/3.0
		var local := terrain.to_local(point)
		if absf(local.x) > half_size.x or absf(local.z) > half_size.y:
			return float(index-1)/3.0
		if _map.regions_controller.region_id_at(point) != region_id or terrain.slope_at(point) > maximum_slope:
			return float(index-1)/3.0
	_sweep_shape.radius = maxf(0.05,_traffic_radii[actor]-0.015)
	_sweep_query.shape = _sweep_shape
	_sweep_query.transform.origin = origin
	_sweep_query.motion = Vector3(motion.x,0,motion.y)
	_sweep_query.collision_mask = actor.collision_mask&6
	_sweep_query.exclude = [actor.get_rid()]
	var travel := actor.get_world_3d().direct_space_state.cast_motion(_sweep_query)
	var fraction := maxf(0.0,travel[0]-0.02)
	cache[key] = fraction
	_motion_cache[actor] = cache
	return fraction

func bathing_route(actor: Creature) -> PackedVector3Array:
	if not ready_for_paths:
		return PackedVector3Array()
	var candidates: Array[Vector3] = []
	var origin := _cell(actor.global_position)
	for y in range(origin.y-4,origin.y+5):
		for x in range(origin.x-4,origin.x+5):
			var cell := Vector2i(x,y)
			if not _astar.region.has_point(cell) or _astar.is_point_solid(cell):
				continue
			if _depths[y*_size.x+x] < actor.species_data().minimum_swim_depth+0.08:
				continue
			var point := cell_position(cell)
			var distance := point.distance_to(actor.global_position)
			if distance >= 0.65 and distance <= 1.8 and space_available(point,actor):
				candidates.append(point)
	candidates.shuffle()
	for point in candidates.slice(0,12):
		var path := path_to(actor.global_position,point)
		var wet := not path.is_empty()
		for step in path:
			var cell := _cell(step)
			if _depths[cell.y*_size.x+cell.x] < actor.species_data().minimum_swim_depth:
				wet = false
				break
		if wet:
			return path
	return PackedVector3Array()

func route_to_partner(actor: Creature, partner: Creature) -> PackedVector3Array:
	var best := PackedVector3Array()
	var nearest := INF
	var separation := actor.body_radius()+partner.body_radius()+0.22
	for index in 16:
		var point := partner.global_position+Vector3(cos(index*TAU/16),0,sin(index*TAU/16))*separation
		point = _map.terrain_controller.surface_position(point)
		if not _map.terrain_controller.contains_world_point(point) or point.y <= _map.water_controller.global_position.y+0.03:
			continue
		var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*actor.body_radius(),partner.global_position,6)
		if not _map.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		var path := path_to(actor.global_position,point)
		if path.is_empty() or not space_available(path[-1],actor) or not space_available(point,actor):
			continue
		if not _partner_segment_clear(actor,path[-1],point):
			continue
		if path[-1].distance_squared_to(point) > 0.0001:
			path.append(point)
		var length := 0.0
		for step in range(1,path.size()):
			length += path[step-1].distance_to(path[step])
		if length < nearest:
			best = path
			nearest = length
	return best

func _partner_segment_clear(actor: Creature, from: Vector3, to: Vector3) -> bool:
	var region_id: int = _map.regions_controller.region_id_at(from)
	var steps := maxi(1,ceili(from.distance_to(to)/0.1))
	for index in range(1,steps+1):
		var point := from.lerp(to,float(index)/steps)
		if _map.regions_controller.region_id_at(point) != region_id or _map.terrain_controller.slope_at(point) > 1.0:
			return false
	var radius := actor.body_radius()
	var shape := SphereShape3D.new()
	shape.radius = maxf(0.05,radius-0.01)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = from+Vector3.UP*(radius+0.03)
	query.motion = to-from
	query.collision_mask = 6
	query.exclude = [actor.get_rid()]
	var space := actor.get_world_3d().direct_space_state
	if space.cast_motion(query)[0] < 0.999:
		return false
	query.transform.origin = to+Vector3.UP*(radius+0.03)
	query.motion = Vector3.ZERO
	return space.intersect_shape(query,1).is_empty()

func drop_position(actor: Creature, around: Vector3) -> Variant:
	var rings := ceili(_map.terrain_controller.world_size.length()/0.6)
	for ring in range(rings):
		var count := 1 if ring == 0 else maxi(8,ceili(TAU*ring))
		for index in count:
			var angle := TAU*index/count
			var point := around+Vector3(cos(angle),0,sin(angle))*ring*0.6
			if not _map.terrain_controller.contains_world_point(point):
				continue
			point = _map.terrain_controller.surface_position(point)
			if ready_for_paths and _astar.is_point_solid(_cell(point)):
				continue
			if not space_available(point,actor):
				continue
			var shape := SphereShape3D.new()
			shape.radius = actor.body_radius()+0.02
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform.origin = point+Vector3.UP*(actor.body_radius()+0.04)
			query.collision_mask = 14
			query.exclude = [actor.get_rid()]
			if _map.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
				point.y = maxf(around.y,point.y+actor.body_radius()+0.04)
				return point
	return null

func avoid_blocked_route(actor: Creature, target: Vector3) -> void:
	var places: Array = _failed_places.get(actor,[])
	var direction := Vector2(target.x-actor.global_position.x,target.z-actor.global_position.z).normalized()
	places.append({"point":target,"origin":actor.global_position,"direction":direction,"until":Time.get_ticks_msec()+8000})
	if places.size() > 4:
		places.pop_front()
	_failed_places[actor] = places
	release_place(actor)

func _active_failures(actor: Creature) -> Array:
	var places: Array = _failed_places.get(actor,[])
	var now := Time.get_ticks_msec()
	for index in range(places.size()-1,-1,-1):
		if places[index].until <= now:
			places.remove_at(index)
	if places.is_empty():
		_failed_places.erase(actor)
	return places

func _avoids_failed_place(actor: Creature, point: Vector3) -> bool:
	for place in _active_failures(actor):
		var old: Vector3 = place.point
		if Vector2(point.x-old.x,point.z-old.z).length() < 1.25:
			return true
	return false

func _route_is_new(actor: Creature, path: PackedVector3Array) -> bool:
	for place in _active_failures(actor):
		var origin: Vector3 = place.origin
		if Vector2(actor.global_position.x-origin.x,actor.global_position.z-origin.z).length() > 1.25:
			continue
		for point in path:
			var direction := Vector2(point.x-actor.global_position.x,point.z-actor.global_position.z)
			if direction.length() < 0.45:
				continue
			if direction.normalized().dot(place.direction) > 0.65:
				return false
			break
	return true
