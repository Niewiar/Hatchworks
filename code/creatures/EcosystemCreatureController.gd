class_name EcosystemCreatureController
extends CreatureActivityController

var _job: Dictionary = {}
var _effect_done := false
var _job_message := "Looking for a place to work"
var _aggression_wait := 0.0

func _advance_activity_timers(delta: float) -> void:
	_aggression_wait = maxf(0.0,_aggression_wait-delta)

func _tick_work_activity(delta: float) -> bool:
	if activity != ACTIVITY.SHAKING or _job.is_empty():
		return false
	_tick_work(delta)
	return true

func _select_work() -> void:
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

func _ai_state() -> String:
	return "attack" if _job.get("kind","") == "damage" else super._ai_state()

func _begin_break() -> void:
	_job.clear()
	super._begin_break()

func _choose_job() -> Dictionary:
	if _uses_mineral_ground():
		return _choose_mineral_job()
	var region_id: int = _map.regions_controller.region_id_at(global_position)
	var ids: Array[StringName] = [&"fern"]
	if _production() == CreatureSpecies.PRODUCTION.GARDENER:
		ids.assign([&"oak",&"shrub"])
	if _map.vegetation_controller.count_near(global_position,_species.production_radius,ids) >= _species.production_limit:
		_job_message = "Nearby plants are full; harvest them to make room"
		return {}
	for attempt in 40:
		var distance := randf_range(1.3,_species.production_radius)
		var offset := Vector2.from_angle(randf()*TAU)*distance
		var point: Vector3 = _map.terrain_controller.surface_position(global_position+Vector3(offset.x,0,offset.y))
		if not _free_site(point,region_id) or _map.terrain_controller.ground_weight(point,TerrainController.GROUND_TYPE.GRASS) < 0.55:
			continue
		var id: StringName = ids[0] if ids.size() == 1 or randf() < 0.65 else ids[1]
		var data: FloraSpecies = _map.database.plant(id)
		if not _map.vegetation_controller.can_plant(data,point):
			continue
		var appearance := _model as CreatureCelAppearance
		var precise := appearance != null and appearance.work_contact_offset.length_squared() > 0.0
		var reach := appearance.work_contact_offset.length() * absf(appearance.scale.x) if precise else body_radius() + 0.95
		var path := _approach(point,reach,0.0 if precise else body_radius()+0.75,precise)
		if not path.is_empty():
			return {"kind":"plant","point":point,"plant":data,"path":path}
	_job_message = "Needs free grassy ground"
	return {}

func _choose_mineral_job() -> Dictionary:
	var kind := _mineral_ground()
	var transforming: bool = _map.landscape.needs_terrain(self,kind)
	if not transforming and _mineral_resources_full(global_position):
		_job_message = "Nearby stone deposits are full; mine them to make room" if _production() == CreatureSpecies.PRODUCTION.QUARRY else "Nearby pebbles are full; collect them to make room"
		return {}
	var region: int = _map.regions_controller.region_id_at(global_position)
	for point: Vector3 in _map.landscape.terrain_sites(self,kind,transforming):
		if not transforming and global_position.distance_to(point) > _species.production_radius:
			continue
		if not _free_site(point,region):
			continue
		var path: PackedVector3Array = _map.navigation.path_to(global_position,point)
		if path.is_empty() or not _map.navigation.space_available(path[-1],self):
			continue
		var target := path[-1]
		if not _free_site(target,region):
			continue
		if transforming:
			if not _map.landscape.can_transform(self,target,kind):
				continue
		elif _map.terrain_controller.ground_weight(target,kind) < 0.55 or _mineral_resources_full(target):
			continue
		if not transforming and _production() == CreatureSpecies.PRODUCTION.SAND_MAKER and _map.rock_controller.count_pebbles_near(target,0.22) > 0:
			continue
		return {"kind":"quarry" if _production() == CreatureSpecies.PRODUCTION.QUARRY else ("sand" if transforming else "pebble"),"point":target,"path":path}
	_job_message = "Needs free dry soil or rocky ground"
	return {}

func _mineral_ground() -> int:
	return TerrainController.GROUND_TYPE.SAND if _production() == CreatureSpecies.PRODUCTION.SAND_MAKER else TerrainController.GROUND_TYPE.ROCK

