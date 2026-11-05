class_name LandscapeController
extends Node

const KINDS := {TerrainController.GROUND_TYPE.GRASS:&"grass",TerrainController.GROUND_TYPE.SOIL:&"soil",TerrainController.GROUND_TYPE.SAND:&"sand",TerrainController.GROUND_TYPE.ROCK:&"rock"}
const SITE_BUCKET_SIZE := 8

var _map: MapManager
var _size := Vector2i.ZERO
var _extent := Vector2.ZERO
var _ids := PackedInt32Array()
var _colors := PackedColorArray()
var _dry := PackedByteArray()
var _totals: Dictionary[int,PackedFloat64Array] = {}
var _members: Dictionary[int,Array] = {}
var _sites: Dictionary[String,Dictionary] = {}
var _site_profiles: Dictionary[int,Array] = {}
var _targets: Dictionary[int,PackedFloat64Array] = {}
var _targets_frame := -1
var _dirty_all := true
var _dirty_bounds := Rect2()
var _ground_pending := false
var _height_pending := false
var _natural_coverage_source: Image

func initialize(map: MapManager) -> void:
	_map = map
	_natural_coverage_source = map.terrain_controller._natural_image
	map.regions_controller.regions_changed.connect(_invalidate)
	map.terrain_controller.ground_area_changed.connect(_ground_area_changed)
	map.terrain_controller.height_area_changed.connect(_height_area_changed)
	map.terrain_controller.terrain_changed.connect(_ground_changed)
	map.terrain_controller.height_changed.connect(_height_changed)
	map.water_controller.water_level_changed.connect(_invalidate)

func _invalidate() -> void:
	_dirty_all = true
	_targets_frame = -1
	_sites.clear()
	_site_profiles.clear()

func _ground_area_changed(bounds: Rect2) -> void:
	_ground_pending = true
	_mark_bounds(bounds)

func _height_area_changed(bounds: Rect2) -> void:
	_height_pending = true
	_mark_bounds(bounds)

func _ground_changed() -> void:
	var local_change := _ground_pending
	_ground_pending = false
	var nature := _map.terrain_controller._natural_image
	if nature != _natural_coverage_source:
		_natural_coverage_source = nature
		_invalidate()
	elif not local_change:
		_invalidate()

func _height_changed() -> void:
	if _height_pending:
		_height_pending = false
	else:
		_invalidate()

func _mark_bounds(bounds: Rect2) -> void:
	_dirty_bounds = _dirty_bounds.merge(bounds) if _dirty_bounds.has_area() else bounds

func _sync() -> bool:
	if _map == null or _map.regions_controller._rebuild_pending:
		return false
	if _dirty_all:
		_size = Vector2i(ceil(_map.terrain_controller.world_size/_map.regions_controller.cell_size))
		_extent = _map.terrain_controller.world_size/Vector2(_size)
		_ids.resize(_size.x*_size.y)
		_ids.fill(0)
		_colors.resize(_ids.size())
		_colors.fill(Color(0,0,0,0))
		_dry.resize(_ids.size())
		_dry.fill(0)
		_totals.clear()
		_members.clear()
		_sites.clear()
		_site_profiles.clear()
		_refresh(Rect2i(Vector2i.ZERO,_size),true)
		_dirty_all = false
		_dirty_bounds = Rect2()
	elif _dirty_bounds.has_area():
		var half := _map.terrain_controller.world_size*0.5
		var first := Vector2i(((_dirty_bounds.position+half)/_extent).floor()).max(Vector2i.ZERO)
		var last := Vector2i(((_dirty_bounds.end+half)/_extent).ceil()).min(_size)
		_dirty_bounds = Rect2()
		if last.x > first.x and last.y > first.y:
			_refresh(Rect2i(first,last-first),false)
	return true

