class_name VegetationController
extends Node3D

signal plant_sown(species: FloraSpecies, world_position: Vector3)
signal obstacles_changed
signal sapling_found(id: StringName, world_position: Vector3)

const TREE_SCENE = preload("res://scenes/harvesting/deposit.tscn")

var species: Array[FloraSpecies] = []
@export var foliage_material: ShaderMaterial
@export var chunk_size := 6.0
@export var spawn_clearing_radius := 3.2

var _terrain: TerrainController
var _environment: EnvironmentController
var _plants: Array[FloraPlant] = []
var _trees: Array[FloraPlant] = []
var _batches: Dictionary[String, MultiMeshInstance3D] = {}
var _batch_plants: Dictionary[String, Array] = {}
var _buckets: Dictionary[Vector2i, Array] = {}
var _spacing_by_kind: Dictionary[int, float] = {}
var _material: ShaderMaterial
var _detail_bias := 1.0
var _growing: Array[FloraPlant] = []
var _elapsed := 0.0
var _dirty_batches: Dictionary[String, bool] = {}

func initialize(terrain: TerrainController, environment: EnvironmentController) -> void:
	_terrain = terrain
	_environment = environment
	set_process(false)
	global_transform = terrain.global_transform
	_material = foliage_material.duplicate(true) as ShaderMaterial
	var current: ShaderMaterial = _material
	while current != null:
		terrain.bind_height_material(current)
		current.set_shader_parameter("follow_ground",false)
		current = current.next_pass as ShaderMaterial
	for data in species:
		_spacing_by_kind[data.kind] = maxf(_spacing_by_kind.get(data.kind,0.0),data.spacing*data.maximum_scale)
	if environment.enabled:
		_generate_initial_plants()
	_flush_dirty_batches()
	set_process(not _growing.is_empty())
	terrain.height_changed.connect(_on_height_changed)

func update_detail(visible_world_height: float) -> void:
	var bias := clampf(pow(4.0/maxf(visible_world_height,1.6),4.0),0.001,1.0)
	if absf(bias-_detail_bias) < maxf(0.0001,_detail_bias*0.02):
		return
	_detail_bias = bias
	for key in _batches:
		_batches[key].lod_bias = _detail_bias
	for plant in _trees:
		if is_instance_valid(plant.tree_view):
			plant.tree_view.lod_bias = _detail_bias

func _generate_initial_plants() -> void:
	var terrain := _terrain
	var random := RandomNumberGenerator.new()
	random.seed = terrain.world_seed + 16127
	var patches := FastNoiseLite.new()
	patches.seed = terrain.world_seed + 32749
	patches.frequency = 0.14
	patches.fractal_octaves = 2
	for species_index in species.size():
		var data := species[species_index]
		if data.variants.is_empty() or data.density <= 0.0:
			continue
		var wanted := maxi(1,int(terrain.world_size.x*terrain.world_size.y*data.density))
		var placed := 0
		for attempt in wanted*14:
			if placed >= wanted:
				break
			var point := Vector2(random.randf_range(-terrain.world_size.x*0.5+0.3,terrain.world_size.x*0.5-0.3),random.randf_range(-terrain.world_size.y*0.5+0.3,terrain.world_size.y*0.5-0.3))
			var clearing := spawn_clearing_radius if data.kind == FloraSpecies.KIND.TREE else 1.35 if data.kind == FloraSpecies.KIND.SHRUB else 0.65
			if point.length() < clearing:
				continue
			var patch := patches.get_noise_2dv(point)*0.5+0.5
			var probability := clampf((patch-0.25)*1.8,0.08,0.9) if data.kind <= FloraSpecies.KIND.SHRUB else clampf(patch*1.4,0.15,0.95)
			if random.randf() > probability:
				continue
			var scale_value := random.randf_range(data.minimum_scale,data.maximum_scale)
			if not _can_grow_at(data,point) or not _has_space(point,data,scale_value):
				continue
			_create_plant(data,point,random.randi_range(0,data.variants.size()-1),scale_value,random.randf_range(-PI,PI),1.0)
			placed += 1

