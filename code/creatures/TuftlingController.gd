class_name TuftlingController
extends Creature

@export var swimming_library: AnimationLibrary
@export var behaviour_library: AnimationLibrary

enum ACTIVITY { SEEKING_WATER, MOVING_TO_WATER, BATHING, SEEKING_GROUND, MOVING_TO_GROUND, SHAKING, RESTING, HUNGRY, NO_WATER, NO_GROUND, MOVING_TO_FOOD, EATING, SWIMMING, SEEKING_REST, MOVING_TO_REST, LEISURE }

var activity: ACTIVITY = ACTIVITY.SEEKING_WATER
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

func _ready() -> void:
	if swimming_library != null and animation_player != null and not animation_player.has_animation_library(&"water"):
		animation_player.add_animation_library(&"water",swimming_library)
	if behaviour_library != null and animation_player != null and not animation_player.has_animation_library(&"behaviour"):
		animation_player.add_animation_library(&"behaviour",behaviour_library)
	super._ready()
	_map = get_parent().get_node_or_null("Map") if get_parent() != null else null
	if _map == null:
		_map = get_parent() if get_parent() is MapManager else null
	if _map != null:
		_map.navigation.navigation_changed.connect(_on_navigation_changed)
	if _model != null:
		_model_rotation = _model.rotation
	_choose_leisure_interval()

func _physics_process(delta: float) -> void:
	if _map == null or _state == STATE.HELD:
		super._physics_process(delta)
		return
	var depth: float = _map.water_controller.water_level-terrain_controller.surface_position(global_position).y
	var threshold := _species.minimum_swim_depth-0.1 if _swimming else _species.minimum_swim_depth
	var was_swimming := _swimming
	_swimming = depth >= threshold and global_position.y <= _map.water_controller.global_position.y+0.8
	var near_ground := global_position.y-terrain_controller.surface_position(global_position).y <= body_radius()+0.35
	if _swimming and not was_swimming:
		SoundEffects.play_at(&"water_splash",global_position,self)
	if not _swimming and (_state == STATE.LANDING or (_state == STATE.FALLING and not near_ground)):
		super._physics_process(delta)
		return
	if _swimming:
		_state = STATE.GROUNDED
		_airborne_elapsed = 0.0
	_tick_activity(delta)
	if _swimming:
		_play_animation(&"water/Swim")
		var height: float = _map.water_controller.global_position.y+0.2+sin(Time.get_ticks_msec()*0.002)*0.025
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
		if activity == ACTIVITY.SHAKING:
			_model.rotation.z += sin(_elapsed*34.0)*0.16
			_model.rotation.y += sin(_elapsed*28.0)*0.10
		elif activity == ACTIVITY.EATING:
			_model.rotation.x += sin(_elapsed*9.0)*0.045

