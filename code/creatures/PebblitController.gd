class_name PebblitController
extends EcosystemCreatureController

const RIDE_DISTANCE := 0.590318495
const FEMALE_WALK_DISTANCE := 0.22285714750000002
const MALE_WALK_DISTANCE := 0.13
const FEMALE_MODEL = preload("res://scenes/creatures/pebblit_female_model.tscn")
const MALE_MODEL = preload("res://scenes/creatures/pebblit_model.tscn")

enum POSE { OPEN, CURLING, RIDING, IMPACT, UNCURLING }

var _model_initialized := false
var _pose := POSE.OPEN
var _requested_animation: StringName = &"Idle"
var _rubbing_job: Dictionary = {}
var _aggression_retry := 0.0

func _ready() -> void:
	prepare_appearance()
	super._ready()
	_model_initialized = true

func prepare_appearance() -> void:
	_select_model()

func _select_model() -> void:
	var previous := get_node("Model") as PebblitAppearance
	if previous.female == (sex == SEX.FEMALE):
		return
	if _model_initialized:
		interrupt_activity()
		if animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.disconnect(_on_animation_finished)
	var replacement := (FEMALE_MODEL if sex == SEX.FEMALE else MALE_MODEL).instantiate() as PebblitAppearance
	replacement.transform = previous.transform
	remove_child(previous)
	previous.queue_free()
	replacement.name = "Model"
	add_child(replacement)
	animation_player = replacement.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_model = replacement
	_model_scale = replacement.scale
	_model_rotation = replacement.rotation
	var collider := $CollisionShape3D as CollisionShape3D
	collider.shape = collider.shape.duplicate()
	collider.shape.radius = 0.26 if sex == SEX.FEMALE else 0.31
	replacement.position.y = -collider.shape.radius + 0.0025
	$Splash.position = Vector3(0, -0.04, 0) if sex == SEX.FEMALE else Vector3(0, -0.05, 0.15)
	_pose = POSE.OPEN
	_requested_animation = &"Idle"
	if _model_initialized:
		animation_player.animation_finished.connect(_on_animation_finished)
		_play_animation(&"HeldIdle" if _state == STATE.HELD else (&"Fall" if _state == STATE.FALLING else &"Idle"))

func _advance_activity_timers(delta: float) -> void:
	super._advance_activity_timers(delta)
	_aggression_retry = maxf(0.0,_aggression_retry-delta)

func _tick_priority_activity(delta: float) -> bool:
	if _job.get("kind","") == "damage":
		var target = _job.get("target")
		if not _effect_done and (not is_instance_valid(target) or target.is_queued_for_deletion()):
			interrupt_activity()
	if _pose in [POSE.CURLING,POSE.IMPACT,POSE.UNCURLING]:
		if _pose == POSE.IMPACT:
			_elapsed += delta
			if not _effect_done and _elapsed >= 0.18:
				_effect_done = true
				if _apply_effect():
					_work_cycles += 1
		return true
	if _job.get("kind","") != "damage" and _aggression_wait > 0.0 and _on_dry_ground():
		if activity != ACTIVITY.LEISURE:
			interrupt_activity()
			_begin_break()
			_leisure_duration = _aggression_wait
		_tick_rest(delta)
		return true
	return false

func _enforce_mood() -> void:
	var ended_attack := _ai_state() == "attack" and not _mood_allows("attack")
	if ended_attack:
		_aggression_wait = maxf(_aggression_wait,_species.aggression_cooldown)
	super._enforce_mood()
	if ended_attack:
		_leisure_duration = _aggression_wait

func _try_aggression() -> bool:
	if not _mood_allows("attack"):
		return false
	if _job.get("kind", "") == "damage" or _aggression_wait > 0.0 or _aggression_retry > 0.0 or not _map.navigation.ready_for_paths or not _on_dry_ground():
		return false
	_aggression_retry = 0.8
	var attack := _damage_job()
	if attack.is_empty():
		return false
	interrupt_activity()
	_job = attack
	_effect_done = false
	_path_revision = _map.navigation.revision
	_start_path(attack.path,ACTIVITY.MOVING_TO_GROUND,ACTIVITY.NO_GROUND)
	return not _path.is_empty()

func _can_attack() -> bool:
	return true

func _finish_work() -> void:
	var attacked: bool = _job.get("kind", "") == "damage"
	super._finish_work()
	if attacked:
		_aggression_wait = _species.aggression_cooldown
		_begin_break()
		_leisure_duration = _aggression_wait

func _on_path_started(moving: ACTIVITY) -> void:
	if moving != ACTIVITY.MOVING_TO_REST:
		_rubbing_job.clear()
	super._on_path_started(moving)
	_curl_remaining = 0.0
	_uncurl_remaining = 0.0
	if _path.is_empty():
		_pose = POSE.OPEN
		_play_animation(&"Idle")
	elif sex == SEX.MALE and moving == ACTIVITY.MOVING_TO_GROUND and _job.get("kind","") == "damage":
		face_point(_path[0],&"Idle")
		_pose = POSE.CURLING
		_show_animation(&"Curl")