func _has_space(point: Vector2, data: FloraSpecies, scale_value: float) -> bool:
	var bucket := Vector2i((point/2.0).floor())
	var reach := maxi(1,ceili(_spacing_by_kind[data.kind]/2.0))
	for y in range(bucket.y-reach,bucket.y+reach+1):
		for x in range(bucket.x-reach,bucket.x+reach+1):
			for other: FloraPlant in _buckets.get(Vector2i(x,y),[]):
				if other.removed:
					continue
				var distance := maxf(data.spacing*scale_value,other.species.spacing*other.scale) if data.kind == other.species.kind else 0.16
				if data.kind == FloraSpecies.KIND.TREE or other.species.kind == FloraSpecies.KIND.TREE:
					distance = maxf(distance,0.42)
				if point.distance_squared_to(other.point) < distance*distance:
					return false
	return true

func _can_grow_at(data: FloraSpecies, point: Vector2) -> bool:
	var conditions := _environment.conditions_at(point)
	var world := _terrain.to_global(Vector3(point.x,0,point.y))
	return conditions.z < data.maximum_slope and conditions.w > data.water_depth_range.x and conditions.w < data.water_depth_range.y and (data.ground_material < 0 or _terrain.ground_weight(world,data.ground_material) >= 0.55)

func _create_plant(data: FloraSpecies, point: Vector2, variant: int, scale_value: float, yaw: float, growth: float) -> FloraPlant:
	var plant := FloraPlant.new()
	plant.species = data
	plant.point = point
	plant.variant = variant
	plant.scale = scale_value
	plant.yaw = yaw
	plant.growth = growth
	var chunk := Vector2i(((point+_terrain.world_size*0.5)/chunk_size).floor())
	plant.batch_key = "%d:%d:%d:%d" % [species.find(data),variant,chunk.x,chunk.y]
	_plants.append(plant)
	var bucket := Vector2i((point/2.0).floor())
	if not _buckets.has(bucket):
		_buckets[bucket] = []
	_buckets[bucket].append(plant)
	if data.kind == FloraSpecies.KIND.TREE:
		_trees.append(plant)
		_update_tree_view(plant)
	else:
		if not _batch_plants.has(plant.batch_key):
			_batch_plants[plant.batch_key] = []
		_batch_plants[plant.batch_key].append(plant)
		if not _batches.has(plant.batch_key):
			_create_batch(plant.batch_key)
		_dirty_batches[plant.batch_key] = true
	if growth < 1.0:
		_growing.append(plant)
	set_process(not _growing.is_empty() or not _dirty_batches.is_empty())
	return plant

func _remove_plant(plant: FloraPlant) -> bool:
	if plant.removed:
		return false
	plant.removed = true
	plant.growth = 0.0
	_plants.erase(plant)
	_trees.erase(plant)
	_growing.erase(plant)
	var bucket := Vector2i((plant.point/2.0).floor())
	_buckets[bucket].erase(plant)
	if _buckets[bucket].is_empty():
		_buckets.erase(bucket)
	if plant.species.kind != FloraSpecies.KIND.TREE:
		var key := plant.batch_key
		_batch_plants[key].erase(plant)
		if _batch_plants[key].is_empty():
			_batch_plants.erase(key)
			_batches[key].queue_free()
			_batches.erase(key)
			_dirty_batches.erase(key)
		else:
			_dirty_batches[key] = true
	plant.tree_view = null
	set_process(not _growing.is_empty() or not _dirty_batches.is_empty())
	return true

func clear() -> void:
	for plant in _plants:
		plant.removed = true
		plant.tree_view = null
	for child in get_children():
		child.free()
	_plants.clear()
	_trees.clear()
	_batches.clear()
	_batch_plants.clear()
	_buckets.clear()
	_growing.clear()
	_dirty_batches.clear()
	_elapsed = 0.0
	set_process(false)

func capture_state() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for plant in _plants:
		records.append({"id":plant.species.id,"point":plant.point,"variant":plant.variant,"scale":plant.scale,"yaw":plant.yaw,"growth":plant.growth,"hits":plant.tree_view._hits if is_instance_valid(plant.tree_view) else 0})
	return records

