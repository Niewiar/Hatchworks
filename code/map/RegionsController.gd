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

func initialize(terrain: TerrainController, fences: FenceController, water: WaterController) -> void:
	_terrain = terrain
	_fences = fences
	_water = water
	_grid_size = Vector2i(ceil(terrain.world_size / cell_size))
	_cell_extent = terrain.world_size / Vector2(_grid_size)
	_fences.network_changed.connect(_queue_rebuild)
	_terrain.terrain_changed.connect(_on_terrain_changed)
	_terrain.height_changed.connect(_on_water_changed)
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

func _on_terrain_changed() -> void:
	_coverage_dirty = true

func _on_water_changed() -> void:
	_water_coverage_dirty = true

func _refresh_water_coverage() -> void:
	if not _water_coverage_dirty or _rebuild_pending:
		return
	var flooded_cells := PackedInt32Array()
	flooded_cells.resize(_regions.size() + 1)
	var normal := _terrain.global_basis.y.normalized()
	for y in _grid_size.y:
		for x in _grid_size.x:
			var id := _region_ids[y * _grid_size.x + x]
			if id <= 0:
				continue
			var point := (Vector2(x, y) + Vector2(0.5, 0.5)) * _cell_extent - _terrain.world_size * 0.5
			var ground := _terrain.surface_position(_terrain.to_global(Vector3(point.x, 0, point.y)))
			if (ground - _water.global_position).dot(normal) < 0.0:
				flooded_cells[id] += 1
	var sample_area := _cell_extent.x * _cell_extent.y
	for region: Region in _regions.values():
		region.water_area = flooded_cells[region.id] * sample_area
	_water_coverage_dirty = false

func _refresh_coverage() -> void:
	if _rebuild_pending:
		return
	_refresh_water_coverage()
	if not _coverage_dirty:
		return
	var samples := _terrain.sample_coverage(_grid_size).get_data()
	var totals: Dictionary[int, PackedFloat64Array] = {}
	for region: Region in _regions.values():
		totals[region.id] = PackedFloat64Array([0, 0, 0, 0, 0])
	for index in _region_ids.size():
		var id := _region_ids[index]
		if id == 0:
			continue
		var offset := index * 4
		var dirt := float(samples[offset]) / 255.0
		var sand := float(samples[offset + 2]) / 255.0
		var rock := float(samples[offset + 3]) / 255.0
		var grass := maxf(0, 1.0 - dirt - sand - rock)
		var weights := totals[id]
		weights[0] += grass
		weights[1] += dirt
		weights[3] += sand
		weights[4] += rock
		totals[id] = weights
	for region: Region in _regions.values():
		var weights := totals[region.id]
		var total := 0.0
		for value in weights:
			total += value
		for index in 5:
			region.terrain_coverage[index] = weights[index] / maxf(total, 0.0001) * 100.0
	_coverage_dirty = false

func region_id_at(world_position: Vector3) -> int:
	if _rebuild_pending or not _terrain.contains_world_point(world_position):
		return 0
	var cell := Vector2i(_world_to_grid(world_position).floor()).clamp(Vector2i.ZERO,_grid_size-Vector2i.ONE)
	return _region_ids[cell.y*_grid_size.x+cell.x]