func _refresh(bounds: Rect2i, topology: bool) -> void:
	var sample := _map.terrain_controller.sample_coverage_window(_size,bounds)
	var sample_area := _extent.x*_extent.y
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var index := y*_size.x+x
			var previous_id := _ids[index]
			if _ids[index] > 0 and _dry[index] != 0:
				_accumulate(_ids[index],_colors[index],-sample_area)
			var point := _cell_position(index)
			var id := _map.regions_controller.region_id_at(point)
			_ids[index] = id
			_colors[index] = sample.get_pixel(x-bounds.position.x,y-bounds.position.y)
			_dry[index] = int(point.y > _map.water_controller.global_position.y+0.015)
			if not _sites.is_empty():
				_refresh_site_cell(index,previous_id,id)
			if id > 0:
				if topology:
					if not _members.has(id):
						_members[id] = []
					_members[id].append(index)
				if _dry[index] != 0:
					_accumulate(id,_colors[index],sample_area)

func _accumulate(id: int, color: Color, area: float) -> void:
	var totals: PackedFloat64Array = _totals.get(id,PackedFloat64Array([0,0,0,0,0,0]))
	totals[0] += area
	totals[1] += maxf(0.0,1.0-color.r-color.g-color.b-color.a)*area
	totals[2] += color.r*area
	totals[3] += color.g*area
	totals[4] += color.b*area
	totals[5] += color.a*area
	_totals[id] = totals

func _cell_position(index: int) -> Vector3:
	var local := (Vector2(index%_size.x,index/_size.x)+Vector2(0.5,0.5))*_extent-_map.terrain_controller.world_size*0.5
	return _map.terrain_controller.surface_position(_map.terrain_controller.to_global(Vector3(local.x,0,local.y)))

func _refresh_targets() -> void:
	var frame := Engine.get_physics_frames()
	if frame == _targets_frame:
		return
	_targets_frame = frame
	_targets.clear()
	for node in get_tree().get_nodes_in_group("creatures"):
		if not node is Creature or not node.is_grounded() or node.get_viewport() != _map.get_viewport() or not _map.get_parent().is_ancestor_of(node):
			continue
		var id := _map.regions_controller.region_id_at(node.global_position)
		var species: CreatureSpecies = node.species_data()
		if id <= 0 or species == null:
			continue
		var targets: PackedFloat64Array = _targets.get(id,PackedFloat64Array([0,0,0,0,0]))
		var profile: Dictionary = species.terrain_targets(node.sex == Creature.SEX.FEMALE)
		for kind: int in KINDS:
			targets[kind] = maxf(targets[kind],clampf(float(profile.get(KINDS[kind],0.0))/100.0,0.0,1.0))
		_targets[id] = targets

func _remaining(id: int, kind: int) -> float:
	_refresh_targets()
	var totals: PackedFloat64Array = _totals.get(id,PackedFloat64Array([0,0,0,0,0,0]))
	var targets: PackedFloat64Array = _targets.get(id,PackedFloat64Array([0,0,0,0,0]))
	var remaining := maxf(0.0,totals[0]*targets[kind]-totals[kind+1])
	return remaining if remaining > _extent.x*_extent.y/255.0 else 0.0

func needs_terrain(actor: Creature, kind: int) -> bool:
	if not is_instance_valid(actor) or kind not in KINDS or not _sync():
		return false
	var id := _map.regions_controller.region_id_at(actor.global_position)
	return id > 0 and _remaining(id,kind) > 0.000001

func terrain_status(actor: Creature) -> Dictionary:
	var result := {"ready":false,"region_id":0,"dry_area":0.0,"fulfillment":1.0,"requirements":[]}
	if not is_instance_valid(actor) or actor.species_data() == null or not actor.is_grounded() or not _sync():
		return result
	var id := _map.regions_controller.region_id_at(actor.global_position)
	if id <= 0:
		return result
	_refresh_targets()
	var totals: PackedFloat64Array = _totals.get(id,PackedFloat64Array([0,0,0,0,0,0]))
	var targets: PackedFloat64Array = _targets.get(id,PackedFloat64Array([0,0,0,0,0]))
	var profile := actor.species_data().terrain_targets(actor.sex == Creature.SEX.FEMALE)
	result.ready = true
	result.region_id = id
	result.dry_area = maxf(0.0,totals[0])
	for kind: int in KINDS:
		if float(profile.get(KINDS[kind],0.0)) <= 0.0:
			continue
		var minimum := targets[kind]
		var coverage := clampf(totals[kind+1]/totals[0],0.0,1.0) if totals[0] > 0.000001 else 0.0
		var met := totals[0] > 0.000001 and minimum > 0.0 and _remaining(id,kind) <= 0.000001
		var fulfillment := 1.0 if met else (clampf(coverage/minimum,0.0,1.0) if minimum > 0.0 else 0.0)
		result.requirements.append({"kind":kind,"coverage":coverage*100.0,"minimum":minimum*100.0,"fulfillment":fulfillment,"met":met})
		result.fulfillment = minf(result.fulfillment,fulfillment)
	return result

