class_name EnvironmentController
extends Node

@export var enabled := true
@export_range(0.25, 1.0, 0.25) var cell_size := 0.5
@export_range(0.1, 2.0, 0.1) var update_interval := 0.5
var wetting_speed := 0.45
var drying_speed := 0.07
var ground_change_speed := 0.3

var _terrain: TerrainController
var _water: WaterController
var _size := Vector2i.ZERO
var _extent := Vector2.ZERO
var _height := PackedFloat32Array()
var _slope := PackedFloat32Array()
var _moisture := PackedFloat32Array()
var _target_moisture := PackedFloat32Array()
var _shade := PackedFloat32Array()
var _distance := PackedFloat32Array()
var _sediment := PackedFloat32Array()
var _variation := PackedFloat32Array()
var _cover := PackedColorArray()
var _image: Image
var _work_height := PackedFloat32Array()
var _work_slope := PackedFloat32Array()
var _work_distance := PackedFloat32Array()
var _work_moisture := PackedFloat32Array()
var _field_stage := -1
var _field_cursor := 0
var _simulation_cursor := -1
var _simulation_blend := 0.0
var _simulation_elapsed := 0.0
var _cycle_settled := true
var _revision := 0
var _simulation_revision := 0
var _elapsed := 0.0
var _fields_dirty := false
var _settled := true

