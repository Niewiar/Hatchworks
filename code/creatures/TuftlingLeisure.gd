class_name TuftlingLeisure
extends RefCounted

enum ACTION { NONE, SLEEP, WANDER, PLAY }

var action: ACTION = ACTION.NONE
var _actor: CreatureActivityController
var _path := PackedVector3Array()
var _path_index := 0
var _target := Vector3.ZERO
var _region_id := 0
var _stuck_elapsed := 0.0
var _last_position := Vector3.ZERO
var _pair: TuftlingPlayPair
var _social_elapsed := 0.0
var _social_checked := false

func _init(actor: CreatureActivityController) -> void:
	_actor = actor
	if _actor._map != null:
		_region_id = _actor._map.regions_controller.region_id_at(_actor.global_position)

func begin() -> void:
	cancel()
	_region_id = _actor._map.regions_controller.region_id_at(_actor.global_position)
	var choice := randf()
	action = ACTION.SLEEP if choice < 0.4 else (ACTION.WANDER if choice < 0.7 else ACTION.PLAY)
	_target = _actor.terrain_controller.surface_position(_actor.global_position)
	if action == ACTION.PLAY:
		_pair = TuftlingPlayPair.find(_actor,self)
		_actor._play_animation(&"Idle")
		return
	var chosen := _choose_route()
	if not chosen.is_empty() and _actor._map.navigation.reserve_place(_actor,chosen[-1]):
		_set_path(chosen)
	else:
		if action == ACTION.WANDER:
			action = ACTION.SLEEP
		_settle()

func tick(delta: float) -> void:
	if action == ACTION.NONE:
		begin()
	if action == ACTION.PLAY:
		_tick_play(delta)
		refresh_sleep_effect()
		return
	if not _path.is_empty():
		_follow_route(delta)
	else:
		_play_settled_animation()
	refresh_sleep_effect()

func cancel() -> void:
	var waking := action == ACTION.SLEEP and _path.is_empty()
	var previous := _pair
	_pair = null
	if previous != null:
		previous.end()
	_set_sleep_effect(false)
	_path.clear()
	_path_index = 0
	action = ACTION.NONE
	_social_elapsed = 0.0
	_social_checked = false
	if is_instance_valid(_actor) and is_instance_valid(_actor._map) and is_instance_valid(_actor._map.navigation):
		_actor._map.navigation.release_place(_actor)
		if waking and _actor.is_grounded():
			_actor._play_animation(&"Idle",0.35)

func is_sleeping() -> bool:
	return action == ACTION.SLEEP and _path.is_empty() and _actor.activity == CreatureActivityController.ACTIVITY.LEISURE and _actor.is_grounded() and _actor._on_dry_ground() and not _actor._map.breeding.is_breeding(_actor)

func refresh_sleep_effect() -> void:
	_set_sleep_effect(is_sleeping())

func holds_position() -> bool:
	return is_sleeping() or (_pair != null and _pair.holds_position(_actor))

func presentation() -> Dictionary:
	if action == ACTION.PLAY:
		return _pair.presentation(_actor) if _pair != null else _actor._present_activity("Resting","status_company","Looking for a playmate")
	if not _path.is_empty():
		if action == ACTION.SLEEP:
			return _actor._present_activity("Resting","status_walk","Walking to a sleeping spot")
		return _actor._present_activity("Wandering","status_walk","Exploring nearby")
	if action == ACTION.SLEEP:
		return _actor._present_activity("Sleeping","status_sleep","Sleeping peacefully")
	return _actor._present_activity("Resting","status_rest","Looking around")

func capture_state(actors: Array[Creature] = []) -> Dictionary:
	if action == ACTION.NONE:
		return {}
	var result := {"action":["none","sleep","wander","play"][action],"target":_target,"moving":not _path.is_empty()}
	if action == ACTION.PLAY:
		result.merge(_pair.capture_state(_actor,actors) if _pair != null else {"partner":-1,"leader":false,"phase":0,"elapsed":_social_elapsed,"age":0.0})
	return result

