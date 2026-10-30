class_name EcosystemCreatureController
extends TuftlingController

var _job: Dictionary = {}
var _effect_done := false
var _job_message := "Looking for a place to work"
var _aggression_wait := 0.0
var _curl_remaining := 0.0
var _uncurl_remaining := 0.0

func _ready() -> void:
	if animation_player == null:
		animation_player = find_child("AnimationPlayer",true,false) as AnimationPlayer
	if animation_player != null and animation_player.has_animation(&"Swim"):
		swimming_library = AnimationLibrary.new()
		swimming_library.add_animation(&"Swim",animation_player.get_animation(&"Swim"))
	super._ready()
	activity = ACTIVITY.SEEKING_GROUND

func _tick_activity(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_aggression_wait = maxf(0.0,_aggression_wait-delta)
	if _map.breeding.is_breeding(self):
		_map.breeding.move_creature(self,delta)
		return
	if satiety <= 0.0 or activity in [ACTIVITY.MOVING_TO_FOOD,ACTIVITY.EATING]:
		_tick_hunger(delta)
		return
	_food_retry -= delta
	if satiety <= _species.feeding_threshold and _food_retry <= 0.0 and _map.navigation.ready_for_paths:
		_food_retry = 1.0
		var meal: Dictionary = _map.navigation.route_to_feeder(global_position,_species,self)
		if not meal.is_empty():
			_feeder = meal.feeder
			_start_path(meal.path,ACTIVITY.MOVING_TO_FOOD,ACTIVITY.HUNGRY)
			return
	if activity == ACTIVITY.LEISURE:
		_tick_rest(delta)
		return
	if activity == ACTIVITY.SHAKING and not _job.is_empty():
		_tick_work(delta)
		return
	if not _map.navigation.ready_for_paths:
		return
	if _path_revision != _map.navigation.revision:
		_on_navigation_changed()
	if activity not in [ACTIVITY.SEEKING_REST,ACTIVITY.MOVING_TO_REST] and _work_cycles >= _cycles_until_leisure:
		_job.clear()
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
	if not _path.is_empty():
		if _curl_remaining > 0.0:
			_curl_remaining -= delta
			_play_animation(&"Curl")
			return
		_follow_path(delta)
		return
	_elapsed += delta
	if activity == ACTIVITY.RESTING and _elapsed < _species.resting_seconds:
		_play_animation(&"Idle")
		return
	if _elapsed < 0.8:
		return
	_elapsed = 0.0
	if _swimming or not _on_dry_ground():
		_job.clear()
		_begin_break()
		return
	var chosen := _choose_job()
	if chosen.is_empty():
		activity = ACTIVITY.NO_GROUND
		_play_animation(&"Idle")
		return
	_job = chosen
	_effect_done = false
	_start_path(chosen.path,ACTIVITY.MOVING_TO_GROUND,ACTIVITY.NO_GROUND)

func _choose_job() -> Dictionary:
	if _species.production == CreatureSpecies.PRODUCTION.QUARRY and _aggression_wait <= 0.0 and (happiness <= _species.aggression_threshold or (space_per_creature > 0.0 and space_per_creature < _species.preferred_area*0.5)):
		var attack := _damage_job()
		if not attack.is_empty():
			return attack
	var region_id: int = _map.regions_controller.region_id_at(global_position)
	var ids: Array[StringName] = [&"fern"]
	if _species.production == CreatureSpecies.PRODUCTION.GARDENER:
		ids.assign([&"oak",&"shrub"])
	if _species.production == CreatureSpecies.PRODUCTION.QUARRY:
		if _map.rock_controller.count_near(global_position,_species.production_radius) >= _species.production_limit:
			_job_message = "Nearby stone deposits are full; mine them to make room"
			return {}
	elif _map.vegetation_controller.count_near(global_position,_species.production_radius,ids) >= _species.production_limit:
		_job_message = "Nearby plants are full; harvest them to make room"
		return {}
	for attempt in 40:
		var distance := randf_range(1.3,_species.production_radius)
		var offset := Vector2.from_angle(randf()*TAU)*distance
		var point: Vector3 = _map.terrain_controller.surface_position(global_position+Vector3(offset.x,0,offset.y))
		if not _free_site(point,region_id):
			continue
		if _species.production == CreatureSpecies.PRODUCTION.QUARRY:
			var ground: float = _map.terrain_controller.ground_weight(point,TerrainController.GROUND_TYPE.SOIL)+_map.terrain_controller.ground_weight(point,TerrainController.GROUND_TYPE.ROCK)+_map.terrain_controller.ground_weight(point,TerrainController.GROUND_TYPE.GRASS)
			if ground < 0.55:
				continue
			var path: PackedVector3Array = _map.navigation.path_to(global_position,point)
			if not path.is_empty() and _map.navigation.space_available(path[-1],self):
				return {"kind":"quarry","point":point,"path":path}
		else:
			if _map.terrain_controller.ground_weight(point,TerrainController.GROUND_TYPE.GRASS) < 0.55:
				continue
			var id: StringName = ids[0] if ids.size() == 1 or randf() < 0.65 else ids[1]
			var data: FloraSpecies = _map.database.plant(id)
			if not _map.vegetation_controller.can_plant(data,point):
				continue
			var path := _approach(point,body_radius()+0.95,body_radius()+0.75)
			if not path.is_empty():
				return {"kind":"plant","point":point,"plant":data,"path":path}
	_job_message = "Needs free dry soil or rocky ground" if _species.production == CreatureSpecies.PRODUCTION.QUARRY else "Needs free grassy ground"
	return {}

func _free_site(point: Vector3, region_id: int) -> bool:
	var terrain: TerrainController = _map.terrain_controller
	if not terrain.contains_world_point(point) or _map.regions_controller.region_id_at(point) != region_id:
		return false
	if point.y <= _map.water_controller.global_position.y+0.08 or terrain.slope_at(point) > 0.5:
		return false
	var local := terrain.to_local(point)
	if _map.building_controller.occupied(point,_species.impact_radius+0.25) or _map.rock_controller.occupied(point,0.6):
		return false
	if _map.vegetation_controller.occupied(Vector2(local.x,local.z),0.55):
		return false
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = point+Vector3.UP*0.6
	query.collision_mask = 14
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _approach(point: Vector3, radius: float, minimum_distance: float = 0.0) -> PackedVector3Array:
	var best := PackedVector3Array()
	var best_length := INF
	for index in 12:
		var angle := index*TAU/12.0
		var stand: Vector3 = _map.terrain_controller.surface_position(point+Vector3(cos(angle),0,sin(angle))*radius)
		if stand.y <= _map.water_controller.global_position.y+0.05 or not _map.navigation.space_available(stand,self):
			continue
		if _map.regions_controller.region_id_at(stand) != _map.regions_controller.region_id_at(global_position):
			continue
		var path: PackedVector3Array = _map.navigation.path_to(global_position,stand)
		if path.is_empty() or Vector2(path[-1].x-point.x,path[-1].z-point.z).length() < minimum_distance:
			continue
		var length := 0.0
		for step in range(1,path.size()):
			length += path[step-1].distance_to(path[step])
		if length < best_length:
			best_length = length
			best = path
	return best

func _damage_job() -> Dictionary:
	var targets: Array = _map.building_controller.get_buildings()
	targets.append_array(_map.fances_controller.get_damageable_views())
	targets.sort_custom(func(first,second): return global_position.distance_squared_to(first.global_position) < global_position.distance_squared_to(second.global_position))
	for target: Node3D in targets:
		if global_position.distance_to(target.global_position) > _species.production_radius+2.0:
			continue
		var data: BuildingDefinition = _map.building_controller.building_definition(target)
		var reach := data.footprint_radius+body_radius()+0.25 if data != null else body_radius()+0.45
		var path := _approach(target.global_position,reach)
		if not path.is_empty() and _can_hit_from(path[-1]+Vector3.UP*body_radius(),target):
			return {"kind":"damage","target":target,"point":target.global_position,"path":path}
	return {}

func _start_path(path: PackedVector3Array, moving: ACTIVITY, failure: ACTIVITY) -> void:
	if moving == ACTIVITY.MOVING_TO_FOOD:
		_job.clear()
	super._start_path(path,moving,failure)
	_curl_remaining = 0.667 if not _path.is_empty() and moving == ACTIVITY.MOVING_TO_GROUND and _species.production == CreatureSpecies.PRODUCTION.QUARRY else 0.0
	_uncurl_remaining = 0.0

func _follow_path(delta: float) -> void:
	var previous := activity
	super._follow_path(delta)
	if previous == ACTIVITY.MOVING_TO_GROUND and activity == ACTIVITY.SHAKING:
		_uncurl_remaining = 0.75 if _species.production == CreatureSpecies.PRODUCTION.QUARRY else 0.0
		if _uncurl_remaining > 0.0:
			_play_animation(&"Uncurl")

func _tick_work(delta: float) -> void:
	if _uncurl_remaining > 0.0:
		_uncurl_remaining -= delta
		_play_animation(&"Uncurl")
		return
	if not _on_dry_ground():
		_job.clear()
		_begin_break()
		return
	if _job.kind == "plant":
		face_point(_job.point,&"Work")
	else:
		_play_animation(&"Work")
	_elapsed += delta*work_efficiency()
	if not _effect_done and _elapsed >= _species.impact_time:
		_effect_done = true
		if _apply_effect():
			_work_cycles += 1
	if _elapsed >= _species.production_seconds:
		_map.navigation.release_place(self)
		_job.clear()
		activity = ACTIVITY.RESTING
		_elapsed = 0.0
		_play_animation(&"Idle")

func _apply_effect() -> bool:
	if _job.kind == "damage":
		var target := _job.get("target") as Node3D
		_aggression_wait = _species.aggression_cooldown
		if not is_instance_valid(target) or target.is_queued_for_deletion() or not _can_hit(target):
			return false
		_map.noise.pulse(global_position,1.0,8.0,6.0,self)
		SoundEffects.play_at(&"stone_impact",global_position,self)
		return target.damage_structure(_species.impact_damage) if target.has_method("damage_structure") else _map.building_controller.damage_building(target,_species.impact_damage)
	if _job.kind == "plant":
		var point: Vector3 = _map.terrain_controller.surface_position(_job.point)
		if not _free_site(point,_map.regions_controller.region_id_at(global_position)):
			return false
		if _map.terrain_controller.ground_weight(point,TerrainController.GROUND_TYPE.GRASS) < 0.55:
			return false
		var planted: bool = _map.vegetation_controller.plant_specimen(_job.plant,point)
		if planted:
			SoundEffects.play_at(&"plant_work" if _species.production == CreatureSpecies.PRODUCTION.GARDENER else &"herb_work",point,self)
			_map.science.observe(species_id,&"plant_tree" if _species.production == CreatureSpecies.PRODUCTION.GARDENER else &"grow_herbs",point)
		return planted
	var point := global_position
	_map.noise.pulse(point,1.0,8.0,6.0,self)
	SoundEffects.play_at(&"stone_impact",point,self)
	_map.vegetation_controller.flatten_ground_plants(point,_species.impact_radius)
	_map.terrain_controller.rocky_impact(point,_species.impact_radius,_species.impact_strength)
	for attempt in 12:
		var angle := randf()*TAU
		var deposit: Vector3 = _map.terrain_controller.surface_position(point+Vector3(cos(angle),0,sin(angle))*(_species.impact_radius*0.85+body_radius()*0.5))
		if not _free_site(deposit,_map.regions_controller.region_id_at(point)) or not _map.navigation.space_available(deposit,self,0.6):
			continue
		if _map.rock_controller.create_deposit(deposit):
			_map.discoveries.discover(&"rock")
			_map.science.observe(species_id,&"create_stone",deposit)
			return true
	return true

func _can_hit(target: Node3D) -> bool:
	return _can_hit_from(global_position,target)

func _can_hit_from(origin: Vector3, target: Node3D) -> bool:
	var data: BuildingDefinition = _map.building_controller.building_definition(target)
	var reach := data.footprint_radius+body_radius()+0.65 if data != null else body_radius()+1.0
	if Vector2(target.global_position.x-origin.x,target.global_position.z-origin.z).length() > reach:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin,target.global_position+Vector3.UP*0.5,7)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target or target.is_ancestor_of(hit.collider)