func restore_state(records: Array) -> void:
	clear()
	for record: Dictionary in records:
		var data: FloraSpecies
		for candidate in species:
			if candidate.id == StringName(record.id):
				data = candidate
				break
		var plant := _create_plant(data,record.point,record.variant,record.scale,record.yaw,record.growth)
		if is_instance_valid(plant.tree_view):
			plant.tree_view.restore_hits(record.hits)
	_flush_dirty_batches()
	obstacles_changed.emit()

func _create_batch(key: String) -> void:
	var first := _batch_plants[key][0] as FloraPlant
	var batch := MultiMeshInstance3D.new()
	batch.name = "Flora_%s" % key.replace(":","_")
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = first.species.variants[first.variant]
	batch.material_override = _material
	batch.lod_bias = _detail_bias
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var chunk := Vector2i(((first.point+_terrain.world_size*0.5)/chunk_size).floor())
	var corner := Vector2(chunk)*chunk_size-_terrain.world_size*0.5
	batch.multimesh.custom_aabb = AABB(Vector3(corner.x-3,_terrain.minimum_height-1,corner.y-3),Vector3(chunk_size+6,_terrain.maximum_height-_terrain.minimum_height+8,chunk_size+6))
	add_child(batch)
	_batches[key] = batch

func _flush_dirty_batches() -> void:
	for key in _dirty_batches:
		_upload_batch(key)
	_dirty_batches.clear()
	set_process(not _growing.is_empty())

func _upload_batch(key: String) -> void:
	var count := 0
	var batch := _batches[key].multimesh
	var source_bounds: AABB = batch.mesh.get_aabb()
	var visible_bounds := AABB()
	if batch.instance_count != _batch_plants[key].size():
		batch.instance_count = _batch_plants[key].size()
	for plant: FloraPlant in _batch_plants[key]:
		if plant.removed or plant.growth < 0.025:
			continue
		var basis := Basis(Vector3.UP,plant.yaw).scaled(Vector3.ONE*plant.scale*plant.growth)
		var surface := _terrain.to_local(_terrain.surface_position(_terrain.to_global(Vector3(plant.point.x,0,plant.point.y))))
		batch.set_instance_transform(count,Transform3D(basis,surface))
		var plant_bounds := Transform3D(basis,surface)*source_bounds
		visible_bounds = plant_bounds if count == 0 else visible_bounds.merge(plant_bounds)
		count += 1
	batch.visible_instance_count = count
	if count > 0:
		batch.custom_aabb = visible_bounds.grow(0.05)

func _on_height_changed() -> void:
	for key in _batches:
		_upload_batch(key)
	_update_tree_views()

func _update_tree_views() -> void:
	for plant in _trees:
		_update_tree_view(plant)

func _update_tree_view(plant: FloraPlant) -> void:
	if not is_instance_valid(plant.tree_view):
		if plant.growth < 0.025:
			return
		plant.tree_view = TREE_SCENE.instantiate() as HarvestableDeposit
		add_child(plant.tree_view)
		plant.tree_view.lod_bias = _detail_bias
		plant.tree_view.hits_required = plant.species.hits_required
		plant.tree_view.resource_kind = plant.species.harvest_resource
		plant.tree_view.yield_amount = maxi(1,roundi(plant.species.harvest_amount*plant.scale))
		plant.tree_view.configure(plant.species.variants[plant.variant],_material,plant.yaw,plant.species.trunk_radius,plant.species.trunk_height)
		plant.tree_view.depleted.connect(_on_tree_depleted.bind(plant))
	plant.tree_view.set_growth(plant.growth,plant.scale)
	plant.tree_view.global_position = _terrain.surface_position(_terrain.to_global(Vector3(plant.point.x,0,plant.point.y)))

func _on_tree_depleted(deposit: HarvestableDeposit, plant: FloraPlant) -> void:
	if not _remove_plant(plant):
		return
	_harvest_sapling(plant,deposit.global_position)
	obstacles_changed.emit()

