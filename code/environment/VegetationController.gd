class_name VegetationController
extends Node3D

const TREE_SCENE = preload("res://scenes/harvesting/deposit.tscn")

var species: Array[FloraSpecies] = []
@export var foliage_material: ShaderMaterial
@export var chunk_size := 16.0
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
var _clock := 0.0
var _elapsed := 0.0
var _cursor := -1
var _step_elapsed := 0.0
var _canopy_dirty := false
var _dirty_batches: Dictionary[String, bool] = {}

func initialize(terrain: TerrainController, environment: EnvironmentController) -> void:
	_terrain = terrain
	_environment = environment
	set_process(environment.enabled)
	if not environment.enabled:
		return
	global_transform = terrain.global_transform
	_material = foliage_material.duplicate() as ShaderMaterial
	terrain.bind_height_material(_material)
	_material.set_shader_parameter("follow_ground",true)
	var random := RandomNumberGenerator.new()
	random.seed = terrain.world_seed + 16127
	var patches := FastNoiseLite.new()
	patches.seed = terrain.world_seed + 32749
	patches.frequency = 0.14
	patches.fractal_octaves = 2
	for data in species:
		_spacing_by_kind[data.kind] = maxf(_spacing_by_kind.get(data.kind,0.0),data.spacing*data.maximum_scale)
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
			if not _has_space(point,data,scale_value):
				continue
			var plant := FloraPlant.new()
			plant.species = data
			plant.point = point
			plant.variant = random.randi_range(0,data.variants.size()-1)
			plant.scale = scale_value
			plant.yaw = random.randf_range(-PI,PI)
			plant.growth = 1.0 if _suitable(plant) else 0.0
			var chunk := Vector2i(((point+terrain.world_size*0.5)/chunk_size).floor())
			plant.batch_key = "%d:%d:%d:%d" % [species_index,plant.variant,chunk.x,chunk.y]
			_plants.append(plant)
			if data.kind == FloraSpecies.KIND.TREE:
				_trees.append(plant)
			if data.kind != FloraSpecies.KIND.TREE:
				if not _batch_plants.has(plant.batch_key):
					_batch_plants[plant.batch_key] = []
				_batch_plants[plant.batch_key].append(plant)
			var bucket := Vector2i((point/2.0).floor())
			if not _buckets.has(bucket):
				_buckets[bucket] = []
			_buckets[bucket].append(plant)
			placed += 1
	_update_canopies()
	for plant in _plants:
		plant.growth = 1.0 if _suitable(plant) else 0.0
	_create_batches()
	_upload_batches()
	_update_tree_views()
	terrain.height_changed.connect(_on_height_changed)

func _has_space(point: Vector2, data: FloraSpecies, scale_value: float) -> bool:
	var bucket := Vector2i((point/2.0).floor())
	var reach := maxi(1,ceili(_spacing_by_kind[data.kind]/2.0))
	for y in range(bucket.y-reach,bucket.y+reach+1):
		for x in range(bucket.x-reach,bucket.x+reach+1):
			for other: FloraPlant in _buckets.get(Vector2i(x,y),[]):
				var distance := maxf(data.spacing*scale_value,other.species.spacing*other.scale) if data.kind == other.species.kind else 0.16
				if data.kind == FloraSpecies.KIND.TREE or other.species.kind == FloraSpecies.KIND.TREE:
					distance = maxf(distance,0.42)
				if point.distance_squared_to(other.point) < distance*distance:
					return false
	return true

func _suitable(plant: FloraPlant) -> bool:
	if plant.removed or _clock < plant.regrow_at:
		return false
	var conditions := _environment.conditions_at(plant.point)
	var data := plant.species
	return conditions.x > data.moisture_range.x and conditions.x < data.moisture_range.y and conditions.y > data.shade_range.x and conditions.y < data.shade_range.y and conditions.z < data.maximum_slope and conditions.w > data.water_depth_range.x and conditions.w < data.water_depth_range.y

func _update_canopies() -> void:
	var canopies: Array[Vector4] = []
	for plant in _trees:
		if plant.species.canopy_radius > 0.0 and plant.growth > 0.1:
			canopies.append(Vector4(plant.point.x,plant.point.y,plant.species.canopy_radius*plant.scale*plant.growth,0.85*plant.growth))
	_environment.set_canopies(canopies)

func _create_batches() -> void:
	for key in _batch_plants:
		var plants: Array = _batch_plants[key]
		var first := plants[0] as FloraPlant
		var batch := MultiMeshInstance3D.new()
		batch.name = "Flora_%s" % key.replace(":","_")
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = first.species.variants[first.variant]
		batch.multimesh.instance_count = plants.size()
		batch.material_override = _material
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if first.species.kind == FloraSpecies.KIND.TREE else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var minimum := _terrain.mesh.get_aabb().position.y-0.1
		var maximum := _terrain.mesh.get_aabb().end.y+batch.multimesh.mesh.get_aabb().end.y*first.species.maximum_scale+0.1
		var bounds := AABB(Vector3(first.point.x,minimum,first.point.y),Vector3(0,maximum-minimum,0))
		for plant: FloraPlant in plants:
			bounds = bounds.expand(Vector3(plant.point.x,minimum,plant.point.y))
			bounds = bounds.expand(Vector3(plant.point.x,maximum,plant.point.y))
		bounds.position -= Vector3(2.5,0,2.5)
		bounds.size += Vector3(5,0,5)
		batch.multimesh.custom_aabb = bounds
		add_child(batch)
		_batches[key] = batch

