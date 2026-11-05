class_name RegionsController
extends Node

signal regions_changed

@export_range(0.125, 1.0, 0.125) var cell_size := 0.25

var _terrain: TerrainController
var _fences: FenceController
var _water: WaterController
var _grid_size := Vector2i.ZERO
var _cell_extent := Vector2.ZERO
var _region_ids := PackedInt32Array()
var _regions: Dictionary[int, Region] = {}
var _rebuild_pending := false
var _coverage_dirty := true
var _water_coverage_dirty := true
var _coverage_full_dirty := true
var _water_full_dirty := true
var _coverage_dirty_bounds := Rect2()
var _water_dirty_bounds := Rect2()
var _ground_area_pending := false
var _height_area_pending := false
var _coverage_samples := PackedByteArray()
var _coverage_totals: Dictionary[int,PackedFloat64Array] = {}
var _natural_coverage_source: Image
var _flooded_cells := PackedByteArray()
var _flooded_counts := PackedInt32Array()

func initialize(terrain: TerrainController, fences: FenceController, water: WaterController) -> void:
	_terrain = terrain
	_fences = fences
	_water = water
	_natural_coverage_source = terrain._natural_image
	_grid_size = Vector2i(ceil(terrain.world_size / cell_size))
	_cell_extent = terrain.world_size / Vector2(_grid_size)
	_fences.network_changed.connect(_queue_rebuild)
	_terrain.ground_area_changed.connect(_on_ground_area_changed)
	_terrain.terrain_changed.connect(_on_terrain_changed)
	_terrain.height_area_changed.connect(_on_height_area_changed)
	_terrain.height_changed.connect(_on_height_changed)
	_water.water_level_changed.connect(_on_water_changed)
	_queue_rebuild()

func get_region_at(world_position: Vector3) -> Region:
	if _rebuild_pending or not _terrain.contains_world_point(world_position):
		return null
	var cell := Vector2i(_world_to_grid(world_position).floor())
	if cell.x < 0 or cell.y < 0 or cell.x >= _grid_size.x or cell.y >= _grid_size.y:
		return null
	_refresh_coverage()
	return _regions.get(_region_ids[cell.y * _grid_size.x + cell.x]) as Region

func _world_to_grid(world_position: Vector3) -> Vector2:
	var local := _terrain.to_local(world_position)
	return (Vector2(local.x, local.z) + _terrain.world_size * 0.5) / _cell_extent

func _queue_rebuild() -> void:
	if _rebuild_pending:
		return
	_rebuild_pending = true
	_rebuild.call_deferred()

func _rebuild() -> void:
	var count := _grid_size.x * _grid_size.y
	_region_ids.resize(count)
	_region_ids.fill(-1)
	_regions.clear()
	for span: FenceSpanState in _fences.get_spans():
		var first := _world_to_grid(_fences.map_to_world(_fences.get_post(span.start_post_id).position))
		var last := _world_to_grid(_fences.map_to_world(_fences.get_post(span.end_post_id).position))
		var radius := span.data.thickness * 0.5 / _fences.pixels_per_unit
		_block_segment(first, last, radius)
	for post: FencePostState in _fences.get_posts():
		var center := _world_to_grid(_fences.map_to_world(post.position))
		var radius := maxf(post.data.post_width, post.data.thickness * 1.15) * 0.5 / _fences.pixels_per_unit
		_block_segment(center, center, radius)
	var queue := PackedInt32Array()
	queue.resize(count)
	for seed in count:
		if _region_ids[seed] != -1:
			continue
		var region := Region.new()
		region.id = _regions.size() + 1
		_regions[region.id] = region
		var head := 0
		var tail := 1
		queue[0] = seed
		_region_ids[seed] = region.id
		while head < tail:
			var index := queue[head]
			head += 1
			region.cell_count += 1
			region.center += Vector3(index%_grid_size.x,0,index/_grid_size.x)
			var x := index % _grid_size.x
			var y := index / _grid_size.x
			if x == 0 or y == 0 or x == _grid_size.x - 1 or y == _grid_size.y - 1:
				region.touches_map_edge = true
			if x > 0 and _region_ids[index - 1] == -1:
				_region_ids[index - 1] = region.id
				queue[tail] = index - 1
				tail += 1
			if x + 1 < _grid_size.x and _region_ids[index + 1] == -1:
				_region_ids[index + 1] = region.id
				queue[tail] = index + 1
				tail += 1
			if y > 0 and _region_ids[index - _grid_size.x] == -1:
				_region_ids[index - _grid_size.x] = region.id
				queue[tail] = index - _grid_size.x
				tail += 1
			if y + 1 < _grid_size.y and _region_ids[index + _grid_size.x] == -1:
				_region_ids[index + _grid_size.x] = region.id
				queue[tail] = index + _grid_size.x
				tail += 1
		region.area = region.cell_count * _cell_extent.x * _cell_extent.y
		var center := Vector2(region.center.x,region.center.z)/region.cell_count
		center = (center+Vector2(0.5,0.5))*_cell_extent-_terrain.world_size*0.5
		region.center = _terrain.surface_position(_terrain.to_global(Vector3(center.x,0,center.y)))
	_coverage_dirty = true
	_water_coverage_dirty = true
	_coverage_full_dirty = true
	_water_full_dirty = true
	_coverage_dirty_bounds = Rect2()
	_water_dirty_bounds = Rect2()
	_rebuild_pending = false
	regions_changed.emit()