func region_summary(id: int) -> Dictionary:
	if not _sync():
		return {"ready":false}
	var region := _map.regions_controller.region_by_id(id)
	if region == null:
		return {"ready":false}
	var totals: PackedFloat64Array = _totals.get(id,PackedFloat64Array([0,0,0,0,0,0]))
	var dry_area := maxf(0.0,totals[0])
	var coverage: Dictionary[int,float] = {}
	for kind: int in KINDS:
		coverage[kind] = clampf(totals[kind+1]/dry_area*100.0,0.0,100.0) if dry_area > 0.000001 else 0.0
	return {"ready":true,"id":id,"area":region.area,"dry_area":dry_area,"water_coverage":clampf((region.area-dry_area)/maxf(region.area,0.000001)*100.0,0.0,100.0),"coverage":coverage}

func _inside_region(point: Vector3, id: int) -> bool:
	return id > 0 and _map.regions_controller.region_id_at(point) == id and _map.terrain_controller.surface_position(point).y > _map.water_controller.global_position.y+0.015

func region_filter(actor: Creature) -> Callable:
	var reference: WeakRef = weakref(actor)
	return func(point: Vector3) -> bool:
		var current := reference.get_ref() as Creature
		return is_instance_valid(current) and _inside_region(point,_map.regions_controller.region_id_at(current.global_position))

func can_transform(actor: Creature, point: Vector3, kind: int) -> bool:
	return needs_terrain(actor,kind) and _inside_region(point,_map.regions_controller.region_id_at(actor.global_position)) and _map.terrain_controller.ground_weight(point,kind) < 0.985

func terrain_sites(actor: Creature, kind: int, transform: bool = true) -> PackedVector3Array:
	var result := PackedVector3Array()
	if not is_instance_valid(actor) or kind not in KINDS or not _sync() or not _map.navigation.has_current_paths():
		return result
	var id := _map.regions_controller.region_id_at(actor.global_position)
	if id <= 0 or (transform and not needs_terrain(actor,kind)):
		return result
	var key := "%d:%d:%d" % [id,kind,int(transform)]
	if not _sites.has(key):
		_build_site_cache(key,id,kind,transform)
	var cache: Dictionary = _sites[key]
	var cells: Array = cache.cells
	if cells.is_empty():
		return result
	var nearest_distance := INF
	var nearest_cell := -1
	var origin := _map.terrain_controller.to_local(actor.global_position)
	var origin_cell := (Vector2(origin.x,origin.z)+_map.terrain_controller.world_size*0.5)/_extent-Vector2(0.5,0.5)
	var nearby := _nearest_site_cells(cache,origin_cell)
	var selected := {}
	for entry: Vector2 in nearby:
		var cell := int(entry.y)
		if entry.x < nearest_distance or (entry.x == nearest_distance and cell < nearest_cell):
			nearest_distance = entry.x
			nearest_cell = cell
		selected[cell] = true
		result.append(_cell_position(cell))
	var nearest: int = cache.positions[nearest_cell].x
	var count := mini(cells.size(),64)
	for index in count:
		var offset := (nearest+floori(float(index)*cells.size()/count))%cells.size()
		var cell: int = cells[offset]
		if not selected.has(cell):
			selected[cell] = true
			result.append(_cell_position(cell))
	var points: Array[Vector3] = []
	points.assign(Array(result))
	points.sort_custom(func(first: Vector3,second: Vector3): return first.distance_squared_to(actor.global_position) < second.distance_squared_to(actor.global_position))
	return PackedVector3Array(points)

