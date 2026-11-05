class_name RockController
extends Node3D

signal obstacles_changed

const DEPOSIT_SCENE = preload("res://scenes/harvesting/deposit.tscn")
const PEBBLE_SCENE = preload("res://scenes/harvesting/loose_stone.tscn")
const LEGACY_PEBBLE_WIDTHS := {"stone_deposit":[1.51160097122192,1.38675701618195,1.55029892921448]}

var definitions: Array[DepositDefinition] = []

var _terrain: TerrainController
var _rocks: Array[HarvestableDeposit] = []
var _pebbles: Array[LooseStone] = []

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
	for pebble in _pebbles:
		_place_pebble(pebble,pebble.global_position)

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

func scatter_pebbles(point: Vector3, maximum_count: int, filter: Callable = Callable()) -> int:
	if maximum_count <= 0 or definitions.is_empty() or definitions[0].pebble_mesh == null or _terrain == null:
		return 0
	var data := definitions[0]
	var bounds := data.pebble_mesh.get_aabb().size
	var source_width := maxf(bounds.x,bounds.z)
	if source_width <= 0.0:
		return 0
	var wanted := mini(randi_range(3,5),maximum_count)
	var phase := randf()*TAU
	var placed := 0
	for attempt in wanted*16:
		var angle := phase+attempt*2.3999632297+randf_range(-0.25,0.25)
		var distance := randf_range(0.32,0.68)
		var candidate := point+Vector3(cos(angle),0,sin(angle))*distance
		if not _terrain.contains_world_point(candidate):
			continue
		candidate = _terrain.surface_position(candidate)
		var size := randf_range(0.16,0.24)/source_width
		var radius := Vector2(bounds.x,bounds.z).length()*size*0.5
		if not _pebble_site_valid(candidate,radius,filter):
			continue
		_make_pebble(data,candidate,size,randf_range(-PI,PI))
		placed += 1
		if placed >= wanted:
			break
	return placed

func _pebble_site_valid(point: Vector3, radius: float, filter: Callable) -> bool:
	var map := get_parent() as MapManager
	for offset: Vector3 in [Vector3.ZERO,Vector3.LEFT*radius,Vector3.RIGHT*radius,Vector3.FORWARD*radius,Vector3.BACK*radius]:
		var sample := point+offset
		if not _terrain.contains_world_point(sample) or (filter.is_valid() and not filter.call(sample)) or _terrain.ground_weight(sample,TerrainController.GROUND_TYPE.SAND) < 0.55:
			return false
		if map != null and _terrain.surface_position(sample).y <= map.water_controller.global_position.y+0.05:
			return false
	if _terrain.slope_at(point) > 0.5 or occupied(point,radius):
		return false
	if map != null:
		var local := _terrain.to_local(point)
		if map.building_controller.occupied(point,radius) or map.vegetation_controller.occupied(Vector2(local.x,local.z),radius):
			return false
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = point+Vector3.UP*radius
	query.collision_mask = 6
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		return false
	for pebble in _pebbles:
		if pebble.is_queued_for_deletion():
			continue
		var bounds := pebble.mesh.get_aabb().size
		var reach := radius+Vector2(bounds.x,bounds.z).length()*pebble.scale.x*0.5+0.015
		if Vector2(pebble.global_position.x-point.x,pebble.global_position.z-point.z).length_squared() < reach*reach:
			return false
	return true

func _make_pebble(data: DepositDefinition, point: Vector3, size: float, yaw: float) -> void:
	var pebble := PEBBLE_SCENE.instantiate() as LooseStone
	pebble.definition = data
	pebble.variant = 0
	pebble.mesh = data.pebble_mesh
	pebble.scale = Vector3.ONE*size
	pebble.rotation.y = yaw
	add_child(pebble)
	_place_pebble(pebble,point)
	_pebbles.append(pebble)
	pebble.tree_exiting.connect(_on_pebble_removed.bind(pebble))

func _place_pebble(pebble: LooseStone, point: Vector3) -> void:
	pebble.global_position = _terrain.surface_position(point)-Vector3.UP*pebble.mesh.get_aabb().position.y*pebble.scale.y+Vector3.UP*0.005

func _on_pebble_removed(pebble: LooseStone) -> void:
	_pebbles.erase(pebble)

func count_pebbles_near(point: Vector3, radius: float) -> int:
	var count := 0
	for pebble in _pebbles:
		if not pebble.is_queued_for_deletion() and Vector2(pebble.global_position.x-point.x,pebble.global_position.z-point.z).length_squared() < radius*radius:
			count += 1
	return count

func collect_pebbles_segment(from: Vector3, to: Vector3, radius: float) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var start := Vector2(from.x,from.z)
	var end := Vector2(to.x,to.z)
	for pebble: LooseStone in _pebbles.duplicate():
		var point := Vector2(pebble.global_position.x,pebble.global_position.z)
		var bounds := pebble.mesh.get_aabb().size
		var reach := maxf(bounds.x,bounds.z)*pebble.scale.x*0.5
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,start,end)) <= radius+reach:
			rewards.append({"kind":ResourceInventory.KIND.STONE,"quantity":1,"origin":pebble.global_position+Vector3.UP*0.05})
			_pebbles.erase(pebble)
			pebble.queue_free()
	return rewards

func capture_pebbles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pebble in _pebbles:
		if not pebble.is_queued_for_deletion():
			var bounds := pebble.mesh.get_aabb().size
			result.append({"id":pebble.definition.id,"position":pebble.global_position,"variant":0,"scale":pebble.scale.x,"width":maxf(bounds.x,bounds.z)*pebble.scale.x,"yaw":pebble.rotation.y})
	return result

func restore_pebbles(records: Array) -> void:
	for record: Dictionary in records:
		for data in definitions:
			if data.id == StringName(record.id) and data.pebble_mesh != null:
				var bounds := data.pebble_mesh.get_aabb().size
				var mesh_width := maxf(bounds.x,bounds.z)
				var width := float(record.get("width",mesh_width*record.scale))
				var legacy: Array = LEGACY_PEBBLE_WIDTHS.get(str(data.id),[])
				if not record.has("width") and record.variant >= 0 and record.variant < legacy.size():
					width = float(legacy[record.variant])*record.scale
				_make_pebble(data,record.position,width/maxf(mesh_width,0.001),record.yaw)
				break

func clear() -> void:
	for child in get_children():
		child.free()
	_rocks.clear()
	_pebbles.clear()
	obstacles_changed.emit()
