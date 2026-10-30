class_name BreedingController
extends Node

signal changed

var _map: Node3D
var _pairs: Array[Dictionary] = []
var _active: Dictionary[Creature, Dictionary] = {}

func initialize(map: Node3D) -> void:
	_map = map
	set_physics_process(false)

func is_breeding(creature: Creature) -> bool:
	return _active.has(creature)

func are_partners(first: Creature, second: Creature) -> bool:
	if first == second or not _active.has(first):
		return false
	var pair: Dictionary = _active[first]
	return second == pair.male or second == pair.female

func _condition(creature: Creature, check_route: bool = false) -> String:
	if not is_instance_valid(creature) or not creature.available_for_breeding():
		return tr("Place the creature safely on the ground.")
	var data := creature.species_data()
	if creature.breeding_cooldown > 0.0:
		return tr("Recovering - %d s remaining") % ceili(creature.breeding_cooldown)
	if creature.satiety < maxf(data.breeding_min_satiety,data.breeding_satiety_cost):
		return tr("Needs at least %d%% satiety.") % ceili(maxf(data.breeding_min_satiety,data.breeding_satiety_cost))
	if not _map.navigation.ready_for_paths:
		return tr("Waiting for a clear route.")
	if _map.terrain_controller.surface_position(creature.global_position).y <= _map.water_controller.global_position.y+0.03:
		return tr("Needs dry ground for breeding.")
	var region: Region = _map.regions_controller.get_region_at(creature.global_position)
	if region == null or (data.habitat_ground >= 0 and region.terrain_coverage[data.habitat_ground] <= 0.001):
		return tr("Needs its preferred ground in the habitat.")
	if data.requires_water and (region.water_coverage <= 0.0 or (check_route and _map.navigation.route_to_water(creature.global_position,data.minimum_swim_depth).is_empty())):
		return tr("Needs accessible water in its habitat.")
	for egg: EggDefinition in _map.database.eggs:
		if egg.creature_id == creature.species_id:
			return ""
	return tr("No egg is defined for this species.")

func status(creature: Creature) -> String:
	if is_breeding(creature):
		return activity_text(creature)
	var reason := _condition(creature)
	if not reason.is_empty():
		return reason
	return tr("Ready - A male will call one compatible female.")

func start(creature: Creature) -> bool:
	if is_breeding(creature) or not _condition(creature,true).is_empty():
		return false
	var partner: Creature
	var chosen_path := PackedVector3Array()
	var nearest := INF
	for candidate: Node in get_tree().get_nodes_in_group("creatures"):
		if not candidate is Creature or candidate == creature or candidate.get_viewport() != creature.get_viewport():
			continue
		if candidate.species_id != creature.species_id or candidate.sex == creature.sex or is_breeding(candidate):
			continue
		if not _condition(candidate,true).is_empty():
			continue
		var male: Creature = creature if creature.sex == Creature.SEX.MALE else candidate
		var female: Creature = candidate if creature.sex == Creature.SEX.MALE else creature
		var path: PackedVector3Array = _map.navigation.route_to_partner(female,male)
		if path.is_empty():
			continue
		var length := 0.0
		for index in range(1,path.size()):
			length += path[index-1].distance_to(path[index])
		if length < nearest:
			nearest = length
			partner = candidate
			chosen_path = path
	if partner == null:
		return false
	var male: Creature = creature if creature.sex == Creature.SEX.MALE else partner
	var female: Creature = partner if creature.sex == Creature.SEX.MALE else creature
	for actor: Creature in [male,female]:
		if not actor.tree_exiting.is_connected(cancel.bind(actor)):
			actor.tree_exiting.connect(cancel.bind(actor))
		actor.interrupt_activity()
	if not _map.navigation.reserve_place(male,male.global_position) or not _map.navigation.reserve_place(female,chosen_path[-1]):
		_map.navigation.release_place(male)
		_map.navigation.release_place(female)
		return false
	var pair := {"male":male,"female":female,"path":chosen_path,"index":0,"revision":_map.navigation.revision,"elapsed":0.0,"call_elapsed":0.0,"age":0.0,"courting":false,"stuck":0.0,"last_position":female.global_position,"male_position":male.global_position,"check":0.0,"blocked_retries":0}
	_pairs.append(pair)
	_active[male] = pair
	_active[female] = pair
	male.face_point(female.global_position,&"behaviour/Call")
	set_physics_process(true)
	changed.emit()
	return true

func cancel(creature: Creature) -> void:
	if _active.has(creature):
		_end(_active[creature])

func progress(creature: Creature) -> float:
	if not _active.has(creature):
		return 0.0
	var pair: Dictionary = _active[creature]
	if not pair.courting:
		return clampf(pair.call_elapsed/maxf(pair.male.species_data().breeding_call_seconds,0.1),0.0,1.0)
	return clampf(pair.elapsed/creature.species_data().breeding_seconds,0.0,1.0)

func activity_text(creature: Creature) -> String:
	if not _active.has(creature):
		return ""
	var pair: Dictionary = _active[creature]
	if pair.courting:
		return tr("Breeding - %d s remaining") % ceili(creature.species_data().breeding_seconds-pair.elapsed)
	return tr("Calling for a mate") if creature == pair.male else tr("Approaching the calling male")