func _block_segment(first: Vector2, last: Vector2, radius: float) -> void:
	var padding := Vector2(radius, radius) / _cell_extent + Vector2.ONE
	var minimum := Vector2i((first.min(last) - padding).floor()).max(Vector2i.ZERO)
	var maximum := Vector2i((first.max(last) + padding).ceil()).min(_grid_size - Vector2i.ONE)
	var first_world := first * _cell_extent
	var last_world := last * _cell_extent
	var reach := radius + _cell_extent.length() * 0.5
	for y in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var center := (Vector2(x, y) + Vector2(0.5, 0.5)) * _cell_extent
			if center.distance_to(Geometry2D.get_closest_point_to_segment(center, first_world, last_world)) <= reach:
				_region_ids[y * _grid_size.x + x] = 0

func _on_ground_area_changed(bounds: Rect2) -> void:
	_ground_area_pending = true
	_coverage_dirty = true
	if not bounds.has_area():
		_coverage_full_dirty = true
		return
	_coverage_dirty_bounds = _coverage_dirty_bounds.merge(bounds) if _coverage_dirty_bounds.has_area() else bounds

func _on_terrain_changed() -> void:
	if _natural_coverage_source != _terrain._natural_image:
		_natural_coverage_source = _terrain._natural_image
		_coverage_dirty = true
		_coverage_full_dirty = true
	if _ground_area_pending:
		_ground_area_pending = false
		return
	_coverage_dirty = true
	_coverage_full_dirty = true

func _on_height_area_changed(bounds: Rect2) -> void:
	_height_area_pending = true
	_water_coverage_dirty = true
	if not bounds.has_area():
		_water_full_dirty = true
		return
	_water_dirty_bounds = _water_dirty_bounds.merge(bounds) if _water_dirty_bounds.has_area() else bounds

func _on_height_changed() -> void:
	if _height_area_pending:
		_height_area_pending = false
		return
	_water_coverage_dirty = true
	_water_full_dirty = true

func _on_water_changed() -> void:
	_water_coverage_dirty = true
	_water_full_dirty = true

func _sample_bounds(bounds: Rect2, padding: float) -> Rect2i:
	var half := _terrain.world_size*0.5
	var first := Vector2i(((bounds.position+half-Vector2.ONE*padding)/_cell_extent).floor()).clamp(Vector2i.ZERO,_grid_size)
	var last := Vector2i(((bounds.end+half+Vector2.ONE*padding)/_cell_extent).ceil()).clamp(Vector2i.ZERO,_grid_size)
	return Rect2i(first,(last-first).max(Vector2i.ZERO))

func _refresh_water_coverage() -> void:
	if not _water_coverage_dirty or _rebuild_pending:
		return
	var full := _water_full_dirty or _flooded_cells.size() != _region_ids.size() or _flooded_counts.size() != _regions.size()+1
	var bounds := Rect2i(Vector2i.ZERO,_grid_size) if full else _sample_bounds(_water_dirty_bounds,_terrain.height_spacing)
	if full:
		_flooded_cells.resize(_region_ids.size())
		_flooded_cells.fill(0)
		_flooded_counts.resize(_regions.size()+1)
		_flooded_counts.fill(0)
	var normal := _terrain.global_basis.y.normalized()
	var changed: Dictionary[int,bool] = {}
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var index := y*_grid_size.x+x
			var id := _region_ids[index]
			if id <= 0:
				continue
			var point := (Vector2(x,y)+Vector2(0.5,0.5))*_cell_extent-_terrain.world_size*0.5
			var ground := _terrain.surface_position(_terrain.to_global(Vector3(point.x,0,point.y)))
			var flooded := int((ground-_water.global_position).dot(normal) < 0.0)
			_flooded_counts[id] += flooded-int(_flooded_cells[index])
			_flooded_cells[index] = flooded
			changed[id] = true
	var sample_area := _cell_extent.x*_cell_extent.y
	for id: int in changed:
		_regions[id].water_area = _flooded_counts[id]*sample_area
	_water_coverage_dirty = false
	_water_full_dirty = false
	_water_dirty_bounds = Rect2()

