class_name TuftlingController
extends CreatureActivityController

var _leisure: TuftlingLeisure
var _shaking_effect := false

@onready var _shake_audio: AudioStreamPlayer3D = $ShakeAudio
@onready var _shake_droplets: CPUParticles3D = $Splash

func _process(delta: float) -> void:
	if _leisure != null and _leisure.is_sleeping():
		_voice_wait += delta
	super._process(delta)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_sync_shaking_effect()
	if _leisure != null:
		_leisure.refresh_sleep_effect()

func _exit_tree() -> void:
	if _leisure != null:
		_leisure.cancel()

func _settle_rest() -> void:
	super._settle_rest()
	if activity == ACTIVITY.LEISURE:
		_leisure_controller().begin()

func _tick_rest(delta: float) -> void:
	if not _on_dry_ground():
		_reset_work_state()
		activity = ACTIVITY.SEEKING_REST
		_elapsed = 0.75
		return
	_leisure_elapsed += delta
	if _leisure_elapsed >= _leisure_duration:
		_finish_break()
		return
	_leisure_controller().tick(delta)

func _finish_break() -> void:
	_reset_work_state()
	super._finish_break()

func _reset_work_state() -> void:
	_stop_shaking_effect()
	if _leisure != null:
		_leisure.cancel()

func _apply_avoidance(delta: float) -> void:
	if _leisure != null and _leisure.holds_position():
		if _navigation != null and _navigation.ready_for_paths:
			_navigation.steer(self,Vector2.ZERO,delta)
		velocity.x = 0.0
		velocity.z = 0.0
		return
	super._apply_avoidance(delta)

func _rest_presentation() -> Dictionary:
	if activity == ACTIVITY.LEISURE and _leisure != null and _leisure.action != TuftlingLeisure.ACTION.NONE:
		return _leisure.presentation()
	return super._rest_presentation()

func capture_leisure_state(actors: Array[Creature] = []) -> Dictionary:
	return _leisure.capture_state(actors) if _leisure != null and activity == ACTIVITY.LEISURE else {}

func restore_leisure_state(state: Dictionary) -> void:
	_leisure_controller().restore_state(state)

func restore_leisure_partner(state: Dictionary, actors: Array[Creature]) -> void:
	_leisure_controller().restore_partner(state,actors)

func is_playing_with(other: Creature) -> bool:
	return _leisure != null and _leisure.is_playing_with(other)

func _leisure_controller() -> TuftlingLeisure:
	if _leisure == null:
		_leisure = TuftlingLeisure.new(self)
	return _leisure

func work_cycle_seconds() -> float:
	return _species.shaking_seconds

func _next_work_activity() -> ACTIVITY:
	return ACTIVITY.SEEKING_GROUND if carrying_water else ACTIVITY.SEEKING_WATER

func _tick_work_activity(delta: float) -> bool:
	if activity in [ACTIVITY.BATHING,ACTIVITY.SWIMMING]:
		if not _swimming:
			interrupt_activity()
			return true
		_bath_elapsed += delta
		if _bath_elapsed >= _species.bathing_seconds:
			_map.navigation.release_place(self)
			_path.clear()
			carrying_water = true
			activity = ACTIVITY.SEEKING_GROUND
			_elapsed = 0.0
			return true
		if activity == ACTIVITY.BATHING and _path.is_empty():
			_elapsed += delta
			_play_animation(&"water/Swim")
			if _elapsed >= 0.3:
				_start_path(_map.navigation.bathing_route(self),ACTIVITY.SWIMMING,ACTIVITY.BATHING)
		return true
	if activity != ACTIVITY.SHAKING:
		return false
	_elapsed += delta
	_play_animation(&"Work")
	if _elapsed >= _species.shaking_seconds:
		var painted: float = _map.landscape.apply_terrain(self,global_position,TerrainController.GROUND_TYPE.GRASS,_species.grass_radius)
		var planted := 0
		if terrain_controller.ground_weight(global_position,TerrainController.GROUND_TYPE.GRASS) >= 0.55:
			planted = _map.vegetation_controller.seed_grass(global_position,_species.grass_per_cycle,_species.grass_radius,_map.landscape.region_filter(self),false)
		if painted > 0.0 or planted > 0:
			carrying_water = false
			_work_cycles += 1
			_map.science.observe(species_id,&"create_grass",global_position)
			_continue_work()
		else:
			_map.navigation.release_place(self)
			activity = ACTIVITY.NO_GROUND
			_elapsed = 0.0
	return true

