class_name TuftlingController
extends CreatureActivityController

func work_cycle_seconds() -> float:
	return _species.shaking_seconds

func _next_work_activity() -> ACTIVITY:
	return ACTIVITY.SEEKING_GROUND if carrying_water else ACTIVITY.SEEKING_WATER

func _tick_work_activity(delta: float) -> bool:
	if activity in [ACTIVITY.BATHING,ACTIVITY.SWIMMING]:
		if not _swimming:
			interrupt_activity()
			return true
		_bath_elapsed += delta*work_efficiency()
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
	_elapsed += delta*work_efficiency()
	_play_animation(&"Work")
	if _elapsed >= _species.shaking_seconds:
		var planted: int = _map.vegetation_controller.seed_grass(global_position,_species.grass_per_cycle,_species.grass_radius)
		if planted > 0:
			SoundEffects.play_at(&"grass_work",global_position,self)
			carrying_water = false
			_work_cycles += 1
			_map.science.observe(species_id,&"create_grass",global_position)
		_map.navigation.release_place(self)
		activity = ACTIVITY.RESTING
		_elapsed = 0.0
	return true

func _select_work() -> void:
	match activity:
		ACTIVITY.SEEKING_WATER:
			_start_path(_map.navigation.route_to_water(global_position,_species.minimum_swim_depth,self),ACTIVITY.MOVING_TO_WATER,ACTIVITY.NO_WATER)
		ACTIVITY.SEEKING_GROUND:
			_start_path(_map.navigation.route_to_sowing_ground(global_position,self),ACTIVITY.MOVING_TO_GROUND,ACTIVITY.NO_GROUND)
		ACTIVITY.RESTING,ACTIVITY.NO_WATER,ACTIVITY.NO_GROUND:
			_play_animation(movement_animation() if _swimming else &"Idle")
			if _elapsed >= _species.resting_seconds:
				activity = _next_work_activity()
				_elapsed = 0.0

func _complete_work_path() -> void:
	if activity == ACTIVITY.MOVING_TO_WATER:
		activity = ACTIVITY.BATHING
		_bath_elapsed = 0.0
	elif activity == ACTIVITY.SWIMMING:
		activity = ACTIVITY.BATHING
	else:
		super._complete_work_path()
		return
	_play_animation(&"water/Swim" if _swimming else &"Idle")

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
