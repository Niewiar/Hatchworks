class_name TuftlingController
extends Creature

enum ACTIVITY { SEEKING_WATER, MOVING_TO_WATER, BATHING, SEEKING_GROUND, MOVING_TO_GROUND, SHAKING, RESTING, HUNGRY, NO_WATER, NO_GROUND, MOVING_TO_FOOD, EATING }

var activity: ACTIVITY = ACTIVITY.SEEKING_WATER
var carrying_water := false
var _feeder: FeederController
var _map: Node3D
var _path := PackedVector3Array()
var _path_index := 0
var _path_revision := -1
var _elapsed := 0.0
var _food_retry := 0.0
var _stuck := 0.0
var _last_position := Vector3.ZERO
var _model_rotation := Vector3.ZERO

func _ready() -> void:
	super._ready()
	_map = get_parent().get_node_or_null("Map") if get_parent() != null else null
	if _map == null:
		_map = get_parent() if get_parent() is MapManager else null
	if _model != null:
		_model_rotation = _model.rotation

func _physics_process(delta: float) -> void:
	if _map == null or _state == STATE.HELD:
		super._physics_process(delta)
		return
	var depth: float = _map.water_controller.water_level-terrain_controller.surface_position(global_position).y
	var swimming: bool = depth >= _species.minimum_swim_depth and global_position.y <= _map.water_controller.global_position.y+0.8
	if _state == STATE.FALLING and not swimming:
		super._physics_process(delta)
		return
	if swimming:
		_state = STATE.GROUNDED
	_tick_activity(delta,swimming)
	if swimming:
		var height: float = _map.water_controller.global_position.y+0.2+sin(Time.get_ticks_msec()*0.002)*0.025
		velocity.y = clampf((height-global_position.y)*5.0,-2.0,2.0)
		_update_rotation(_rest_rotation,delta)
		move_and_slide()
	else:
		super._physics_process(delta)
	if _model != null:
		_model.rotation = _model_rotation
		if activity == ACTIVITY.SHAKING:
			_model.rotation.z += sin(_elapsed*34.0)*0.16
			_model.rotation.y += sin(_elapsed*28.0)*0.10
		elif activity == ACTIVITY.EATING:
			_model.rotation.x += sin(_elapsed*9.0)*0.045

func _tick_activity(delta: float, swimming: bool) -> void:
	velocity.x = 0
	velocity.z = 0
	if not _map.navigation.ready_for_paths:
		return
	if _path_revision != _map.navigation.revision:
		_path.clear()
		_path_revision = _map.navigation.revision
		activity = ACTIVITY.SEEKING_GROUND if carrying_water else ACTIVITY.SEEKING_WATER
	if satiety <= 0.0 or activity in [ACTIVITY.MOVING_TO_FOOD,ACTIVITY.EATING]:
		_tick_hunger(delta,swimming)
		return
	_food_retry -= delta
	if satiety <= _species.feeding_threshold and _food_retry <= 0.0:
		_food_retry = 1.0
		var route: Dictionary = _map.navigation.route_to_feeder(global_position,_species)
		if not route.is_empty():
			_feeder = route.feeder
			_start_path(route.path,ACTIVITY.MOVING_TO_FOOD,ACTIVITY.HUNGRY)
			return
	if not _path.is_empty():
		_follow_path(delta,swimming)
		return
	_elapsed += delta
	match activity:
		ACTIVITY.SEEKING_WATER:
			_start_path(_map.navigation.route_to_water(global_position,_species.minimum_swim_depth),ACTIVITY.MOVING_TO_WATER,ACTIVITY.NO_WATER)
		ACTIVITY.SEEKING_GROUND:
			_start_path(_map.navigation.route_to_sowing_ground(global_position),ACTIVITY.MOVING_TO_GROUND,ACTIVITY.NO_GROUND)
		ACTIVITY.BATHING:
			_play_animation(&"Idle")
			if not swimming:
				activity = ACTIVITY.SEEKING_WATER
			elif _elapsed >= _species.bathing_seconds:
				carrying_water = true
				activity = ACTIVITY.SEEKING_GROUND
				_elapsed = 0
		ACTIVITY.SHAKING:
			if _elapsed >= _species.shaking_seconds:
				var planted: int = _map.vegetation_controller.seed_grass(global_position,_species.grass_per_cycle,_species.grass_radius)
				if planted > 0:
					carrying_water = false
				activity = ACTIVITY.RESTING
				_elapsed = 0
		ACTIVITY.RESTING, ACTIVITY.NO_WATER, ACTIVITY.NO_GROUND:
			_play_animation(&"Idle")
			if _elapsed >= _species.resting_seconds:
				activity = ACTIVITY.SEEKING_GROUND if carrying_water else ACTIVITY.SEEKING_WATER
				_elapsed = 0