func _path_tolerance() -> float:
	return 0.07 if _pose == POSE.RIDING else super._path_tolerance()

func _path_speed() -> float:
	return _species.walk_speed*6.0 if _pose == POSE.RIDING else super._path_speed()

func _complete_work_path() -> void:
	if _pose == POSE.RIDING:
		activity = ACTIVITY.SHAKING
		_pose = POSE.IMPACT
		_show_animation(&"Impact",0.04)
	else:
		super._complete_work_path()
		_uncurl_remaining = 0.0
	$Splash.emitting = false

func movement_animation() -> StringName:
	return &"water/Swim" if _swimming else (&"Ride" if _pose == POSE.RIDING else &"Walk")

func _play_animation(name: StringName, blend: float = 0.12) -> bool:
	if animation_player == null:
		return false
	if name in [&"HeldIdle", &"Fall", &"Land", &"water/Swim"]:
		_pose = POSE.OPEN
	if name == &"Uncurl":
		name = &"Idle"
	if name == &"behaviour/Call" and _requested_animation != name:
		SoundEffects.play_at(StringName(str(species_id) + "_voice"), global_position, self, 1.1 if sex == SEX.FEMALE else 0.9)
	_requested_animation = name
	var clip := _clip_name(name)
	_show_animation(clip, blend)
	return animation_player.has_animation(clip)

func _clip_name(name: StringName) -> StringName:
	if name == &"Idle" and activity == ACTIVITY.EATING:
		return &"Eat"
	if name == &"behaviour/Rest":
		return &"Rest"
	if name == &"behaviour/Call":
		return &"Call"
	if name == &"water/Swim":
		return &"Swim"
	return name

func _show_animation(name: StringName, blend: float = 0.12) -> void:
	var clip: StringName = name if animation_player.has_animation(name) else &"Idle"
	if clip not in [&"Ride", &"Walk"]:
		animation_player.speed_scale = 1.0
	if animation_player.current_animation != clip:
		animation_player.play(clip, blend)

func _on_animation_finished(name: StringName) -> void:
	super._on_animation_finished(name)
	if name == &"Curl" and _pose == POSE.CURLING:
		_pose = POSE.IMPACT if _path.is_empty() else POSE.RIDING
		_show_animation(&"Impact" if _path.is_empty() else &"Ride", 0.0)
	elif name == &"Impact" and _pose == POSE.IMPACT:
		_pose = POSE.UNCURLING
		_show_animation(&"Uncurl", 0.0)
	elif name == &"Uncurl" and _pose == POSE.UNCURLING:
		_pose = POSE.OPEN
		_finish_work()

func _update_visual_activity() -> void:
	super._update_visual_activity()
	if animation_player == null:
		return
	var clip := animation_player.current_animation
	if clip in [&"Walk", &"Ride"]:
		var stride := RIDE_DISTANCE if clip == &"Ride" else (FEMALE_WALK_DISTANCE if sex == SEX.FEMALE else MALE_WALK_DISTANCE)
		animation_player.speed_scale = Vector2(velocity.x, velocity.z).length() * animation_player.get_animation(clip).length / (stride * absf(_model.scale.x))
	elif clip in [&"Work", &"ShakeSand", &"Attack"]:
		animation_player.speed_scale = animation_player.get_animation(clip).length / _species.production_seconds * work_efficiency()

func _apply_avoidance(delta: float) -> void:
	if _pose in [POSE.CURLING, POSE.IMPACT, POSE.UNCURLING] or (activity == ACTIVITY.LEISURE and animation_player.current_animation == &"Rub"):
		velocity.x = 0.0
		velocity.z = 0.0
		return
	super._apply_avoidance(delta)

func _tick_work(delta: float) -> void:
	if not _on_dry_ground():
		interrupt_activity()
		_begin_break()
		return
	if sex == SEX.MALE and _job.get("kind", "") == "damage":
		if _effect_done:
			_finish_work()
		else:
			_pose = POSE.CURLING
			_elapsed = 0.0
			_show_animation(&"Curl")
		return
	if _job.get("kind", "") == "damage" and is_instance_valid(_job.get("target")):
		face_point(_job.target.global_position, work_animation())
	else:
		_play_animation(work_animation())
	_elapsed += delta * work_efficiency()
	if not _effect_done and _elapsed >= _species.impact_time:
		_effect_done = true
		if _apply_effect():
			_work_cycles += 1
	if _elapsed >= _species.production_seconds:
		_finish_work()

func work_animation() -> StringName:
	return &"ShakeSand" if _job.get("kind", "") == "sand" else (&"Attack" if _job.get("kind", "") == "damage" else &"Work")

func _settle_rest() -> void:
	if _aggression_wait > 0.0:
		super._settle_rest()
		return
	if sex == SEX.FEMALE and _rubbing_job.is_empty() and _on_dry_ground():
		_rubbing_job = _find_rubbing_rock()
		if not _rubbing_job.is_empty():
			_start_path(_rubbing_job.path, ACTIVITY.MOVING_TO_REST, ACTIVITY.SEEKING_REST)
			if not _path.is_empty():
				return
			_rubbing_job.clear()
	super._settle_rest()