func _build_site_cache(key: String, id: int, kind: int, transform: bool) -> void:
	var cells: Array = []
	var positions: Array[Vector2i] = []
	positions.resize(_ids.size())
	positions.fill(Vector2i(-1,-1))
	var bucket_count := (_size+Vector2i.ONE*(SITE_BUCKET_SIZE-1))/SITE_BUCKET_SIZE
	var buckets: Array = []
	buckets.resize(bucket_count.x*bucket_count.y)
	for index in buckets.size():
		buckets[index] = []
	for index: int in _members.get(id,[]):
		if _dry[index] == 0:
			continue
		var color := _colors[index]
		var weight: float = maxf(0.0,1.0-color.r-color.g-color.b-color.a) if kind == 0 else color[kind-1]
		if (transform and weight >= 0.985) or (not transform and weight < 0.55):
			continue
		var bucket_index := ((index/_size.x)/SITE_BUCKET_SIZE)*bucket_count.x+(index%_size.x)/SITE_BUCKET_SIZE
		var bucket: Array = buckets[bucket_index]
		positions[index] = Vector2i(cells.size(),bucket.size())
		cells.append(index)
		bucket.append(index)
	_sites[key] = {"id":id,"kind":kind,"transform":transform,"cells":cells,"positions":positions,"buckets":buckets,"bucket_width":bucket_count.x}
	if not _site_profiles.has(id):
		_site_profiles[id] = []
	_site_profiles[id].append(key)

func _site_matches(index: int, kind: int, transform: bool) -> bool:
	if _dry[index] == 0:
		return false
	var color := _colors[index]
	var weight: float = maxf(0.0,1.0-color.r-color.g-color.b-color.a) if kind == 0 else color[kind-1]
	return weight < 0.985 if transform else weight >= 0.55

func _site_bucket(index: int) -> Vector2i:
	return Vector2i((index%_size.x)/SITE_BUCKET_SIZE,(index/_size.x)/SITE_BUCKET_SIZE)

func _insert_site(cache: Dictionary, index: int) -> void:
	var cells: Array = cache.cells
	var key := _site_bucket(index)
	var bucket: Array = cache.buckets[key.y*cache.bucket_width+key.x]
	cache.positions[index] = Vector2i(cells.size(),bucket.size())
	cells.append(index)
	bucket.append(index)

func _remove_site(cache: Dictionary, index: int) -> void:
	var offsets: Vector2i = cache.positions[index]
	var cells: Array = cache.cells
	var last: int = cells[-1]
	cells[offsets.x] = last
	cells.pop_back()
	if last != index:
		var position: Vector2i = cache.positions[last]
		position.x = offsets.x
		cache.positions[last] = position
	var key := _site_bucket(index)
	var bucket: Array = cache.buckets[key.y*cache.bucket_width+key.x]
	last = bucket[-1]
	bucket[offsets.y] = last
	bucket.pop_back()
	if last != index:
		var position: Vector2i = cache.positions[last]
		position.y = offsets.y
		cache.positions[last] = position
	cache.positions[index] = Vector2i(-1,-1)

func _refresh_site_cell(index: int, previous_id: int, id: int) -> void:
	for key: String in _site_profiles.get(previous_id,[]):
		_refresh_site_membership(_sites[key],index,id)
	if id != previous_id:
		for key: String in _site_profiles.get(id,[]):
			_refresh_site_membership(_sites[key],index,id)

func _refresh_site_membership(cache: Dictionary, index: int, id: int) -> void:
	var included: bool = cache.positions[index].x >= 0
	var eligible: bool = id == cache.id and _site_matches(index,cache.kind,cache.transform)
	if eligible and not included:
		_insert_site(cache,index)
	elif included and not eligible:
		_remove_site(cache,index)