func _start_path(path: PackedVector3Array, moving: ACTIVITY, failure: ACTIVITY) -> void:
	_path = path
	_path_index = 0
	_elapsed = 0
	_stuck = 0
	_last_position = global_position
	activity = moving if not path.is_empty() else failure

func _follow_path(delta: float, swimming: bool) -> void:
	var target := _path[_path_index]
	var difference := Vector2(target.x-global_position.x,target.z-global_position.z)
	if difference.length() < 0.14:
		_path_index += 1
		if _path_index >= _path.size():
			_path.clear()
			_elapsed = 0
			if activity == ACTIVITY.MOVING_TO_WATER:
				activity = ACTIVITY.BATHING
			elif activity == ACTIVITY.MOVING_TO_FOOD:
				activity = ACTIVITY.EATING
				if is_instance_valid(_feeder):
					var facing := _feeder.global_position-global_position
					_rest_rotation.y = atan2(facing.x,facing.z)
			else:
				activity = ACTIVITY.SHAKING
				$Splash.restart()
				$Splash.emitting = true
			_play_animation(&"Idle")
		return
	var speed := _species.swim_speed if swimming else _species.walk_speed
	var direction := difference.normalized()
	velocity.x = direction.x*speed
	velocity.z = direction.y*speed
	_rest_rotation.y = atan2(direction.x,direction.y)
	if not _play_animation(&"Walk"):
		_play_animation(&"Idle")
	_stuck += delta
	if _stuck > 1.5:
		if Vector2(global_position.x-_last_position.x,global_position.z-_last_position.z).length() < 0.12:
			_path.clear()
			activity = ACTIVITY.RESTING
			_elapsed = 0
		_last_position = global_position
		_stuck = 0

func begin_hold() -> void:
	_feeder = null
	_path.clear()
	_elapsed = 0
	activity = ACTIVITY.SEEKING_GROUND if carrying_water else ACTIVITY.SEEKING_WATER
	if _model != null:
		_model.rotation = _model_rotation
	super.begin_hold()

func _follow_ground() -> void:
	if _map != null and _map.water_controller.water_level-terrain_controller.surface_position(global_position).y >= _species.minimum_swim_depth:
		return
	super._follow_ground()

func activity_text() -> String:
	if _state == STATE.HELD:
		return "Being carried"
	if _map == null or not _map.navigation.ready_for_paths:
		return "Waiting for a clear route"
	return ["Looking for water","Walking to water","Bathing","Looking for soil","Walking to soil","Shaking and sowing grass","Resting","Hungry","Needs accessible water","Needs free dry soil","Walking to a feeder","Eating"][activity]

func _tick_hunger(delta: float, swimming: bool) -> void:
	if activity == ACTIVITY.MOVING_TO_FOOD and is_instance_valid(_feeder) and _feeder.can_feed(_species) and not _path.is_empty():
		_follow_path(delta,swimming)
		return
	_play_animation(&"Idle")
	_elapsed += delta
	if activity == ACTIVITY.EATING:
		if not is_instance_valid(_feeder) or not _feeder.can_feed(_species) or not _at_feeder():
			activity = ACTIVITY.HUNGRY
		elif _elapsed >= _species.feeding_seconds:
			if _feeder.eat(_species):
				restore_satiety(_species.satiety_per_meal)
				activity = ACTIVITY.RESTING
			else:
				activity = ACTIVITY.HUNGRY
			_elapsed = 0.0
		return
	activity = ACTIVITY.HUNGRY
	if _elapsed < 1.0:
		return
	_elapsed = 0.0
	_path.clear()
	var route: Dictionary = _map.navigation.route_to_feeder(global_position,_species)
	if not route.is_empty():
		_feeder = route.feeder
		_start_path(route.path,ACTIVITY.MOVING_TO_FOOD,ACTIVITY.HUNGRY)

func _at_feeder() -> bool:
	for point in _feeder.feeding_positions():
		if Vector2(point.x-global_position.x,point.z-global_position.z).length() < 0.7:
			return true
	return false
