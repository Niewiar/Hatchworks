class_name TuftlingPlayPair
extends RefCounted

enum PHASE { APPROACH = 0, PLAY = 2 }

var first: CreatureActivityController
var second: CreatureActivityController
var phase: PHASE = PHASE.APPROACH
var elapsed := 0.0
var age := 0.0
var _first_leisure: TuftlingLeisure
var _second_leisure: TuftlingLeisure
var _path := PackedVector3Array()
var _path_index := 0
var _last_tick := -1
var _stuck_elapsed := 0.0
var _last_position := Vector3.ZERO
var _finished := false

static func find(actor: CreatureActivityController, leisure: TuftlingLeisure) -> TuftlingPlayPair:
	if not leisure.available_for_play() or not actor._map.navigation.ready_for_paths:
		return null
	var candidates: Array[TuftlingController] = []
	var region_id: int = actor._map.regions_controller.region_id_at(actor.global_position)
	for node in actor.get_tree().get_nodes_in_group("creatures"):
		if not node is TuftlingController or node == actor or node.species_id != actor.species_id:
			continue
		var other := node as TuftlingController
		if other._map != actor._map or other.get_viewport() != actor.get_viewport() or not _available(other):
			continue
		if actor.global_position.distance_squared_to(other.global_position) > 2.25 or actor._map.regions_controller.region_id_at(other.global_position) != region_id:
			continue
		candidates.append(other)
	candidates.sort_custom(func(a: TuftlingController,b: TuftlingController): return actor.global_position.distance_squared_to(a.global_position) < actor.global_position.distance_squared_to(b.global_position))
	for other: TuftlingController in candidates.slice(0,8):
		var other_leisure := other._leisure_controller()
		if not other_leisure.available_for_play():
			continue
		var seconds := minf(actor._leisure_duration-actor._leisure_elapsed,other._leisure_duration-other._leisure_elapsed)-3.3
		var speed := other_leisure._walking_speed()
		if seconds <= 0.0:
			continue
		var route: PackedVector3Array = actor._map.navigation.route_to_partner(other,actor,0.11)
		if not other_leisure._route_is_safe(route,minf(1.5,seconds*speed)):
			continue
		var pair := _create(actor,other,leisure,other_leisure,route)
		if pair != null:
			return pair
	return null

static func restore(actor: CreatureActivityController, leisure: TuftlingLeisure, state: Dictionary, actors: Array[Creature]) -> TuftlingPlayPair:
	var index: int = state.get("partner",-1)
	if index < 0 or index >= actors.size() or actors[index] == actor or not actors[index] is TuftlingController:
		return null
	var other := actors[index] as TuftlingController
	if other.species_id != actor.species_id or other._map != actor._map:
		return null
	var other_leisure := other._leisure_controller()
	if not leisure.available_for_play() or not other_leisure.available_for_play():
		return null
	if not _available(actor) or not _available(other) or actor.get_viewport() != other.get_viewport() or actor._map.regions_controller.region_id_at(actor.global_position) != actor._map.regions_controller.region_id_at(other.global_position):
		return null
	var leader: CreatureActivityController = actor if state.get("leader",false) else other
	var visitor: CreatureActivityController = other if leader == actor else actor
	var leader_leisure := leisure if leader == actor else other_leisure
	var visitor_leisure := other_leisure if leader == actor else leisure
	var saved_phase: int = state.get("phase",0)
	var saved_elapsed: float = state.get("elapsed",0.0)
	if saved_phase == 1:
		saved_phase = PHASE.PLAY
		saved_elapsed = 0.0
	var route := PackedVector3Array([visitor.global_position])
	var remaining := minf(actor._leisure_duration-actor._leisure_elapsed,other._leisure_duration-other._leisure_elapsed)
	if saved_phase == PHASE.APPROACH:
		route = actor._map.navigation.route_to_partner(visitor,leader,0.11)
		var speed := visitor_leisure._walking_speed()
		if not visitor_leisure._route_is_safe(route,minf(1.5,maxf(0.0,remaining-3.3)*speed)):
			return null
	elif remaining < maxf(0.0,3.0-saved_elapsed) or leader.global_position.distance_to(visitor.global_position) > leader.body_radius()+visitor.body_radius()+0.6:
		return null
	var pair := _create(leader,visitor,leader_leisure,visitor_leisure,route)
	if pair != null:
		pair.phase = saved_phase as PHASE
		pair.elapsed = saved_elapsed
		pair.age = state.get("age",0.0)
		pair._present(leader,0.0)
		pair._present(visitor,0.0)
	return pair