func move_creature(creature: Creature, delta: float) -> void:
	var pair: Dictionary = _active[creature]
	var male: Creature = pair.male
	var female: Creature = pair.female
	if not is_instance_valid(male) or not is_instance_valid(female):
		return
	if creature == male:
		male.face_point(female.global_position,&"Idle" if pair.courting else &"behaviour/Call")
		return
	if pair.courting:
		female.face_point(male.global_position)
		return
	var difference := Vector2(male.global_position.x-female.global_position.x,male.global_position.z-female.global_position.z)
	if difference.length() <= male.body_radius()+female.body_radius()+0.35 and _clear_sight(male,female):
		female.face_point(male.global_position)
		if pair.call_elapsed >= male.species_data().breeding_call_seconds:
			pair.courting = true
			pair.elapsed = 0.0
			male.set_breeding_effect(true)
			female.set_breeding_effect(true)
			changed.emit()
		return
	if not _map.navigation.ready_for_paths:
		return
	if pair.revision != _map.navigation.revision or male.global_position.distance_to(pair.male_position) > 0.4:
		_repath(pair)
	var path: PackedVector3Array = pair.path
	if pair.index >= path.size():
		_repath(pair)
		path = pair.path
		if path.is_empty():
			return
	var destination := path[pair.index]
	var direction := Vector2(destination.x-female.global_position.x,destination.z-female.global_position.z)
	var arrival_distance := 0.07 if pair.index == path.size()-1 else 0.14
	if direction.length() < arrival_distance:
		pair.index += 1
	else:
		female.walk_direction(direction.normalized(),female.species_data().walk_speed)
	pair.stuck += delta
	if pair.stuck >= 2.5:
		if female.global_position.distance_to(pair.last_position) < 0.12:
			pair.blocked_retries += 1
			_repath(pair)
			if pair.blocked_retries >= 3:
				_end(pair)
				return
		else:
			pair.blocked_retries = 0
		pair.stuck = 0.0
		pair.last_position = female.global_position

func _repath(pair: Dictionary) -> void:
	_map.navigation.release_place(pair.female)
	_map.navigation.release_place(pair.male)
	pair.path = _map.navigation.route_to_partner(pair.female,pair.male)
	if not pair.path.is_empty() and not _map.navigation.reserve_place(pair.female,pair.path[-1]):
		pair.path = PackedVector3Array()
	_map.navigation.reserve_place(pair.male,pair.male.global_position)
	pair.index = 0
	pair.revision = _map.navigation.revision
	pair.male_position = pair.male.global_position

func _physics_process(delta: float) -> void:
	for pair in _pairs.duplicate():
		if not is_instance_valid(pair.male) or not is_instance_valid(pair.female):
			_end(pair)
			continue
		var male: Creature = pair.male
		var female: Creature = pair.female
		if not male.available_for_breeding() or not female.available_for_breeding():
			_end(pair)
			continue
		if male.satiety <= male.species_data().breeding_satiety_cost or female.satiety <= female.species_data().breeding_satiety_cost:
			_end(pair)
			continue
		pair.age += delta
		pair.call_elapsed += delta
		if pair.age > 60.0+male.species_data().breeding_seconds:
			_end(pair)
			continue
		pair.check += delta
		if pair.check >= 0.5:
			pair.check = 0.0
			var region: Region = _map.regions_controller.get_region_at(male.global_position)
			if region == null or region.id != _map.regions_controller.region_id_at(female.global_position) or (male.species_data().requires_water and region.water_coverage <= 0.0) or (male.species_data().habitat_ground >= 0 and region.terrain_coverage[male.species_data().habitat_ground] <= 0.001):
				_end(pair)
				continue
			var male_dry: bool = _map.terrain_controller.surface_position(male.global_position).y > _map.water_controller.global_position.y+0.03
			var female_dry: bool = _map.terrain_controller.surface_position(female.global_position).y > _map.water_controller.global_position.y+0.03
			if not male_dry or not female_dry:
				_end(pair)
				continue
		if pair.courting:
			if Vector2(male.global_position.x-female.global_position.x,male.global_position.z-female.global_position.z).length() > male.body_radius()+female.body_radius()+0.6 or not _clear_sight(male,female):
				pair.courting = false
				pair.elapsed = 0.0
				male.set_breeding_effect(false)
				female.set_breeding_effect(false)
				_repath(pair)
				continue
			pair.elapsed += delta
			if pair.elapsed >= male.species_data().breeding_seconds:
				_finish(pair)

func _finish(pair: Dictionary) -> void:
	var male: Creature = pair.male
	for egg: EggDefinition in _map.database.eggs:
		if egg.creature_id == male.species_id:
			var point = _map.navigation.spawn_position((pair.male.global_position+pair.female.global_position)*0.5)
			if point == null:
				_end(pair)
				return
			var pickup := preload("res://scenes/incubation/loose_egg.tscn").instantiate() as LooseEggController
			_map.add_child(pickup)
			pickup.initialize(_map,egg,point)
			for creature: Creature in [pair.male,pair.female]:
				creature.satiety = maxf(0.0,creature.satiety-creature.species_data().breeding_satiety_cost)
				creature.breeding_cooldown = creature.species_data().breeding_cooldown
			_map.science.observe(male.species_id,&"breed",point)
			break
	_end(pair)

func _end(pair: Dictionary) -> void:
	if not _pairs.has(pair):
		return
	for creature in [pair.male,pair.female]:
		_active.erase(creature)
		if is_instance_valid(creature):
			creature.set_breeding_effect(false)
			creature.interrupt_activity()
	_pairs.erase(pair)
	set_physics_process(not _pairs.is_empty())
	changed.emit()

func _clear_sight(first: Creature, second: Creature) -> bool:
	var query := PhysicsRayQueryParameters3D.create(first.global_position,second.global_position,2)
	return _map.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
