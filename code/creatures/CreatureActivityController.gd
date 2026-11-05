class_name CreatureActivityController
extends Creature

@export var swimming_library: AnimationLibrary
@export var behaviour_library: AnimationLibrary

enum ACTIVITY { SEEKING_WATER, MOVING_TO_WATER, BATHING, SEEKING_GROUND, MOVING_TO_GROUND, SHAKING, RESTING, HUNGRY, NO_WATER, NO_GROUND, MOVING_TO_FOOD, EATING, SWIMMING, SEEKING_REST, MOVING_TO_REST, LEISURE }

var activity: ACTIVITY = ACTIVITY.SEEKING_GROUND
var carrying_water := false
var _feeder: FeederController
var _map: Node3D
var _path := PackedVector3Array()
var _path_index := 0
var _path_revision := -1
var _elapsed := 0.0
var _bath_elapsed := 0.0
var _food_retry := 0.0
var _stuck := 0.0
var _last_position := Vector3.ZERO
var _model_rotation := Vector3.ZERO
var _swimming := false
var _work_cycles := 0
var _cycles_until_leisure := 1
var _leisure_duration := 0.0
var _leisure_elapsed := 0.0

func prepare_appearance() -> void:
	super.prepare_appearance()
	_configure_animation_libraries()

func _configure_animation_libraries() -> void:
	if animation_player == null:
		return
	if not animation_player.has_animation_library(&"water"):
		if animation_player.has_animation(&"Swim"):
			var library := AnimationLibrary.new()
			library.add_animation(&"Swim", animation_player.get_animation(&"Swim"))
			animation_player.add_animation_library(&"water", library)
		elif swimming_library != null:
			animation_player.add_animation_library(&"water", swimming_library)
	if not animation_player.has_animation_library(&"behaviour"):
		if animation_player.has_animation(&"Rest") and animation_player.has_animation(&"Call"):
			var library := AnimationLibrary.new()
			library.add_animation(&"Rest", animation_player.get_animation(&"Rest"))
			library.add_animation(&"Call", animation_player.get_animation(&"Call"))
			animation_player.add_animation_library(&"behaviour", library)
		elif behaviour_library != null:
			animation_player.add_animation_library(&"behaviour", behaviour_library)

func _ready() -> void:
	super._ready()
	_map = get_parent().get_node_or_null("Map") if get_parent() != null else null
	if _map == null:
		_map = get_parent() if get_parent() is MapManager else null
	if _map != null:
		_map.navigation.navigation_changed.connect(_on_navigation_changed)
	if _model != null:
		_model_rotation = _model.rotation
	_choose_leisure_interval()
	activity = _next_work_activity()

func _physics_process(delta: float) -> void:
	if _map == null or _state == STATE.HELD:
		super._physics_process(delta)
		return
	var depth: float = _map.water_controller.water_level-terrain_controller.surface_position(global_position).y
	var threshold := _species.minimum_swim_depth-0.1 if _swimming else _species.minimum_swim_depth
	var was_swimming := _swimming
	_swimming = depth >= threshold and global_position.y <= _map.water_controller.global_position.y+0.8
	if _swimming and not was_swimming and species_id != &"tuftling":
		SoundEffects.play_at(&"water_splash",global_position,self)
	if not _swimming and _state in [STATE.LANDING,STATE.FALLING]:
		super._physics_process(delta)
		return
	if _swimming:
		_state = STATE.GROUNDED
		_airborne_elapsed = 0.0
	_enforce_mood()
	_tick_activity(delta)
	if _swimming:
		_play_animation(&"water/Swim")
		var height: float = _map.water_controller.global_position.y+body_radius()*0.3+sin(Time.get_ticks_msec()*0.002)*body_radius()*0.08
		height = maxf(height,terrain_controller.surface_position(global_position).y+body_radius()+0.04)
		velocity.y = clampf((height-global_position.y)*5.0,-2.0,2.0)
		_apply_avoidance(delta)
		_update_rotation(_rest_rotation,delta)
		move_and_slide()
	else:
		super._physics_process(delta)
	_update_visual_activity()