static func _create(leader: CreatureActivityController, visitor: CreatureActivityController, leader_leisure: TuftlingLeisure, visitor_leisure: TuftlingLeisure, route: PackedVector3Array) -> TuftlingPlayPair:
	if route.is_empty() or not leader._map.navigation.reserve_place(leader,leader.global_position):
		return null
	if not leader._map.navigation.reserve_place(visitor,route[-1]):
		leader._map.navigation.release_place(leader)
		return null
	var pair := TuftlingPlayPair.new()
	pair.first = leader
	pair.second = visitor
	pair._first_leisure = leader_leisure
	pair._second_leisure = visitor_leisure
	pair._path = route
	pair._last_position = visitor.global_position
	leader_leisure.accept_pair(pair)
	visitor_leisure.accept_pair(pair)
	return pair

static func _available(actor: CreatureActivityController) -> bool:
	return is_instance_valid(actor) and actor.activity == CreatureActivityController.ACTIVITY.LEISURE and actor.is_grounded() and actor._on_dry_ground() and actor.satiety > actor.species_data().feeding_threshold and not actor._map.breeding.is_breeding(actor)

func includes(actor: Creature) -> bool:
	return not _finished and actor in [first,second]

func holds_position(actor: Creature) -> bool:
	return not _finished and (actor == first or phase != PHASE.APPROACH)

func tick(actor: CreatureActivityController, delta: float) -> void:
	if _finished:
		return
	if _last_tick != Engine.get_physics_frames():
		_last_tick = Engine.get_physics_frames()
		_advance(delta)
	if not _finished:
		_present(actor,delta)

func _advance(delta: float) -> void:
	if not _available(first) or not _available(second):
		end()
		return
	if not first._map.navigation.ready_for_paths or first._map.regions_controller.region_id_at(first.global_position) != first._map.regions_controller.region_id_at(second.global_position):
		end()
		return
	age += delta
	if age >= 16.0:
		end()
		return
	if phase == PHASE.APPROACH:
		var separation := first.body_radius()+second.body_radius()+0.16
		var at_destination := _path_index >= _path.size()-1 and Vector2(second.global_position.x-_path[-1].x,second.global_position.z-_path[-1].z).length() <= 0.03
		if at_destination and first.global_position.distance_to(second.global_position) <= separation and _clear_sight():
			phase = PHASE.PLAY
			elapsed = 0.0
			first._map.navigation.reserve_place(second,second.global_position)
			return
		_stuck_elapsed += delta
		if _stuck_elapsed >= 2.0:
			if Vector2(second.global_position.x-_last_position.x,second.global_position.z-_last_position.z).length() < 0.05:
				end()
			_last_position = second.global_position
			_stuck_elapsed = 0.0
		return
	elapsed += delta
	if phase == PHASE.PLAY and elapsed >= 3.0:
		end()

func _present(actor: CreatureActivityController, delta: float) -> void:
	if phase == PHASE.APPROACH:
		if actor == first:
			actor.face_point(second.global_position)
		else:
			_follow_route(delta)
		return
	var line := second.global_position-first.global_position
	var forward := Vector3(-line.z,0,line.x).normalized()
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	var animation: StringName = &"Idle" if actor == second and elapsed < 0.4 else &"Play"
	actor.face_point(actor.global_position+forward,animation)

func _follow_route(delta: float) -> void:
	if _path_index >= _path.size():
		second._play_animation(&"Idle")
		return
	var point := _path[_path_index]
	if not _second_leisure._safe_point(point):
		end()
		return
	var difference := Vector2(point.x-second.global_position.x,point.z-second.global_position.z)
	if difference.length() < 0.025:
		_path_index += 1
		return
	var speed := _second_leisure._walking_speed()
	second.walk_direction(difference.normalized(),minf(speed,difference.length()/maxf(delta,0.001)))

func presentation(actor: CreatureActivityController) -> Dictionary:
	if phase == PHASE.APPROACH and actor == second:
		return actor._present_activity("On the move","status_walk","Walking to a playmate")
	if phase == PHASE.PLAY:
		return actor._present_activity("Playing","status_company","Playing together")
	return actor._present_activity("Resting","status_company","Looking for a playmate")

func capture_state(actor: CreatureActivityController, actors: Array[Creature]) -> Dictionary:
	var partner := actors.find(second if actor == first else first)
	if partner < 0:
		return {"partner":-1,"leader":false,"phase":0,"elapsed":0.0,"age":0.0}
	return {"partner":partner,"leader":actor == first,"phase":int(phase),"elapsed":elapsed,"age":age}

func end() -> void:
	if _finished:
		return
	_finished = true
	for actor: CreatureActivityController in [first,second]:
		if is_instance_valid(actor) and is_instance_valid(actor._map) and is_instance_valid(actor._map.navigation):
			actor._map.navigation.release_place(actor)
	_first_leisure.pair_ended(self)
	_second_leisure.pair_ended(self)

func _clear_sight() -> bool:
	var query := PhysicsRayQueryParameters3D.create(first.global_position,second.global_position,6)
	return first.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