func _harvest_sapling(plant: FloraPlant, world_position: Vector3) -> void:
	var chance := clampf(plant.species.sapling_chance,0.0,1.0)
	if not plant.species.sapling_item.is_empty() and chance > 0.0 and (chance >= 1.0 or randf() < chance):
		sapling_found.emit(plant.species.sapling_item,world_position+Vector3.UP*0.2)

func tree_at_screen(screen: Vector2, camera: Camera3D) -> HarvestableDeposit:
	var best: HarvestableDeposit
	var distance := 1.0
	for plant in _trees:
		if plant.removed or not is_instance_valid(plant.tree_view):
			continue
		var candidate := plant.tree_view.hover_distance(screen,camera)
		if candidate < distance:
			distance = candidate
			best = plant.tree_view
	return best

func occludes_target(screen: Vector2, camera: Camera3D, target: HarvestableDeposit) -> bool:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var reach := maxf(0.0,(target.global_position+Vector3.UP*0.2-origin).dot(direction))
	var end := origin+direction*reach
	for plant in _trees:
		var tree := plant.tree_view
		if plant.removed or not is_instance_valid(tree) or tree == target or not tree.is_visible_in_tree():
			continue
		var bounds := tree.mesh.get_aabb()
		var center := Vector3(bounds.get_center().x,bounds.position.y+bounds.size.y*0.73,bounds.get_center().z)
		var radii := Vector3(bounds.size.x*0.43,bounds.size.y*0.28,bounds.size.z*0.43)
		var local_origin := (tree.to_local(origin)-center)/radii
		var delta := (tree.to_local(end)-tree.to_local(origin))/radii
		var a := delta.dot(delta)
		var b := 2.0*local_origin.dot(delta)
		var c := local_origin.dot(local_origin)-1.0
		var discriminant := b*b-4.0*a*c
		if a > 0.000001 and discriminant >= 0.0:
			var fraction := (-b-sqrt(discriminant))/(2.0*a)
			if fraction > 0.0 and fraction < 0.98:
				return true
	return false

func occupied(point: Vector2, radius: float) -> bool:
	var bucket := Vector2i((point/2.0).floor())
	var reach := maxi(1,ceili(radius/2.0))
	for y in range(bucket.y-reach,bucket.y+reach+1):
		for x in range(bucket.x-reach,bucket.x+reach+1):
			for plant: FloraPlant in _buckets.get(Vector2i(x,y),[]):
				if not plant.removed and plant.growth > 0.025 and plant.species.kind <= FloraSpecies.KIND.SHRUB and point.distance_squared_to(plant.point) < radius*radius:
					return true
	return false

func gather_plants(world_position: Vector3, radius: float) -> Dictionary[int, int]:
	var result: Dictionary[int, int] = {}
	var local := _terrain.to_local(world_position)
	var point := Vector2(local.x,local.z)
	var first := Vector2i(((point-Vector2.ONE*radius)/2.0).floor())
	var last := Vector2i(((point+Vector2.ONE*radius)/2.0).floor())
	var obstacles_removed := false
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			for plant: FloraPlant in _buckets.get(Vector2i(x,y),[]).duplicate():
				if plant.removed or plant.species.kind == FloraSpecies.KIND.TREE or plant.growth < 0.6 or point.distance_squared_to(plant.point) > radius*radius:
					continue
				var kind := plant.species.harvest_resource
				result[kind] = result.get(kind,0)+plant.species.harvest_amount
				obstacles_removed = obstacles_removed or plant.species.kind == FloraSpecies.KIND.SHRUB
				_remove_plant(plant)
				_harvest_sapling(plant,_terrain.surface_position(_terrain.to_global(Vector3(plant.point.x,0,plant.point.y))))
	_flush_dirty_batches()
	if obstacles_removed:
		obstacles_changed.emit()
	return result