func _tick_rest(delta: float) -> void:
	if not _rubbing_job.is_empty() and (not _valid_rubbing_rock() or not _on_dry_ground()):
		_rubbing_job.clear()
	if _rubbing_job.is_empty():
		super._tick_rest(delta)
	else:
		var rock := _rubbing_job.target as HarvestableDeposit
		var stand: Vector3 = _rubbing_job.point
		var difference := Vector2(stand.x - global_position.x, stand.z - global_position.z)
		if difference.length() > 0.2 or not _rubbing_space_clear(stand, rock):
			_rubbing_job.clear()
			super._tick_rest(delta)
			return
		if difference.length() > 0.025:
			walk_direction(difference.normalized(), minf(_species.walk_speed, difference.length() / maxf(delta, 0.001)))
			return
		var side := (rock.global_position - global_position) * Vector3(1, 0, 1)
		var facing := Vector3(-side.z, 0, side.x).normalized()
		_rest_rotation.y = atan2(facing.x, facing.z)
		_play_animation(&"Rub" if absf(angle_difference(rotation.y, _rest_rotation.y)) < 0.06 else &"Idle")
		_leisure_elapsed += delta
		if _leisure_elapsed >= _leisure_duration:
			_rubbing_job.clear()
			_finish_break()

func _reset_work_state() -> void:
	_pose = POSE.OPEN
	_rubbing_job.clear()
	super._reset_work_state()

func _after_activity_interrupted() -> void:
	if _state == STATE.GROUNDED and _pose == POSE.OPEN:
		_play_animation(&"Idle")

func _find_rubbing_rock() -> Dictionary:
	var rocks: Array[Node] = _map.rock_controller.get_children()
	rocks.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	for node in rocks:
		var rock := node as HarvestableDeposit
		if not is_instance_valid(rock) or rock.exhausted or rock.is_queued_for_deletion() or rock.mesh == null:
			continue
		if Vector2(rock.global_position.x - global_position.x, rock.global_position.z - global_position.z).length() > _species.production_radius:
			continue
		var reach := maxf(rock.mesh.get_aabb().size.x, rock.mesh.get_aabb().size.z) * rock.scale.x * 0.45 + body_radius() + 0.035
		var best: Dictionary = {}
		var shortest := INF
		for index in 24:
			var angle := index * TAU / 24.0
			var stand: Vector3 = _map.terrain_controller.surface_position(rock.global_position + Vector3(cos(angle), 0, sin(angle)) * reach)
			if stand.y <= _map.water_controller.water_level + 0.08 or _map.terrain_controller.slope_at(stand) > 0.35:
				continue
			if not _map.navigation.space_available(stand, self):
				continue
			var approach: Vector3 = _map.terrain_controller.surface_position(stand + Vector3(cos(angle), 0, sin(angle)) * 0.65)
			var route: PackedVector3Array = _map.navigation.path_to(global_position, approach)
			if route.is_empty() or not _rubbing_space_clear(stand, rock) or not _approach_clear(route[-1], stand):
				continue
			route.append(stand)
			var length := global_position.distance_to(route[0])
			for step in range(1, route.size()):
				length += route[step - 1].distance_to(route[step])
			if length < shortest:
				shortest = length
				best = {"kind": "rub", "target": rock, "point": stand, "path": route}
		if not best.is_empty():
			return best
	return {}

func _rubbing_space_clear(point: Vector3, rock: HarvestableDeposit) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = body_radius()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = point + Vector3.UP * (body_radius() + 0.02)
	query.collision_mask = 6
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * body_radius(), rock.global_position + Vector3.UP * body_radius(), 6)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and rock.is_ancestor_of(hit.collider)

func _approach_clear(origin: Vector3, target: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = body_radius()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = origin + Vector3.UP * (body_radius() + 0.03)
	query.motion = target - origin
	query.collision_mask = 6
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	return fractions[0] >= 0.99

func _valid_rubbing_rock() -> bool:
	var target = _rubbing_job.get("target")
	return is_instance_valid(target) and target is HarvestableDeposit and not target.exhausted and not target.is_queued_for_deletion()

func _rest_presentation() -> Dictionary:
	if _aggression_wait > 0.0 and activity == ACTIVITY.LEISURE:
		return _present_activity("Resting","status_rest","Resting after a charge")
	if not _rubbing_job.is_empty():
		return _present_activity("Resting","status_rest","Rubbing against a rock to relax" if activity == ACTIVITY.LEISURE else "Walking to a rock")
	return super._rest_presentation()

func _work_presentation() -> Dictionary:
	if activity == ACTIVITY.SHAKING and _job.get("kind","") == "sand":
		return _present_activity("Working","status_work","Shaking off sand")
	if activity == ACTIVITY.MOVING_TO_GROUND and _job.get("kind","") != "damage":
		return _present_activity("On the move","status_walk","Walking to a work site")
	return super._work_presentation()