func _nearest_site_cells(cache: Dictionary, origin: Vector2) -> Array[Vector2]:
	var nearby: Array[Vector2] = []
	var cells: Array = cache.cells
	if cells.is_empty():
		return nearby
	var bucket_count := (_size+Vector2i.ONE*(SITE_BUCKET_SIZE-1))/SITE_BUCKET_SIZE
	var center := Vector2i((origin/SITE_BUCKET_SIZE).floor()).clamp(Vector2i.ZERO,bucket_count-Vector2i.ONE)
	var maximum := maxi(maxi(center.x,center.y),maxi(bucket_count.x-1-center.x,bucket_count.y-1-center.y))
	for radius in maximum+1:
		var first := (center-Vector2i.ONE*radius).max(Vector2i.ZERO)
		var last := (center+Vector2i.ONE*radius).min(bucket_count-Vector2i.ONE)
		if radius == 0:
			_scan_site_bucket(cache,center,origin,nearby)
		else:
			for x in range(first.x,last.x+1):
				if center.y-radius >= 0:
					_scan_site_bucket(cache,Vector2i(x,center.y-radius),origin,nearby)
				if center.y+radius < bucket_count.y:
					_scan_site_bucket(cache,Vector2i(x,center.y+radius),origin,nearby)
			for y in range(maxi(0,center.y-radius+1),mini(bucket_count.y-1,center.y+radius-1)+1):
				if center.x-radius >= 0:
					_scan_site_bucket(cache,Vector2i(center.x-radius,y),origin,nearby)
				if center.x+radius < bucket_count.x:
					_scan_site_bucket(cache,Vector2i(center.x+radius,y),origin,nearby)
		if nearby.size() == mini(64,cells.size()) and nearby[0].x < _unvisited_site_distance(origin,first,last,bucket_count):
			break
	return nearby

func _scan_site_bucket(cache: Dictionary, key: Vector2i, origin: Vector2, nearby: Array[Vector2]) -> void:
	var bucket: Array = cache.buckets[key.y*cache.bucket_width+key.x]
	if bucket.is_empty():
		return
	var first := Vector2(key*SITE_BUCKET_SIZE)
	var last := Vector2((key*SITE_BUCKET_SIZE+Vector2i.ONE*(SITE_BUCKET_SIZE-1)).min(_size-Vector2i.ONE))
	if nearby.size() == 64 and nearby[0].x < origin.distance_squared_to(origin.clamp(first,last)):
		return
	for cell: int in bucket:
		var distance := Vector2(cell%_size.x,cell/_size.x).distance_squared_to(origin)
		_offer_nearest(nearby,Vector2(distance,cell))

func _unvisited_site_distance(origin: Vector2, first: Vector2i, last: Vector2i, count: Vector2i) -> float:
	var distance := INF
	if first.x > 0:
		distance = minf(distance,pow(maxf(0.0,origin.x-(first.x*SITE_BUCKET_SIZE-1)),2.0))
	if last.x+1 < count.x:
		distance = minf(distance,pow(maxf(0.0,(last.x+1)*SITE_BUCKET_SIZE-origin.x),2.0))
	if first.y > 0:
		distance = minf(distance,pow(maxf(0.0,origin.y-(first.y*SITE_BUCKET_SIZE-1)),2.0))
	if last.y+1 < count.y:
		distance = minf(distance,pow(maxf(0.0,(last.y+1)*SITE_BUCKET_SIZE-origin.y),2.0))
	return distance

func _site_farther(first: Vector2, second: Vector2) -> bool:
	return first.x > second.x or (first.x == second.x and first.y > second.y)

func _offer_nearest(heap: Array[Vector2], value: Vector2) -> void:
	if heap.size() < 64:
		heap.append(value)
		var index := heap.size()-1
		while index > 0:
			var parent := (index-1)/2
			if not _site_farther(heap[index],heap[parent]):
				break
			var previous := heap[parent]
			heap[parent] = heap[index]
			heap[index] = previous
			index = parent
		return
	if not _site_farther(heap[0],value):
		return
	heap[0] = value
	var index := 0
	while index*2+1 < heap.size():
		var child := index*2+1
		if child+1 < heap.size() and _site_farther(heap[child+1],heap[child]):
			child += 1
		if not _site_farther(heap[child],heap[index]):
			break
		var previous := heap[index]
		heap[index] = heap[child]
		heap[child] = previous
		index = child

func apply_terrain(actor: Creature, point: Vector3, kind: int, radius: float) -> float:
	if radius <= 0.0 or not can_transform(actor,point,kind):
		return 0.0
	var id := _map.regions_controller.region_id_at(actor.global_position)
	var limit := _remaining(id,kind)
	var filter := func(sample: Vector3) -> bool: return _inside_region(sample,id)
	var changed := 0.0
	if kind == TerrainController.GROUND_TYPE.ROCK:
		changed = _map.terrain_controller.rocky_impact(point,radius,actor.species_data().impact_strength,filter,limit)
	else:
		changed = _map.terrain_controller.transform_ground(point,radius,kind,filter,limit)
	_sync()
	return changed