func restore_state(state: Dictionary) -> void:
	if _actor.activity != CreatureActivityController.ACTIVITY.LEISURE:
		return
	cancel()
	if state.is_empty():
		return
	action = ACTION.PLAY if state.get("action","") == "play" else (ACTION.WANDER if state.get("action","") == "wander" else ACTION.SLEEP)
	_region_id = _actor._map.regions_controller.region_id_at(_actor.global_position)
	_target = state.get("target",_actor.terrain_controller.surface_position(_actor.global_position))
	if action == ACTION.PLAY:
		_social_elapsed = state.get("elapsed",0.0) if state.get("partner",-1) < 0 else 0.0
		_actor._play_animation(&"Idle")
		return
	if state.get("moving",false) and _safe_point(_target):
		var route: PackedVector3Array = _actor._map.navigation.path_to(_actor.global_position,_target)
		var budget := minf(1.5,_remaining_seconds()*_walking_speed())
		if _route_is_safe(route,budget) and _actor._map.navigation.reserve_place(_actor,route[-1]):
			_set_path(route)
			refresh_sleep_effect()
			return
	_settle()

func restore_partner(state: Dictionary, actors: Array[Creature]) -> void:
	if action == ACTION.PLAY and _pair == null and state.get("partner",-1) >= 0:
		_pair = TuftlingPlayPair.restore(_actor,self,state,actors)
		if _pair == null:
			action = ACTION.WANDER
			_settle()

func available_for_play() -> bool:
	if action == ACTION.NONE:
		_region_id = _actor._map.regions_controller.region_id_at(_actor.global_position)
	return _pair == null and action != ACTION.SLEEP and _actor.activity == CreatureActivityController.ACTIVITY.LEISURE and _actor.is_grounded() and _actor._on_dry_ground() and _actor.satiety > _actor.species_data().feeding_threshold and not _actor._map.breeding.is_breeding(_actor)

func is_playing_with(other: Creature) -> bool:
	return _pair != null and _pair.includes(other)

func accept_pair(pair: TuftlingPlayPair) -> void:
	_pair = pair
	_path.clear()
	_set_sleep_effect(false)
	action = ACTION.PLAY
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0

func pair_ended(pair: TuftlingPlayPair) -> void:
	if _pair != pair:
		return
	_pair = null
	action = ACTION.WANDER
	_path.clear()
	if not is_instance_valid(_actor):
		return
	_actor._map.navigation.release_place(_actor)
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	if _actor.is_grounded() and _actor.activity == CreatureActivityController.ACTIVITY.LEISURE:
		_actor._play_animation(&"Idle")

func _tick_play(delta: float) -> void:
	if _pair != null:
		_pair.tick(_actor,delta)
		return
	_social_elapsed += delta
	_actor._play_animation(&"Idle")
	if not _social_checked and _social_elapsed >= 0.75:
		_social_checked = true
		_pair = TuftlingPlayPair.find(_actor,self)
	if _pair == null and _social_elapsed >= 1.5:
		action = ACTION.WANDER
		var route := _choose_route()
		if not route.is_empty() and _actor._map.navigation.reserve_place(_actor,route[-1]):
			_set_path(route)
		else:
			_settle()

func _choose_route() -> PackedVector3Array:
	var best := PackedVector3Array()
	if not _actor._map.navigation.ready_for_paths or _region_id <= 0:
		return best
	var sleeping := action == ACTION.SLEEP
	var budget := minf(0.9 if sleeping else 1.5,_remaining_seconds()*_walking_speed()*(0.5 if sleeping else 0.9))
	var best_score := _place_score(_target,0.0) if sleeping else -INF
	var points: Array[Vector3] = []
	var offset := randf()*TAU
	for radius: float in [0.5,1.0]:
		for index in 8:
			var angle := offset+float(index)*TAU/8.0
			points.append(_actor.terrain_controller.surface_position(_actor.global_position+Vector3(cos(angle),0,sin(angle))*radius))
	points.shuffle()
	for point: Vector3 in points:
		if not _safe_point(point):
			continue
		var route: PackedVector3Array = _actor._map.navigation.path_to(_actor.global_position,point)
		if not _route_is_safe(route,budget):
			continue
		var destination := route[-1]
		if not _actor._map.navigation.space_available(destination,_actor):
			continue
		var length := _route_length(route)
		if length < 0.25:
			continue
		var score := _place_score(destination,length) if sleeping else length*0.4+randf()*0.3
		if score > best_score+0.05:
			best_score = score
			best = route
	return best