func _update_visual_activity() -> void:
	if _model != null:
		_model.rotation = _model_rotation

func _play_animation(name: StringName, blend: float = 0.12) -> bool:
	if animation_player != null:
		animation_player.speed_scale = work_efficiency() if name == &"Work" else 1.0
	return super._play_animation(name,blend)

func movement_animation() -> StringName:
	if _swimming:
		return &"water/Swim"
	return &"Roll" if _species != null and _species.production == CreatureSpecies.PRODUCTION.QUARRY and activity == ACTIVITY.MOVING_TO_GROUND else &"Walk"

func activity_text() -> String:
	if _state == STATE.HELD or (_map != null and _map.breeding.is_breeding(self)) or activity in [ACTIVITY.LEISURE,ACTIVITY.MOVING_TO_FOOD,ACTIVITY.EATING,ACTIVITY.HUNGRY,ACTIVITY.SEEKING_REST,ACTIVITY.MOVING_TO_REST]:
		return super.activity_text()
	if activity == ACTIVITY.SHAKING:
		if _job.get("kind","") == "damage":
			return tr("Upset: striking a nearby structure")
		return tr("Planting a sapling") if _species.production == CreatureSpecies.PRODUCTION.GARDENER else (tr("Stomping rocky ground") if _species.production == CreatureSpecies.PRODUCTION.QUARRY else tr("Sowing herbs"))
	if activity == ACTIVITY.MOVING_TO_GROUND:
		return tr("Rolling to a work site") if _species.production == CreatureSpecies.PRODUCTION.QUARRY else tr("Moving to a planting site")
	if activity == ACTIVITY.NO_GROUND:
		return tr(_job_message)
	return tr("Taking a short break") if activity == ACTIVITY.RESTING else tr("Looking for a place to work")

func interrupt_activity() -> void:
	_job.clear()
	_curl_remaining = 0.0
	_uncurl_remaining = 0.0
	super.interrupt_activity()
	activity = ACTIVITY.SEEKING_GROUND

func _on_navigation_changed() -> void:
	if _map == null or not _map.navigation.ready_for_paths or _state == STATE.HELD or _map.breeding.is_breeding(self):
		return
	if activity == ACTIVITY.SHAKING and not _job.is_empty():
		_path_revision = _map.navigation.revision
		return
	_job.clear()
	_curl_remaining = 0.0
	_uncurl_remaining = 0.0
	super._on_navigation_changed()
	if activity == ACTIVITY.SEEKING_WATER:
		activity = ACTIVITY.SEEKING_GROUND