func _tick_activity(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	if _map.breeding.is_breeding(self):
		_map.breeding.move_creature(self,delta)
		return
	if not _map.navigation.ready_for_paths:
		if satiety <= 0.0:
			activity = ACTIVITY.HUNGRY
			_path.clear()
			return
		if activity == ACTIVITY.LEISURE and satiety > 0.0:
			_tick_rest(delta)
		return
	if _path_revision != _map.navigation.revision:
		_on_navigation_changed()
	if satiety <= 0.0 or activity in [ACTIVITY.MOVING_TO_FOOD,ACTIVITY.EATING]:
		_tick_hunger(delta)
		return
	_food_retry -= delta
	if satiety <= _species.feeding_threshold and _food_retry <= 0.0:
		_food_retry = 1.0
		var route: Dictionary = _map.navigation.route_to_feeder(global_position,_species,self)
		if not route.is_empty():
			_feeder = route.feeder
			_start_path(route.path,ACTIVITY.MOVING_TO_FOOD,ACTIVITY.HUNGRY)
			return
	if activity == ACTIVITY.LEISURE:
		_tick_rest(delta)
		return
	if activity not in [ACTIVITY.SEEKING_REST,ACTIVITY.MOVING_TO_REST] and _work_cycles >= _cycles_until_leisure:
		_begin_break()
		return
	if activity == ACTIVITY.SEEKING_REST:
		if _on_dry_ground():
			_settle_rest()
		else:
			_elapsed += delta
			if _elapsed >= 0.75:
				_start_path(_map.navigation.route_to_resting_ground(global_position,self),ACTIVITY.MOVING_TO_REST,ACTIVITY.SEEKING_REST)
		return
	if activity in [ACTIVITY.BATHING,ACTIVITY.SWIMMING]:
		if not _swimming:
			interrupt_activity()
			return
		_bath_elapsed += delta*work_efficiency()
		if _bath_elapsed >= _species.bathing_seconds:
			_map.navigation.release_place(self)
			_path.clear()
			carrying_water = true
			activity = ACTIVITY.SEEKING_GROUND
			_elapsed = 0
			return
	if not _path.is_empty():
		_follow_path(delta)
		return
	_elapsed += delta*work_efficiency() if activity == ACTIVITY.SHAKING else delta
	match activity:
		ACTIVITY.SEEKING_WATER:
			_start_path(_map.navigation.route_to_water(global_position,_species.minimum_swim_depth,self),ACTIVITY.MOVING_TO_WATER,ACTIVITY.NO_WATER)
		ACTIVITY.SEEKING_GROUND:
			_start_path(_map.navigation.route_to_sowing_ground(global_position,self),ACTIVITY.MOVING_TO_GROUND,ACTIVITY.NO_GROUND)
		ACTIVITY.BATHING:
			_play_animation(&"water/Swim")
			if _elapsed >= 0.3:
				_start_path(_map.navigation.bathing_route(self),ACTIVITY.SWIMMING,ACTIVITY.BATHING)
		ACTIVITY.SHAKING:
			if _elapsed >= _species.shaking_seconds:
				var planted: int = _map.vegetation_controller.seed_grass(global_position,_species.grass_per_cycle,_species.grass_radius)
				if planted > 0:
					SoundEffects.play_at(&"grass_work",global_position,self)
					carrying_water = false
					_work_cycles += 1
					_map.science.observe(species_id,&"create_grass",global_position)
				_map.navigation.release_place(self)
				activity = ACTIVITY.RESTING
				_elapsed = 0
		ACTIVITY.RESTING, ACTIVITY.NO_WATER, ACTIVITY.NO_GROUND:
			_play_animation(movement_animation() if _swimming else &"Idle")
			if _elapsed >= _species.resting_seconds:
				activity = ACTIVITY.SEEKING_GROUND if carrying_water else ACTIVITY.SEEKING_WATER
				_elapsed = 0

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
	_work_cycles = 0
	_choose_leisure_interval()
	activity = ACTIVITY.SEEKING_GROUND if carrying_water else ACTIVITY.SEEKING_WATER
	_elapsed = 0.0

func _choose_leisure_interval() -> void:
	_cycles_until_leisure = randi_range(_species.leisure_cycles_min,maxi(_species.leisure_cycles_min,_species.leisure_cycles_max))

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

func _follow_path(delta: float) -> void:
	var target := _path[_path_index]
	var difference := Vector2(target.x-global_position.x,target.z-global_position.z)
	var arrived := difference.length() < 0.14
	if activity == ACTIVITY.MOVING_TO_WATER and _path_index == _path.size()-1:
		var depth: float = _map.water_controller.water_level-terrain_controller.surface_position(global_position).y
		arrived = arrived and depth >= _species.minimum_swim_depth
	elif activity == ACTIVITY.MOVING_TO_REST and _path_index == _path.size()-1:
		arrived = arrived and _on_dry_ground()
	if arrived:
		_path_index += 1
		if _path_index >= _path.size():
			_path.clear()
			_elapsed = 0
			if activity == ACTIVITY.MOVING_TO_WATER:
				activity = ACTIVITY.BATHING
				_bath_elapsed = 0
			elif activity == ACTIVITY.SWIMMING:
				activity = ACTIVITY.BATHING
			elif activity == ACTIVITY.MOVING_TO_FOOD:
				activity = ACTIVITY.EATING
				if is_instance_valid(_feeder):
					var facing := _feeder.global_position-global_position
					_rest_rotation.y = atan2(facing.x,facing.z)
			elif activity == ACTIVITY.MOVING_TO_REST:
				_settle_rest()
				return
			else:
				activity = ACTIVITY.SHAKING
				$Splash.restart()
				$Splash.emitting = true
			_play_animation(&"water/Swim" if _swimming else &"Idle")
		return
	var speed := _species.swim_speed if _swimming else _species.walk_speed
	walk_direction(difference.normalized(),minf(speed,difference.length()/maxf(delta,0.001)))
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
				activity = ACTIVITY.SEEKING_GROUND if carrying_water else ACTIVITY.SEEKING_WATER
			_elapsed = 0.0
		_last_position = global_position
		_stuck = 0

func begin_hold() -> void:
	interrupt_activity()
	super.begin_hold()

func _follow_ground() -> void:
	if _map != null and _map.water_controller.water_level-terrain_controller.surface_position(global_position).y >= _species.minimum_swim_depth:
		return
	super._follow_ground()

func activity_text() -> String:
	if _state == STATE.HELD:
		return tr("Being carried")
	if _map != null and _map.breeding.is_breeding(self):
		return _map.breeding.activity_text(self)
	if activity == ACTIVITY.LEISURE:
		return tr("Enjoying free time")
	if _map == null or not _map.navigation.ready_for_paths:
		return tr("Waiting for a clear route")
	return [tr("Looking for water"),tr("Walking to water"),"Bathing",tr("Looking for soil"),tr("Walking to soil"),tr("Shaking and sowing grass"),tr("Resting"),tr("Hungry"),tr("Needs accessible water or a free bathing spot"),tr("Needs free dry soil"),tr("Walking to a feeder"),"Eating",tr("Swimming and bathing"),tr("Looking for a dry resting place"),tr("Walking to a resting place"),tr("Enjoying free time")][activity]

func _tick_hunger(delta: float) -> void:
	if activity == ACTIVITY.MOVING_TO_FOOD and is_instance_valid(_feeder) and _feeder.can_feed(_species) and not _path.is_empty():
		_follow_path(delta)
		return
	_play_animation(&"water/Swim" if _swimming else &"Idle")
	_elapsed += delta
	if activity == ACTIVITY.EATING:
		if not is_instance_valid(_feeder) or not _feeder.can_feed(_species) or not _at_feeder():
			activity = ACTIVITY.HUNGRY
			_map.navigation.release_place(self)
		elif _elapsed >= _species.feeding_seconds:
			if _feeder.eat(_species):
				restore_satiety(_species.satiety_per_meal)
				activity = ACTIVITY.RESTING
			else:
				activity = ACTIVITY.HUNGRY
			_map.navigation.release_place(self)
			_elapsed = 0.0
		return
	activity = ACTIVITY.HUNGRY
	if _elapsed < 1.0:
		return
	_elapsed = 0.0
	_map.navigation.release_place(self)
	_path.clear()
	var route: Dictionary = _map.navigation.route_to_feeder(global_position,_species,self)
	if not route.is_empty():
		_feeder = route.feeder
		_start_path(route.path,ACTIVITY.MOVING_TO_FOOD,ACTIVITY.HUNGRY)

func _at_feeder() -> bool:
	for point in _feeder.feeding_positions():
		if Vector2(point.x-global_position.x,point.z-global_position.z).length() < 0.7:
			return true
	return false

func interrupt_activity() -> void:
	super.interrupt_activity()
	_path.clear()
	_feeder = null
	_elapsed = 0.0
	_bath_elapsed = 0.0
	activity = ACTIVITY.SEEKING_GROUND if carrying_water else ACTIVITY.SEEKING_WATER
	if _model != null:
		_model.rotation = _model_rotation

func movement_animation() -> StringName:
	return &"water/Swim" if _swimming else &"Walk"

func _on_navigation_changed() -> void:
	if _map == null or not _map.navigation.ready_for_paths or _state == STATE.HELD or _map.breeding.is_breeding(self):
		return
	_map.navigation.release_place(self)
	_path.clear()
	_path_index = 0
	_path_revision = _map.navigation.revision
	_feeder = null
	_elapsed = 0.0
	_bath_elapsed = 0.0
	_stuck = 0.0
	if activity in [ACTIVITY.SEEKING_REST,ACTIVITY.MOVING_TO_REST,ACTIVITY.LEISURE] and satiety > 0.0:
		if _on_dry_ground():
			_settle_rest()
		else:
			activity = ACTIVITY.SEEKING_REST
			_elapsed = 0.75
		return
	activity = ACTIVITY.HUNGRY if satiety <= 0.0 else (ACTIVITY.SEEKING_GROUND if carrying_water else ACTIVITY.SEEKING_WATER)