func _update_visual_activity() -> void:
	if _model != null:
		_model.rotation = _model_rotation
		if _model is CreatureCelAppearance:
			_update_skeletal_animation_speed()
			return
		if activity == ACTIVITY.SHAKING:
			_model.rotation.z += sin(_elapsed*34.0)*0.16
			_model.rotation.y += sin(_elapsed*28.0)*0.10
		elif activity == ACTIVITY.EATING:
			_model.rotation.x += sin(_elapsed*9.0)*0.045

func _update_skeletal_animation_speed() -> void:
	var appearance := _model as CreatureCelAppearance
	if appearance == null or animation_player == null:
		return
	var clip := animation_player.current_animation
	if clip == &"Walk":
		var distance := appearance.walk_distance * absf(appearance.scale.x)
		animation_player.speed_scale = Vector2(velocity.x, velocity.z).length() * animation_player.get_animation(clip).length / maxf(distance, 0.001)
	elif clip == &"Work":
		animation_player.speed_scale = animation_player.get_animation(clip).length / maxf(work_cycle_seconds(), 0.01)

func walk_direction(direction: Vector2, speed: float) -> void:
	var appearance := _model as CreatureCelAppearance
	if appearance != null and movement_animation() == &"Walk":
		speed = minf(speed, appearance.walk_speed)
	super.walk_direction(direction, speed)

func work_cycle_seconds() -> float:
	return _species.production_seconds