func _select_work() -> void:
	match activity:
		ACTIVITY.SEEKING_WATER:
			_start_path(_map.navigation.route_to_water(global_position,_species.minimum_swim_depth,self),ACTIVITY.MOVING_TO_WATER,ACTIVITY.NO_WATER)
		ACTIVITY.SEEKING_GROUND:
			_start_path(_ground_route(),ACTIVITY.MOVING_TO_GROUND,ACTIVITY.NO_GROUND)
		ACTIVITY.RESTING,ACTIVITY.NO_WATER,ACTIVITY.NO_GROUND:
			_play_animation(movement_animation() if _swimming else &"Idle")
			if _elapsed >= _species.resting_seconds:
				if activity in [ACTIVITY.NO_WATER,ACTIVITY.NO_GROUND]:
					_begin_break()
				else:
					activity = _next_work_activity()
					_elapsed = 0.0

func _ground_route() -> PackedVector3Array:
	var kind := TerrainController.GROUND_TYPE.GRASS
	var transforming: bool = _map.landscape.needs_terrain(self,kind)
	for point: Vector3 in _map.landscape.terrain_sites(self,kind,transforming):
		if not transforming and not _map.vegetation_controller.can_seed_grass(point):
			continue
		var path: PackedVector3Array = _map.navigation.path_to(global_position,point)
		if path.is_empty() or not _map.navigation.space_available(path[-1],self):
			continue
		var target := path[-1]
		if transforming:
			if not _map.landscape.can_transform(self,target,kind):
				continue
		elif terrain_controller.ground_weight(target,kind) < 0.55 or not _map.vegetation_controller.can_seed_grass(target):
			continue
		return path
	return PackedVector3Array()

func _complete_work_path() -> void:
	if activity == ACTIVITY.MOVING_TO_WATER:
		activity = ACTIVITY.BATHING
		_bath_elapsed = 0.0
	elif activity == ACTIVITY.SWIMMING:
		activity = ACTIVITY.BATHING
	else:
		activity = ACTIVITY.SHAKING
		_elapsed = 0.0
		_play_animation(&"Work")
		_sync_shaking_effect()
		return
	_play_animation(&"water/Swim" if _swimming else &"Idle")

func _sync_shaking_effect() -> void:
	var active: bool = activity == ACTIVITY.SHAKING and is_grounded() and not _swimming and _map != null and not _map.breeding.is_breeding(self)
	if not active:
		_stop_shaking_effect()
		return
	if _shaking_effect:
		return
	_shaking_effect = true
	_shake_droplets.restart()
	_shake_droplets.emitting = true
	_shake_audio.pitch_scale = _shake_audio.stream.get_length()/maxf(work_cycle_seconds(),0.01)
	var offset := _elapsed*_shake_audio.pitch_scale
	if animation_player != null and animation_player.current_animation == &"Work":
		animation_player.seek(_elapsed*animation_player.get_animation(&"Work").length/maxf(work_cycle_seconds(),0.01),true)
	if offset < _shake_audio.stream.get_length():
		_shake_audio.play(offset)

func _stop_shaking_effect() -> void:
	if not _shaking_effect:
		return
	_shaking_effect = false
	_shake_droplets.emitting = false
	_shake_audio.stop()

func _work_presentation() -> Dictionary:
	match activity:
		ACTIVITY.SEEKING_WATER,ACTIVITY.MOVING_TO_WATER:
			return _present_activity("Seeking water","water","Walking to water" if activity == ACTIVITY.MOVING_TO_WATER else "Looking for water")
		ACTIVITY.BATHING,ACTIVITY.SWIMMING:
			return _present_activity("Swimming","water","Swimming and bathing")
		ACTIVITY.SEEKING_GROUND,ACTIVITY.MOVING_TO_GROUND:
			return _present_activity("On the move","status_walk","Walking to soil" if activity == ACTIVITY.MOVING_TO_GROUND else "Looking for soil")
		ACTIVITY.SHAKING:
			return _present_activity("Working","status_work","Shaking and sowing grass")
		ACTIVITY.NO_WATER:
			return _present_activity("Needs water","water","Needs accessible water or a free bathing spot")
		ACTIVITY.NO_GROUND:
			return _present_activity("Needs space","status_space","Needs free dry soil")
	return super._work_presentation()