func _mineral_resources_full(point: Vector3) -> bool:
	var count: int = _map.rock_controller.count_pebbles_near(point,_species.production_radius) if _production() == CreatureSpecies.PRODUCTION.SAND_MAKER else _map.rock_controller.count_near(point,_species.production_radius)
	return count >= _species.production_limit

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
	if _model is CreatureCelAppearance:
		query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _approach(point: Vector3, radius: float, minimum_distance: float = 0.0, exact_endpoint: bool = false) -> PackedVector3Array:
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
		if exact_endpoint:
			var shape := SphereShape3D.new()
			shape.radius = body_radius()
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform.origin = path[-1] + Vector3.UP * (body_radius() + 0.02)
			query.motion = stand - path[-1]
			query.collision_mask = 6
			if get_world_3d().direct_space_state.cast_motion(query)[0] < 0.99:
				continue
			path.append(stand)
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
		if _map.building_controller.building_definition(target) != null and _map.building_controller.condition(target) <= 0.0:
			continue
		if global_position.distance_to(target.global_position) > _species.production_radius+2.0:
			continue
		var data: BuildingDefinition = _map.building_controller.building_definition(target)
		var reach := data.footprint_radius+body_radius()+0.25 if data != null else body_radius()+0.45
		var path := _approach(target.global_position,reach)
		if not path.is_empty() and _can_hit_from(path[-1]+Vector3.UP*body_radius(),target):
			return {"kind":"damage","target":target,"point":target.global_position,"path":path}
	return {}

func _on_path_started(moving: ACTIVITY) -> void:
	if moving == ACTIVITY.MOVING_TO_FOOD:
		_job.clear()

func _tick_work(delta: float) -> void:
	if not _on_dry_ground():
		_job.clear()
		_begin_break()
		return
	if _job.kind == "plant":
		var appearance := _model as CreatureCelAppearance
		if appearance != null and appearance.work_contact_offset.length_squared() > 0.0:
			var direction: Vector3 = _job.point - global_position
			var contact := appearance.work_contact_offset
			_rest_rotation.y = atan2(direction.x, direction.z) - atan2(contact.x, contact.z)
			if absf(angle_difference(rotation.y, _rest_rotation.y)) > 0.05:
				_play_animation(&"Idle")
				return
			_play_animation(&"Work")
		else:
			face_point(_job.point,&"Work")
	else:
		_play_animation(work_animation())
	_elapsed += delta
	if not _effect_done and _elapsed >= _species.impact_time:
		_effect_done = true
		if _apply_effect():
			_work_cycles += 1
	if _elapsed >= _species.production_seconds:
		_finish_work()

func _finish_work() -> void:
	var attacked: bool = _job.get("kind","") == "damage"
	_job.clear()
	if attacked:
		_map.navigation.release_place(self)
		activity = ACTIVITY.RESTING
		_elapsed = 0.0
	else:
		_continue_work()
	_play_animation(&"Idle")

func _production() -> CreatureSpecies.PRODUCTION:
	return _species.production_for(sex == SEX.FEMALE) if _species != null else CreatureSpecies.PRODUCTION.NONE

func _uses_mineral_ground() -> bool:
	return _production() in [CreatureSpecies.PRODUCTION.QUARRY,CreatureSpecies.PRODUCTION.SAND_MAKER]

func work_animation() -> StringName:
	if _job.get("kind","") in ["sand","pebble"]:
		return &"ShakeSand"
	return &"Work"