func _place_score(point: Vector3, length: float) -> float:
	var grass: float = _actor.terrain_controller.ground_weight(point,TerrainController.GROUND_TYPE.GRASS)
	var noise: float = _actor._map.noise.level_at(point,_actor)
	return grass*1.2-noise*1.4-length*0.45

func _route_length(route: PackedVector3Array) -> float:
	var previous := _actor.global_position
	var length := 0.0
	for point in route:
		length += Vector2(point.x-previous.x,point.z-previous.z).length()
		previous = point
	return length

func _route_is_safe(route: PackedVector3Array, budget: float) -> bool:
	if route.is_empty() or _route_length(route) > budget:
		return false
	var previous := _actor.global_position
	for point in route:
		var length := Vector2(point.x-previous.x,point.z-previous.z).length()
		var samples := maxi(1,ceili(length/0.2))
		for index in range(1,samples+1):
			if not _safe_point(previous.lerp(point,float(index)/float(samples))):
				return false
		previous = point
	return true

func _safe_point(point: Vector3) -> bool:
	var terrain := _actor.terrain_controller
	var clearance := _actor.body_radius()+0.04
	for offset: Vector3 in [Vector3.ZERO,Vector3(clearance,0,0),Vector3(-clearance,0,0),Vector3(0,0,clearance),Vector3(0,0,-clearance)]:
		var sample := point+offset
		if not terrain.contains_world_point(sample) or _actor._map.regions_controller.region_id_at(sample) != _region_id:
			return false
		if terrain.surface_position(sample).y <= _actor._map.water_controller.global_position.y+0.05 or terrain.slope_at(sample) > 0.8:
			return false
	return true

func _set_path(route: PackedVector3Array) -> void:
	_path = route
	_path_index = 0
	_target = route[-1]
	_stuck_elapsed = 0.0
	_last_position = _actor.global_position
	_set_sleep_effect(false)
	_actor._play_animation(&"Walk")

func _follow_route(delta: float) -> void:
	if not _actor._map.navigation.ready_for_paths:
		_actor._play_animation(&"Idle")
		return
	var point := _path[_path_index]
	if not _safe_point(point):
		_settle()
		return
	var difference := Vector2(point.x-_actor.global_position.x,point.z-_actor.global_position.z)
	if difference.length() < 0.025:
		_path_index += 1
		if _path_index >= _path.size():
			_settle()
		return
	_actor.walk_direction(difference.normalized(),minf(_walking_speed(),difference.length()/maxf(delta,0.001)))
	_stuck_elapsed += delta
	if _stuck_elapsed >= 2.0:
		if Vector2(_actor.global_position.x-_last_position.x,_actor.global_position.z-_last_position.z).length() < 0.05:
			_settle()
		_last_position = _actor.global_position
		_stuck_elapsed = 0.0

func _settle() -> void:
	_path.clear()
	_path_index = 0
	_target = _actor.terrain_controller.surface_position(_actor.global_position)
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	_actor._map.navigation.release_place(_actor)
	_actor._map.navigation.reserve_place(_actor,_actor.global_position)
	_play_settled_animation()
	refresh_sleep_effect()

func _play_settled_animation() -> void:
	if action == ACTION.SLEEP:
		if not _actor._play_animation(&"Sleep",0.35):
			_actor._play_animation(&"behaviour/Rest",0.35)
	else:
		_actor._play_animation(&"Idle")

func _walking_speed() -> float:
	var appearance := _actor._model as CreatureCelAppearance
	return minf(_actor.species_data().walk_speed,appearance.walk_speed) if appearance != null else _actor.species_data().walk_speed

func _remaining_seconds() -> float:
	return maxf(0.0,_actor._leisure_duration-_actor._leisure_elapsed)

func _set_sleep_effect(active: bool) -> void:
	if not is_instance_valid(_actor):
		return
	var signs := _actor.get_node_or_null("SleepSigns") as CPUParticles3D
	if signs == null:
		return
	if active and not signs.visible:
		signs.visible = true
		signs.restart()
	signs.emitting = active
	signs.visible = active