func _process(delta: float) -> void:
	_elapsed += delta
	for index in range(_growing.size()-1,-1,-1):
		var plant := _growing[index]
		plant.growth = minf(1.0,plant.growth+plant.species.growth_rate*delta)
		if plant.species.kind != FloraSpecies.KIND.TREE:
			_dirty_batches[plant.batch_key] = true
		if plant.growth >= 1.0:
			_growing.remove_at(index)
	if _elapsed >= 0.1:
		_elapsed = 0.0
		_flush_dirty_batches()
		_update_tree_views()
	if _growing.is_empty() and _dirty_batches.is_empty():
		set_process(false)

func grass_species() -> FloraSpecies:
	for data in species:
		if data.kind == FloraSpecies.KIND.GRASS:
			return data
	return null

func can_seed_grass(world_position: Vector3) -> bool:
	var data := grass_species()
	if data == null or data.variants.is_empty() or _material == null or not _terrain.contains_world_point(world_position):
		return false
	var local := _terrain.to_local(world_position)
	var point := Vector2(local.x,local.z)
	var soil := _terrain.ground_weight(world_position,TerrainController.GROUND_TYPE.SOIL)
	var grass := _terrain.ground_weight(world_position,TerrainController.GROUND_TYPE.GRASS)
	return soil+grass >= 0.55 and _can_grow_at(data,point) and _has_space(point,data,1.0)

func seed_grass(world_position: Vector3, count: int, radius: float = 1.0) -> int:
	var data := grass_species()
	if data == null or data.variants.is_empty() or _material == null:
		return 0
	var local := _terrain.to_local(world_position)
	var center := Vector2(local.x,local.z)
	var planted := 0
	for attempt in count*25:
		if planted >= count:
			break
		var point := center+Vector2.from_angle(randf()*TAU)*sqrt(randf())*radius*0.72
		var world := _terrain.to_global(Vector3(point.x,0,point.y))
		if not can_seed_grass(world):
			continue
		_create_plant(data,point,randi_range(0,data.variants.size()-1),randf_range(data.minimum_scale,data.maximum_scale),randf()*TAU,0.05)
		planted += 1
	if planted > 0:
		plant_sown.emit(data,world_position)
		_terrain.grow_grass(world_position,radius)
		set_process(true)
	return planted

func present_species() -> Array[FloraSpecies]:
	var result: Array[FloraSpecies] = []
	for plant: FloraPlant in _plants:
		if not plant.removed and not result.has(plant.species):
			result.append(plant.species)
	return result

func can_plant(data: FloraSpecies, world_position: Vector3) -> bool:
	if data == null or data.variants.is_empty() or not _terrain.contains_world_point(world_position):
		return false
	var local := _terrain.to_local(world_position)
	var point := Vector2(local.x,local.z)
	return _can_grow_at(data,point) and _has_space(point,data,1.0)

func plant_specimen(data: FloraSpecies, world_position: Vector3) -> bool:
	if not can_plant(data,world_position):
		return false
	var local := _terrain.to_local(world_position)
	var point := Vector2(local.x,local.z)
	_create_plant(data,point,randi_range(0,data.variants.size()-1),1.0,randf()*TAU,0.25)
	if data.kind == FloraSpecies.KIND.GRASS:
		_terrain.grow_grass(world_position,0.65)
	set_process(true)
	plant_sown.emit(data,world_position)
	obstacles_changed.emit()
	return true

func count_near(world_position: Vector3, radius: float, ids: Array[StringName]) -> int:
	var local := _terrain.to_local(world_position)
	var center := Vector2(local.x,local.z)
	var count := 0
	for plant in _plants:
		if not plant.removed and plant.species.id in ids and plant.point.distance_to(center) < radius:
			count += 1
	return count

func flatten_ground_plants(world_position: Vector3, radius: float) -> int:
	var local := _terrain.to_local(world_position)
	var center := Vector2(local.x,local.z)
	var removed := 0
	for plant in _plants.duplicate():
		if plant.removed or plant.species.kind in [FloraSpecies.KIND.TREE,FloraSpecies.KIND.SHRUB] or plant.point.distance_to(center) > radius:
			continue
		_remove_plant(plant)
		removed += 1
	if removed > 0:
		set_process(true)
	return removed
