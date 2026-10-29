class_name EnvironmentController
extends Node

@export var enabled := true
@export_range(0.25, 1.0, 0.25) var cell_size := 0.5

var _terrain: TerrainController
var _water: WaterController
var _size := Vector2i.ZERO
var _extent := Vector2.ZERO
var _image: Image
var _noise := FastNoiseLite.new()
var _cursor := -1
var _dirty := false

func initialize(terrain: TerrainController, water: WaterController) -> void:
	_terrain = terrain
	_water = water
	set_process(false)
	if not enabled:
		return
	_size = Vector2i(ceil(terrain.world_size/cell_size))
	_extent = terrain.world_size/Vector2(_size)
	_image = Image.create(_size.x,_size.y,false,Image.FORMAT_RGBA8)
	_noise.seed = terrain.world_seed+8191
	_noise.frequency = 0.12
	_noise.fractal_octaves = 2
	for index in _size.x*_size.y:
		_sample(index)
	_terrain.set_natural_coverage(_image)
	terrain.height_changed.connect(_queue_refresh)
	water.water_level_changed.connect(_queue_refresh)

func conditions_at(point: Vector2) -> Vector4:
	var world := _terrain.to_global(Vector3(point.x,0,point.y))
	var height := _terrain.to_local(_terrain.surface_position(world)).y
	return Vector4(0,0,_terrain.slope_at(world),_water.water_level-height)

func _sample(index: int) -> void:
	var point := (Vector2(index%_size.x,index/_size.x)+Vector2(0.5,0.5))*_extent-_terrain.world_size*0.5
	var conditions := conditions_at(point)
	var sediment := _noise.get_noise_2dv(point)*0.5+0.5
	var shore := (1.0-smoothstep(0.06,0.5,absf(conditions.w)))*(1.0-smoothstep(0.3,0.7,conditions.z))
	var sand := shore*smoothstep(0.4,0.68,sediment)*0.85
	var rock := smoothstep(0.4,0.72,conditions.z)*0.88
	var dirt := shore*(1.0-sand)*0.24+smoothstep(0.05,0.35,conditions.w)*0.65*(1.0-sand)
	var divisor := maxf(1.0,(sand+rock+dirt)/0.98)
	_image.set_pixel(index%_size.x,index/_size.x,Color(dirt,0,sand,rock)/divisor)

func _queue_refresh() -> void:
	_dirty = true
	set_process(true)

func _process(_delta: float) -> void:
	if _cursor < 0:
		if not _dirty:
			set_process(false)
			return
		_cursor = 0
		_dirty = false
	var deadline := Time.get_ticks_usec()+1500
	while _cursor < _size.x*_size.y and Time.get_ticks_usec() < deadline:
		_sample(_cursor)
		_cursor += 1
	if _cursor == _size.x*_size.y:
		_cursor = -1
		_terrain.set_natural_coverage(_image)
