class_name RockController
extends Node3D

signal obstacles_changed

const DEPOSIT_SCENE = preload("res://scenes/harvesting/deposit.tscn")

var definitions: Array[DepositDefinition] = []

var _terrain: TerrainController
var _rocks: Array[HarvestableDeposit] = []

func initialize(terrain: TerrainController, environment: EnvironmentController, vegetation: VegetationController) -> void:
	_terrain = terrain
	global_transform = terrain.global_transform
	terrain.height_changed.connect(_update_ground)
	if definitions.is_empty() or not environment.enabled:
		return
	for definition in definitions:
		_spawn_deposits(definition,environment,vegetation)

func _spawn_deposits(data: DepositDefinition, environment: EnvironmentController, vegetation: VegetationController) -> void:
	if data.variants.is_empty() or data.density <= 0.0:
		return
	var terrain := _terrain
	var random := RandomNumberGenerator.new()
	random.seed = terrain.world_seed+65521+int(hash(data.id)%10000)
	var wanted := maxi(1,ceili(terrain.world_size.x*terrain.world_size.y*data.density))
	var placed := 0
	for attempt in wanted*40:
		if placed >= wanted:
			break
		var point := Vector2(random.randf_range(-terrain.world_size.x*0.5+1.0,terrain.world_size.x*0.5-1.0),random.randf_range(-terrain.world_size.y*0.5+1.0,terrain.world_size.y*0.5-1.0))
		var conditions := environment.conditions_at(point)
		if point.length() < 2.8 or conditions.w > -0.1 or conditions.z > 0.65 or vegetation.occupied(point,0.85):
			continue
		var close := false
		for existing in _rocks:
			var previous := terrain.to_local(existing.global_position)
			if point.distance_squared_to(Vector2(previous.x,previous.z)) < data.spacing*data.spacing:
				close = true
				break
		if close:
			continue
		var rock := DEPOSIT_SCENE.instantiate() as HarvestableDeposit
		rock.kind = HarvestableDeposit.KIND.ROCK
		rock.resource_kind = data.harvest_resource
		rock.hits_required = data.hits_required
		var scale_value := random.randf_range(data.minimum_scale,data.maximum_scale)
		rock.yield_amount = maxi(1,roundi(data.harvest_amount*scale_value))
		add_child(rock)
		var source := data.variants[random.randi_range(0,data.variants.size()-1)]
		var bounds := source.get_aabb()
		rock.configure(source,data.material,random.randf_range(-PI,PI),maxf(bounds.size.x,bounds.size.z)*0.42,bounds.size.y*0.9)
		rock.scale = Vector3.ONE*scale_value
		rock.global_position = terrain.surface_position(terrain.to_global(Vector3(point.x,0,point.y)))
		rock.depleted.connect(_on_rock_depleted)
		_rocks.append(rock)
		placed += 1

func _on_rock_depleted(rock: HarvestableDeposit) -> void:
	_rocks.erase(rock)
	obstacles_changed.emit()

func _update_ground() -> void:
	for rock in _rocks:
		rock.global_position = _terrain.surface_position(rock.global_position)

func rock_at_screen(screen: Vector2, camera: Camera3D) -> HarvestableDeposit:
	var best: HarvestableDeposit
	var distance := 1.0
	for rock in _rocks:
		var candidate := rock.hover_distance(screen,camera)
		if candidate < distance:
			distance = candidate
			best = rock
	return best

func occupied(world_position: Vector3, radius: float) -> bool:
	for rock in _rocks:
		if is_instance_valid(rock) and not rock.exhausted:
			var reach := maxf(rock.mesh.get_aabb().size.x,rock.mesh.get_aabb().size.z)*rock.scale.x*0.45+radius
			if Vector2(rock.global_position.x,rock.global_position.z).distance_squared_to(Vector2(world_position.x,world_position.z)) < reach*reach:
				return true
	return false

func count_near(world_position: Vector3, radius: float) -> int:
	var count := 0
	for rock in _rocks:
		if is_instance_valid(rock) and not rock.exhausted and Vector2(rock.global_position.x-world_position.x,rock.global_position.z-world_position.z).length() < radius:
			count += 1
	return count

func create_deposit(world_position: Vector3) -> bool:
	if definitions.is_empty() or not _terrain.contains_world_point(world_position) or occupied(world_position,0.65):
		return false
	var data := definitions[0]
	if data.variants.is_empty():
		return false
	var rock := DEPOSIT_SCENE.instantiate() as HarvestableDeposit
	rock.kind = HarvestableDeposit.KIND.ROCK
	rock.resource_kind = data.harvest_resource
	rock.hits_required = data.hits_required
	rock.yield_amount = data.harvest_amount
	add_child(rock)
	var source := data.variants[randi_range(0,data.variants.size()-1)]
	var bounds := source.get_aabb()
	rock.configure(source,data.material,randf_range(-PI,PI),maxf(bounds.size.x,bounds.size.z)*0.42,bounds.size.y*0.9)
	rock.scale = Vector3.ONE*randf_range(data.minimum_scale,data.maximum_scale)
	rock.global_position = _terrain.surface_position(world_position)
	rock.depleted.connect(_on_rock_depleted)
	_rocks.append(rock)
	obstacles_changed.emit()
	return true