func _upload_batches() -> void:
	for key in _batch_plants:
		_upload_batch(key)

func _upload_batch(key: String) -> void:
	var count := 0
	var batch := _batches[key].multimesh
	for plant: FloraPlant in _batch_plants[key]:
		if plant.growth < 0.025:
			continue
		var basis := Basis(Vector3.UP,plant.yaw).scaled(Vector3.ONE*plant.scale*plant.growth)
		batch.set_instance_transform(count,Transform3D(basis,Vector3(plant.point.x,0,plant.point.y)))
		count += 1
	batch.visible_instance_count = count

func _on_height_changed() -> void:
	var ground := _terrain.mesh.get_aabb()
	for key in _batches:
		var batch := _batches[key].multimesh
		var plant := _batch_plants[key][0] as FloraPlant
		var bounds := batch.custom_aabb
		bounds.position.y = ground.position.y-0.1
		bounds.size.y = ground.size.y+batch.mesh.get_aabb().end.y*plant.species.maximum_scale+0.2
		batch.custom_aabb = bounds
	_update_tree_views()

func _update_tree_views() -> void:
	for plant in _trees:
		if plant.removed:
			continue
		if not is_instance_valid(plant.tree_view):
			if plant.growth < 0.025:
				continue
			plant.tree_view = TREE_SCENE.instantiate() as HarvestableDeposit
			add_child(plant.tree_view)
			plant.tree_view.hits_required = plant.species.hits_required
			plant.tree_view.resource_kind = plant.species.harvest_resource
			plant.tree_view.yield_amount = maxi(1,roundi(plant.species.harvest_amount*plant.scale))
			plant.tree_view.configure(plant.species.variants[plant.variant],_material,plant.yaw,plant.species.trunk_radius,plant.species.trunk_height)
			plant.tree_view.depleted.connect(_on_tree_depleted.bind(plant))
		plant.tree_view.set_growth(plant.growth,plant.scale)
		plant.tree_view.global_position = _terrain.surface_position(_terrain.to_global(Vector3(plant.point.x,0,plant.point.y)))

func _on_tree_depleted(_deposit: HarvestableDeposit, plant: FloraPlant) -> void:
	plant.removed = true
	plant.growth = 0.0
	_update_canopies()

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
				if not plant.removed and plant.growth > 0.5 and plant.species.kind <= FloraSpecies.KIND.SHRUB and point.distance_squared_to(plant.point) < radius*radius:
					return true
	return false

func gather_plants(world_position: Vector3, radius: float) -> Dictionary[int, int]:
	var result: Dictionary[int, int] = {}
	var local := _terrain.to_local(world_position)
	var point := Vector2(local.x,local.z)
	var first := Vector2i(((point-Vector2.ONE*radius)/2.0).floor())
	var last := Vector2i(((point+Vector2.ONE*radius)/2.0).floor())
	var dirty: Dictionary[String, bool] = {}
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			for plant: FloraPlant in _buckets.get(Vector2i(x,y),[]):
				if plant.species.kind == FloraSpecies.KIND.TREE or plant.growth < 0.6 or point.distance_squared_to(plant.point) > radius*radius:
					continue
				var kind := plant.species.harvest_resource
				result[kind] = result.get(kind,0)+plant.species.harvest_amount
				plant.growth = 0.0
				plant.regrow_at = _clock+plant.species.regrowth_delay
				dirty[plant.batch_key] = true
	for key in dirty:
		_upload_batch(key)
	return result

func _process(delta: float) -> void:
	_clock += delta
	_elapsed += delta
	if _cursor < 0 and _elapsed >= 0.5:
		_step_elapsed = minf(_elapsed,2.0)
		_elapsed = 0.0
		_cursor = 0
	if _cursor < 0:
		return
	var deadline := Time.get_ticks_usec()+1500
	while _cursor < _plants.size() and Time.get_ticks_usec() < deadline:
		var last := mini(_cursor+64,_plants.size())
		for index in range(_cursor,last):
			var plant := _plants[index]
			var target := 1.0 if _suitable(plant) else 0.0
			var rate := plant.species.growth_rate if target > plant.growth else plant.species.decay_rate
			var growth := move_toward(plant.growth,target,rate*_step_elapsed)
			if not is_equal_approx(growth,plant.growth):
				plant.growth = growth
				if plant.species.kind != FloraSpecies.KIND.TREE:
					_dirty_batches[plant.batch_key] = true
				_canopy_dirty = _canopy_dirty or plant.species.canopy_radius > 0.0
		_cursor = last
	if _cursor == _plants.size():
		_cursor = -1
		if _canopy_dirty:
			_update_canopies()
			_update_tree_views()
			_canopy_dirty = false
		for key in _dirty_batches:
			_upload_batch(key)
		_dirty_batches.clear()