func _can_sample_window() -> bool:
	if _terrain._natural_image != null:
		return false
	var dimensions := _terrain._ground_image.get_size()
	if dimensions.x%_grid_size.x != 0 or dimensions.y%_grid_size.y != 0:
		return false
	var ratio := dimensions/_grid_size
	return ratio.x > 0 and ratio.y > 0 and (ratio.x & (ratio.x-1)) == 0 and (ratio.y & (ratio.y-1)) == 0

func _refresh_coverage() -> void:
	if _rebuild_pending:
		return
	_refresh_water_coverage()
	if not _coverage_dirty:
		return
	var full := _coverage_full_dirty or _coverage_samples.size() != _region_ids.size()*4 or _coverage_totals.size() != _regions.size()
	var bounds := Rect2i(Vector2i.ZERO,_grid_size) if full else _sample_bounds(_coverage_dirty_bounds,maxf(_cell_extent.x,_cell_extent.y))
	if not bounds.has_area():
		_coverage_dirty = false
		_coverage_dirty_bounds = Rect2()
		return
	var samples: PackedByteArray
	if not full and _can_sample_window():
		samples = _terrain.sample_coverage_window(_grid_size,bounds).get_data()
	else:
		var image := _terrain.sample_coverage(_grid_size)
		samples = image.get_data() if full else image.get_region(bounds).get_data()
	if full:
		_coverage_samples = samples
		_coverage_totals.clear()
		for region: Region in _regions.values():
			_coverage_totals[region.id] = PackedFloat64Array([0,0,0,0,0])
	var changed: Dictionary[int,bool] = {}
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var index := y*_grid_size.x+x
			var id := _region_ids[index]
			if id <= 0:
				continue
			var offset := ((y-bounds.position.y)*bounds.size.x+x-bounds.position.x)*4
			var dirt := float(samples[offset])/255.0
			var sand := float(samples[offset+2])/255.0
			var rock := float(samples[offset+3])/255.0
			var grass := maxf(0.0,1.0-dirt-sand-rock)
			var weights: PackedFloat64Array = _coverage_totals[id]
			if not full:
				var previous_offset := index*4
				var previous_dirt := float(_coverage_samples[previous_offset])/255.0
				var previous_sand := float(_coverage_samples[previous_offset+2])/255.0
				var previous_rock := float(_coverage_samples[previous_offset+3])/255.0
				weights[0] -= maxf(0.0,1.0-previous_dirt-previous_sand-previous_rock)
				weights[1] -= previous_dirt
				weights[3] -= previous_sand
				weights[4] -= previous_rock
				for channel in 4:
					_coverage_samples[previous_offset+channel] = samples[offset+channel]
			weights[0] += grass
			weights[1] += dirt
			weights[3] += sand
			weights[4] += rock
			_coverage_totals[id] = weights
			changed[id] = true
	for id: int in changed:
		var region: Region = _regions[id]
		var weights: PackedFloat64Array = _coverage_totals[id]
		var total := 0.0
		for value in weights:
			total += value
		for index in 5:
			region.terrain_coverage[index] = weights[index]/maxf(total,0.0001)*100.0
	_coverage_dirty = false
	_coverage_full_dirty = false
	_coverage_dirty_bounds = Rect2()

func region_id_at(world_position: Vector3) -> int:
	if _rebuild_pending or not _terrain.contains_world_point(world_position):
		return 0
	var cell := Vector2i(_world_to_grid(world_position).floor()).clamp(Vector2i.ZERO,_grid_size-Vector2i.ONE)
	return _region_ids[cell.y*_grid_size.x+cell.x]

func layout_snapshot() -> Dictionary:
	return {"ready":not _rebuild_pending,"size":_grid_size,"ids":_region_ids.duplicate(),"regions":_regions.values()}

func region_by_id(id: int) -> Region:
	return null if _rebuild_pending else _regions.get(id) as Region