func _apply_effect() -> bool:
	if _job.kind == "damage":
		var target := _job.get("target") as Node3D
		if not is_instance_valid(target) or target.is_queued_for_deletion() or not _can_hit(target):
			return false
		_map.noise.pulse(global_position,1.0,8.0,6.0,self)
		SoundEffects.play_at(&"stone_impact",global_position,self)
		return target.damage_structure(_species.impact_damage) if target.has_method("damage_structure") else _map.building_controller.damage_building(target,_species.impact_damage,self)
	var region_filter: Callable = _map.landscape.region_filter(self)
	if _job.kind == "plant":
		var point: Vector3 = _map.terrain_controller.surface_position(_job.point)
		if not _free_site(point,_map.regions_controller.region_id_at(global_position)) or _map.terrain_controller.ground_weight(point,TerrainController.GROUND_TYPE.GRASS) < 0.55:
			return false
		var planted: bool = _map.vegetation_controller.plant_specimen(_job.plant,point,region_filter)
		if planted:
			SoundEffects.play_at(&"plant_work" if _production() == CreatureSpecies.PRODUCTION.GARDENER else &"herb_work",point,self)
			_map.science.observe(species_id,&"plant_tree" if _production() == CreatureSpecies.PRODUCTION.GARDENER else &"grow_herbs",point)
		return planted
	var point := global_position
	if not region_filter.call(point):
		return false
	if _job.kind == "pebble":
		if _map.terrain_controller.ground_weight(point,TerrainController.GROUND_TYPE.SAND) < 0.55:
			return false
		var capacity: int = _species.production_limit-_map.rock_controller.count_pebbles_near(point,_species.production_radius)
		if capacity <= 0 or _map.rock_controller.scatter_pebbles(point,capacity,region_filter) == 0:
			return false
		_mineral_effect(point,0.55,1.3)
		_map.science.observe(species_id,&"create_stone",point)
		return true
	var kind := _mineral_ground()
	var changed: float = _map.landscape.apply_terrain(self,point,kind,_species.impact_radius)
	if _job.kind == "sand":
		if changed <= 0.0:
			return false
		_map.vegetation_controller.flatten_ground_plants(point,_species.impact_radius,region_filter)
		_mineral_effect(point,0.55,1.3)
		_map.discoveries.discover(&"sand")
		_map.science.observe(species_id,&"create_sand",point)
		return true
	if changed > 0.0:
		_map.vegetation_controller.flatten_ground_plants(point,_species.impact_radius,region_filter)
	var created := false
	if _map.terrain_controller.ground_weight(point,TerrainController.GROUND_TYPE.ROCK) >= 0.55 and not _mineral_resources_full(point):
		for attempt in 12:
			var angle := randf()*TAU
			var deposit: Vector3 = _map.terrain_controller.surface_position(point+Vector3(cos(angle),0,sin(angle))*(_species.impact_radius*0.85+body_radius()*0.5))
			if not region_filter.call(deposit) or _map.terrain_controller.ground_weight(deposit,TerrainController.GROUND_TYPE.ROCK) < 0.55 or not _free_site(deposit,_map.regions_controller.region_id_at(global_position)) or not _map.navigation.space_available(deposit,self,0.6):
				continue
			if _map.rock_controller.create_deposit(deposit):
				created = true
				_map.discoveries.discover(&"rock")
				_map.science.observe(species_id,&"create_stone",deposit)
				break
	if changed > 0.0 or created:
		_mineral_effect(point,1.0,1.0)
	return changed > 0.0 or created

func _mineral_effect(point: Vector3, loudness: float, pitch: float) -> void:
	_map.noise.pulse(point,loudness,8.0,6.0,self)
	SoundEffects.play_at(&"stone_impact",point,self,pitch)
	$Splash.restart()
	$Splash.emitting = true

func _can_hit(target: Node3D) -> bool:
	return _can_hit_from(global_position,target)

func _can_hit_from(origin: Vector3, target: Node3D) -> bool:
	var data: BuildingDefinition = _map.building_controller.building_definition(target)
	if data != null and _map.building_controller.condition(target) <= 0.0:
		return false
	var reach := data.footprint_radius+body_radius()+0.65 if data != null else body_radius()+1.0
	if Vector2(target.global_position.x-origin.x,target.global_position.z-origin.z).length() > reach:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin,target.global_position+Vector3.UP*0.5,7)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target or target.is_ancestor_of(hit.collider)

func _update_visual_activity() -> void:
	if _model != null:
		_model.rotation = _model_rotation
	_update_skeletal_animation_speed()

func movement_animation() -> StringName:
	if _swimming:
		return &"water/Swim"
	return &"Walk"

func _work_presentation() -> Dictionary:
	var kind: String = _job.get("kind","")
	if kind == "damage":
		return _present_activity("Attacking","happiness_unhappy","Upset: striking a nearby structure" if activity == ACTIVITY.SHAKING else "Charging at a structure")
	if activity == ACTIVITY.SHAKING:
		var description := "Shaking off pebbles" if kind == "pebble" else ("Shaking off sand" if kind == "sand" else ("Planting a sapling" if _production() == CreatureSpecies.PRODUCTION.GARDENER else ("Stomping rocky ground" if _production() == CreatureSpecies.PRODUCTION.QUARRY else "Sowing herbs")))
		return _present_activity("Working","status_work",description)
	if activity == ACTIVITY.MOVING_TO_GROUND:
		return _present_activity("On the move","status_walk","Walking to a work site" if _uses_mineral_ground() else "Moving to a planting site")
	if activity == ACTIVITY.NO_GROUND:
		return _present_activity("Needs space","status_space",_job_message)
	return super._work_presentation()

func _reset_work_state() -> void:
	_job.clear()

func _preserve_work_on_navigation_changed() -> bool:
	return activity == ACTIVITY.SHAKING and not _job.is_empty()