func initialize(terrain: TerrainController, water: WaterController) -> void:
	_terrain = terrain
	_water = water
	set_process(enabled)
	if not enabled:
		return
	_size = Vector2i(ceil(terrain.world_size / cell_size))
	_extent = terrain.world_size / Vector2(_size)
	var count := _size.x * _size.y
	_height.resize(count)
	_slope.resize(count)
	_moisture.resize(count)
	_target_moisture.resize(count)
	_shade.resize(count)
	_distance.resize(count)
	_sediment.resize(count)
	_variation.resize(count)
	_cover.resize(count)
	_work_height.resize(count)
	_work_slope.resize(count)
	_work_distance.resize(count)
	_work_moisture.resize(count)
	_image = Image.create(_size.x,_size.y,false,Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = terrain.world_seed + 8191
	noise.frequency = 0.12
	noise.fractal_octaves = 2
	for y in _size.y:
		for x in _size.x:
			var index := y * _size.x + x
			var point := (Vector2(x,y)+Vector2(0.5,0.5))*_extent-terrain.world_size*0.5
			_sediment[index] = noise.get_noise_2dv(point)*0.5+0.5
			_variation[index] = noise.get_noise_2dv(point*2.7+Vector2(133,71))*0.5+0.5
	_read_ground()
	_moisture = _target_moisture.duplicate()
	for index in count:
		_cover[index] = _ground_target(index)
	_upload_ground()
	terrain.height_changed.connect(_on_ground_changed)
	water.water_level_changed.connect(_on_ground_changed)

func conditions_at(point: Vector2) -> Vector4:
	var cell := Vector2i(((point+_terrain.world_size*0.5)/_extent).floor()).clamp(Vector2i.ZERO,_size-Vector2i.ONE)
	var index := cell.y*_size.x+cell.x
	return Vector4(_moisture[index],_shade[index],_slope[index],_water.water_level-_height[index])

func set_canopies(canopies: Array[Vector4]) -> void:
	_shade.fill(0.0)
	for canopy in canopies:
		var center := (Vector2(canopy.x,canopy.y)+_terrain.world_size*0.5)/_extent
		var padding := Vector2.ONE*canopy.z/_extent
		var first := Vector2i((center-padding).floor()).max(Vector2i.ZERO)
		var last := Vector2i((center+padding).ceil()).min(_size-Vector2i.ONE)
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var distance := ((Vector2(x,y)+Vector2(0.5,0.5)-center)*_extent).length()
				var shade := (1.0-smoothstep(canopy.z*0.35,canopy.z,distance))*canopy.w
				var index := y*_size.x+x
				_shade[index] = maxf(_shade[index],shade)
	_revision += 1
	_settled = false

func _on_ground_changed() -> void:
	_fields_dirty = true
	_settled = false

func _read_ground() -> void:
	var count := _size.x*_size.y
	_sample_ground(0,count)
	_spread_water(0,count,false)
	_spread_water(0,count,true)
	_finish_ground(0,count)
	_commit_ground()
	_fields_dirty = false

func _sample_ground(first: int, last: int) -> void:
	for index in range(first,last):
		var point := (Vector2(index%_size.x,index/_size.x)+Vector2(0.5,0.5))*_extent-_terrain.world_size*0.5
		var world := _terrain.to_global(Vector3(point.x,0,point.y))
		_work_height[index] = _terrain.to_local(_terrain.surface_position(world)).y
		_work_distance[index] = 0.0 if _work_height[index] < _water.water_level else INF

func _spread_water(first: int, last: int, reverse: bool) -> void:
	var diagonal := _extent.length()
	var direction := -1 if reverse else 1
	for offset in range(first,last):
		var index := _size.x*_size.y-1-offset if reverse else offset
		var x := index%_size.x
		var y := index/_size.x
		if x-direction >= 0 and x-direction < _size.x:
			_work_distance[index] = minf(_work_distance[index],_work_distance[index-direction]+_extent.x)
		if y-direction >= 0 and y-direction < _size.y:
			var row := index-direction*_size.x
			_work_distance[index] = minf(_work_distance[index],_work_distance[row]+_extent.y)
			if x > 0:
				_work_distance[index] = minf(_work_distance[index],_work_distance[row-1]+diagonal)
			if x+1 < _size.x:
				_work_distance[index] = minf(_work_distance[index],_work_distance[row+1]+diagonal)

func _finish_ground(first: int, last: int) -> void:
	for index in range(first,last):
		var x := index%_size.x
		var y := index/_size.x
		var left := maxi(x-1,0)
		var right := mini(x+1,_size.x-1)
		var back := maxi(y-1,0)
		var front := mini(y+1,_size.y-1)
		var dx := (_work_height[y*_size.x+right]-_work_height[y*_size.x+left])/maxf((right-left)*_extent.x,0.001)
		var dz := (_work_height[front*_size.x+x]-_work_height[back*_size.x+x])/maxf((front-back)*_extent.y,0.001)
		_work_slope[index] = Vector2(dx,dz).length()
		var shore := 1.0-smoothstep(0.0,4.0,_work_distance[index])
		var elevation := exp(-maxf(0.0,_work_height[index]-_water.water_level)*0.65)
		_work_moisture[index] = clampf(0.18+_variation[index]*0.16+shore*elevation*0.77,0.0,1.0)

func _commit_ground() -> void:
	_height = _work_height.duplicate()
	_slope = _work_slope.duplicate()
	_distance = _work_distance.duplicate()
	_target_moisture = _work_moisture.duplicate()
	_field_stage = -1
	_revision += 1
	_settled = false

func _refresh_ground_slice() -> void:
	if _field_stage < 0:
		if not _fields_dirty:
			return
		_field_stage = 0
		_field_cursor = 0
		_fields_dirty = false
	var deadline := Time.get_ticks_usec()+1000
	var count := _size.x*_size.y
	while Time.get_ticks_usec() < deadline:
		var last := mini(_field_cursor+128,count)
		match _field_stage:
			0:
				_sample_ground(_field_cursor,last)
			1:
				_spread_water(_field_cursor,last,false)
			2:
				_spread_water(_field_cursor,last,true)
			3:
				_finish_ground(_field_cursor,last)
		_field_cursor = last
		if _field_cursor == count:
			_field_cursor = 0
			_field_stage += 1
			if _field_stage == 4:
				_commit_ground()
				return

func _ground_target(index: int) -> Color:
	var depth := _water.water_level-_height[index]
	var shore := (1.0-smoothstep(0.0,1.5,_distance[index]))*(1.0-smoothstep(0.18,0.55,absf(depth)))
	shore *= 1.0-smoothstep(0.22,0.55,_slope[index])
	var sand := shore*smoothstep(0.43,0.64,_sediment[index])*0.92
	var rock := smoothstep(0.4,0.72,_slope[index])*0.88
	var dirt := shore*(1.0-sand)*0.45+_shade[index]*0.22+smoothstep(0.63,0.82,_variation[index])*0.15
	dirt = maxf(dirt,smoothstep(-0.02,0.2,depth)*0.85*(1.0-sand))
	var moss := smoothstep(0.36,0.78,_moisture[index])*(0.25+_shade[index]*0.9)*0.9
	moss *= (1.0-sand)*(1.0-rock)*(1.0-smoothstep(-0.02,0.12,depth))
	var total := dirt+moss+sand+rock
	var divisor := maxf(1.0,total/0.98)
	return Color(dirt,moss,sand,rock)/divisor

func _process(delta: float) -> void:
	_refresh_ground_slice()
	_elapsed += delta
	if _simulation_cursor < 0 and _elapsed >= update_interval:
		_simulation_elapsed = minf(_elapsed,2.0)
		_elapsed = 0.0
		if not _settled:
			_simulation_cursor = 0
			_simulation_blend = 1.0-exp(-ground_change_speed*_simulation_elapsed)
			_simulation_revision = _revision
			_cycle_settled = true
	if _simulation_cursor < 0:
		return
	var deadline := Time.get_ticks_usec()+1000
	while Time.get_ticks_usec() < deadline:
		var last := mini(_simulation_cursor+128,_cover.size())
		for index in range(_simulation_cursor,last):
			var target := clampf(_target_moisture[index]+_shade[index]*0.08,0.0,1.0)
			var rate := wetting_speed if target > _moisture[index] else drying_speed
			_moisture[index] = move_toward(_moisture[index],target,rate*_simulation_elapsed)
			var ground := _ground_target(index)
			_cover[index] = _cover[index].lerp(ground,_simulation_blend)
			if absf(target-_moisture[index]) > 0.001 or absf(_cover[index].r-ground.r) > 0.002 or absf(_cover[index].g-ground.g) > 0.002 or absf(_cover[index].b-ground.b) > 0.002 or absf(_cover[index].a-ground.a) > 0.002:
				_cycle_settled = false
		_simulation_cursor = last
		if _simulation_cursor == _cover.size():
			_simulation_cursor = -1
			_settled = _cycle_settled and _simulation_revision == _revision and not _fields_dirty and _field_stage < 0
			_upload_ground()
			return

func _upload_ground() -> void:
	for index in _cover.size():
		_image.set_pixel(index%_size.x,index/_size.x,_cover[index])
	_terrain.set_natural_coverage(_image)