func _tick_activity(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_advance_activity_timers(delta)
	if _map.breeding.is_breeding(self):
		_map.breeding.move_creature(self,delta)
		return
	if _tick_priority_activity(delta):
		return
	if _map.navigation.ready_for_paths and _path_revision != _map.navigation.revision:
		_on_navigation_changed()
	if _tick_ai(delta):
		return
	if activity == ACTIVITY.LEISURE:
		_tick_rest(delta)
		return
	if _tick_work_activity(delta):
		return
	if not _map.navigation.ready_for_paths:
		return
	if activity == ACTIVITY.SEEKING_REST:
		if _on_dry_ground():
			_settle_rest()
		else:
			_elapsed += delta
			if _elapsed >= 0.75:
				_start_path(_map.navigation.route_to_resting_ground(global_position,self),ACTIVITY.MOVING_TO_REST,ACTIVITY.SEEKING_REST)
		return
	if not _path.is_empty():
		if _path_ready_to_move(delta):
			_follow_path(delta)
		return
	_elapsed += delta
	_select_work()

func _advance_activity_timers(_delta: float) -> void:
	pass

func _tick_priority_activity(_delta: float) -> bool:
	return false

func _tick_work_activity(_delta: float) -> bool:
	return false

func _path_ready_to_move(_delta: float) -> bool:
	return true

func _select_work() -> void:
	pass

func _next_work_activity() -> ACTIVITY:
	return ACTIVITY.SEEKING_GROUND

func _begin_break() -> void:
	_map.navigation.release_place(self)
	_path.clear()
	_leisure_elapsed = 0.0
	_leisure_duration = randf_range(_species.leisure_seconds_min,maxf(_species.leisure_seconds_min,_species.leisure_seconds_max))
	_elapsed = 0.75
	if _on_dry_ground():
		_settle_rest()
	else:
		activity = ACTIVITY.SEEKING_REST

func _on_dry_ground() -> bool:
	return not _swimming and terrain_controller.surface_position(global_position).y > _map.water_controller.global_position.y+0.03

func _settle_rest() -> void:
	_map.navigation.release_place(self)
	_path.clear()
	if not _on_dry_ground():
		activity = ACTIVITY.SEEKING_REST
		_elapsed = 0.75
		return
	activity = ACTIVITY.LEISURE
	if not _play_animation(&"behaviour/Rest"):
		_play_animation(&"Idle")

func _tick_rest(delta: float) -> void:
	if not _on_dry_ground():
		activity = ACTIVITY.SEEKING_REST
		_elapsed = 0.75
		return
	_leisure_elapsed += delta
	if not _play_animation(&"behaviour/Rest"):
		_play_animation(&"Idle")
	if _leisure_elapsed < _leisure_duration:
		return
	_finish_break()

func _finish_break() -> void:
	_work_cycles = 0
	_choose_leisure_interval()
	_map.navigation.release_place(self)
	activity = _next_work_activity()
	_elapsed = 0.0

func work_burst_size() -> int:
	match mood():
		MOOD.HAPPY:
			return 3
		MOOD.NEUTRAL:
			return 2
	return 1

func _choose_leisure_interval() -> void:
	_cycles_until_leisure = work_burst_size()

func _continue_work() -> void:
	_map.navigation.release_place(self)
	if _work_cycles >= work_burst_size():
		_begin_break()
	else:
		activity = _next_work_activity()
		_elapsed = 0.8

func _start_path(path: PackedVector3Array, moving: ACTIVITY, failure: ACTIVITY) -> void:
	_map.navigation.release_place(self)
	if not path.is_empty() and not _map.navigation.reserve_place(self,path[-1]):
		path = PackedVector3Array()
	_path = path
	_path_index = 0
	_elapsed = 0
	_stuck = 0
	_last_position = global_position
	activity = moving if not path.is_empty() else failure
	_on_path_started(moving)

func _on_path_started(_moving: ACTIVITY) -> void:
	pass

func _follow_path(delta: float) -> void:
	var target := _path[_path_index]
	var difference := Vector2(target.x-global_position.x,target.z-global_position.z)
	var arrived := difference.length() < _path_tolerance()
	if activity == ACTIVITY.MOVING_TO_WATER and _path_index == _path.size()-1:
		var depth: float = _map.water_controller.water_level-terrain_controller.surface_position(global_position).y
		arrived = arrived and depth >= _species.minimum_swim_depth
	elif activity == ACTIVITY.MOVING_TO_REST and _path_index == _path.size()-1:
		arrived = arrived and _on_dry_ground()
	if arrived:
		_path_index += 1
		if _path_index >= _path.size():
			_path.clear()
			_elapsed = 0.0
			_complete_path()
		return
	walk_direction(difference.normalized(),minf(_path_speed(),difference.length()/maxf(delta,0.001)))
	_stuck += delta
	if _stuck > 2.0:
		if Vector2(global_position.x-_last_position.x,global_position.z-_last_position.z).length() < 0.12:
			_map.navigation.avoid_blocked_route(self,target)
			_path.clear()
			if activity == ACTIVITY.MOVING_TO_REST:
				activity = ACTIVITY.SEEKING_REST
			elif activity == ACTIVITY.MOVING_TO_FOOD:
				activity = ACTIVITY.HUNGRY
			else:
				interrupt_activity()
			_elapsed = 0.0
		_last_position = global_position
		_stuck = 0.0

func _path_tolerance() -> float:
	return 0.025 if _model is CreatureCelAppearance and _path_index == _path.size()-1 else 0.14

func _path_speed() -> float:
	return _species.swim_speed if _swimming else _species.walk_speed

func _complete_path() -> void:
	match activity:
		ACTIVITY.MOVING_TO_FOOD:
			activity = ACTIVITY.EATING
			if is_instance_valid(_feeder):
				var facing := _feeder.global_position-global_position
				_rest_rotation.y = atan2(facing.x,facing.z)
			_play_animation(&"water/Swim" if _swimming else &"Idle")
		ACTIVITY.MOVING_TO_REST:
			_settle_rest()
		_:
			_complete_work_path()

func _complete_work_path() -> void:
	activity = ACTIVITY.SHAKING
	$Splash.restart()
	$Splash.emitting = true
	_play_animation(&"water/Swim" if _swimming else &"Idle")

func begin_hold() -> void:
	interrupt_activity()
	super.begin_hold()

func _follow_ground() -> void:
	if _map != null and _map.water_controller.water_level-terrain_controller.surface_position(global_position).y >= _species.minimum_swim_depth:
		return
	super._follow_ground()

func activity_presentation() -> Dictionary:
	if _state != STATE.GROUNDED:
		return super.activity_presentation()
	if _map != null and _map.breeding.is_breeding(self):
		return _present_activity("Breeding","breeding_heart",_map.breeding.activity_text(self))
	if activity in [ACTIVITY.LEISURE,ACTIVITY.RESTING,ACTIVITY.SEEKING_REST,ACTIVITY.MOVING_TO_REST]:
		return _rest_presentation()
	if _map == null or not _map.navigation.ready_for_paths:
		return _present_activity("Resting","status_rest","Waiting for a clear route")
	match activity:
		ACTIVITY.HUNGRY:
			return _present_activity("Hungry","status_satiety","Hungry")
		ACTIVITY.MOVING_TO_FOOD:
			return _present_activity("Seeking food","status_satiety","Walking to a feeder")
		ACTIVITY.EATING:
			return _present_activity("Eating","status_satiety","Eating")
	return _work_presentation()

func _rest_presentation() -> Dictionary:
	match activity:
		ACTIVITY.SEEKING_REST:
			return _present_activity("Resting","status_rest","Looking for a dry resting place")
		ACTIVITY.MOVING_TO_REST:
			return _present_activity("Resting","status_walk","Walking to a resting place")
		ACTIVITY.LEISURE:
			return _present_activity("Resting","status_rest","Enjoying free time")
	return _present_activity("Resting","status_rest","Taking a short break")

func _work_presentation() -> Dictionary:
	return _present_activity("Working","status_work","Looking for a place to work")

func _ai_state() -> String:
	if activity in [ACTIVITY.MOVING_TO_FOOD,ACTIVITY.EATING]:
		return "feed"
	if activity in [ACTIVITY.SEEKING_REST,ACTIVITY.MOVING_TO_REST,ACTIVITY.LEISURE]:
		return "rest"
	return "work"

func _can_attack() -> bool:
	return false

func _try_aggression() -> bool:
	return false

func _mood_allows(action: String) -> bool:
	match action:
		"feed", "rest", "work":
			return true
		"attack":
			return mood() == MOOD.UNHAPPY and _can_attack()
	return false

func _enforce_mood() -> void:
	_cycles_until_leisure = work_burst_size()
	if _map.breeding.is_breeding(self) or _mood_allows(_ai_state()):
		return
	interrupt_activity()
	_begin_break()

func _ai_context() -> Dictionary:
	return {"hungry":int(satiety <= _species.feeding_threshold),"needs_break":int(_work_cycles >= _cycles_until_leisure),"happy":int(mood() == MOOD.HAPPY),"neutral":int(mood() == MOOD.NEUTRAL),"unhappy":int(mood() == MOOD.UNHAPPY),"aggressive":int(mood() == MOOD.UNHAPPY),"can_attack":int(_can_attack()),"work_allowed":int(_mood_allows("work")),"satiety":satiety,"happiness":happiness,"companions":companions,"crowding":crowding_stress*100.0,"noise":noise_stress*100.0,"neighbours":species_stress*100.0,"work_cycles":_work_cycles,"female":int(sex == SEX.FEMALE),"carrying_water":int(carrying_water),"swimming":int(_swimming),"dry_ground":int(_on_dry_ground()),"navigation_ready":int(_map.navigation.ready_for_paths)}

func _tick_ai(delta: float) -> bool:
	if activity in [ACTIVITY.MOVING_TO_FOOD,ACTIVITY.EATING]:
		if _tick_hunger(delta,true):
			return true
	else:
		_food_retry = maxf(0.0,_food_retry-delta)
	for action: String in CreatureAiGraph.choices(_species.ai_graph,_ai_state(),_ai_context()):
		if not _mood_allows(action):
			continue
		match action:
			"feed":
				if _tick_hunger(0.0,true):
					return true
			"attack":
				if _try_aggression():
					return true
			"rest":
				if _ai_state() == "attack" or activity == ACTIVITY.SHAKING:
					return false
				if activity in [ACTIVITY.SEEKING_REST,ACTIVITY.MOVING_TO_REST,ACTIVITY.LEISURE]:
					return false
				if _map.navigation.ready_for_paths:
					_begin_break()
					return true
			"work":
				return false
	if not _mood_allows("work"):
		if _ai_state() in ["rest","attack"]:
			return false
		interrupt_activity()
		_begin_break()
		return true
	if activity == ACTIVITY.SHAKING:
		return false
	interrupt_activity()
	activity = ACTIVITY.RESTING
	_play_animation(movement_animation() if _swimming else &"Idle")
	return true

func _tick_hunger(delta: float, policy_triggered: bool = false) -> bool:
	_food_retry = maxf(0.0,_food_retry-delta)
	if activity in [ACTIVITY.MOVING_TO_FOOD,ACTIVITY.EATING]:
		if not is_instance_valid(_feeder) or _feeder.is_queued_for_deletion() or not _feeder.can_feed(_species):
			interrupt_activity()
			_food_retry = 1.0
			return false
		if activity == ACTIVITY.MOVING_TO_FOOD:
			if not _path.is_empty():
				_follow_path(delta)
				if activity in [ACTIVITY.MOVING_TO_FOOD,ACTIVITY.EATING]:
					return true
			interrupt_activity()
			_food_retry = 1.0
			return false
		if not _at_feeder():
			interrupt_activity()
			_food_retry = 1.0
			return false
		var eating := animation_player != null and animation_player.has_animation(&"Eat")
		_play_animation(&"water/Swim" if _swimming else (&"Eat" if eating else &"Idle"))
		_elapsed += delta
		if _elapsed >= _species.feeding_seconds:
			if not _feeder.eat(_species):
				interrupt_activity()
				_food_retry = 1.0
				return false
			restore_satiety(_species.satiety_per_meal)
			_map.navigation.release_place(self)
			_feeder = null
			activity = ACTIVITY.RESTING
			_elapsed = 0.0
		return true
	if activity == ACTIVITY.HUNGRY:
		interrupt_activity()
	if (not policy_triggered and satiety > _species.feeding_threshold) or _food_retry > 0.0 or not _map.navigation.ready_for_paths:
		return false
	_food_retry = 1.0
	var route: Dictionary = _map.navigation.route_to_feeder(global_position,_species,self)
	if route.is_empty():
		return false
	interrupt_activity()
	_feeder = route.feeder
	_path_revision = _map.navigation.revision
	_start_path(route.path,ACTIVITY.MOVING_TO_FOOD,ACTIVITY.HUNGRY)
	if _path.is_empty():
		interrupt_activity()
		return false
	return true

func _at_feeder() -> bool:
	for point in _feeder.feeding_positions():
		if Vector2(point.x-global_position.x,point.z-global_position.z).length() < 0.7:
			return true
	return false

func interrupt_activity() -> void:
	_reset_work_state()
	super.interrupt_activity()
	_path.clear()
	_feeder = null
	_elapsed = 0.0
	_bath_elapsed = 0.0
	activity = _next_work_activity()
	if _model != null:
		_model.rotation = _model_rotation
	_after_activity_interrupted()

func _reset_work_state() -> void:
	pass

func _after_activity_interrupted() -> void:
	pass

func movement_animation() -> StringName:
	return &"water/Swim" if _swimming else &"Walk"

func _on_navigation_changed() -> void:
	if _map == null or not _map.navigation.ready_for_paths or not is_grounded() or _map.breeding.is_breeding(self):
		return
	if _preserve_work_on_navigation_changed():
		_path_revision = _map.navigation.revision
		return
	_reset_work_state()
	_map.navigation.release_place(self)
	_path.clear()
	_path_index = 0
	_path_revision = _map.navigation.revision
	_feeder = null
	_elapsed = 0.0
	_bath_elapsed = 0.0
	_stuck = 0.0
	if activity in [ACTIVITY.SEEKING_REST,ACTIVITY.MOVING_TO_REST,ACTIVITY.LEISURE]:
		if _on_dry_ground():
			_settle_rest()
		else:
			activity = ACTIVITY.SEEKING_REST
			_elapsed = 0.75
	else:
		activity = _next_work_activity()
	_after_activity_interrupted()

func _preserve_work_on_navigation_changed() -> bool:
	return false
