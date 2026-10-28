class_name MapManager
extends Node3D

@export var database: GameDatabase
@export var map_size := Vector2i(512, 512)
@export var pixels_per_unit := 32.0
@export var camera_controller: MapCameraController

@onready var inventory: ResourceInventory = $Inventory
@onready var harvest_controller: HarvestController = $Harvest
@onready var rock_controller: RockController = $Rocks
@onready var terrain_controller: TerrainController = $Terrain
@onready var water_controller: WaterController = $Water
@onready var environment_controller: EnvironmentController = $Environment
@onready var vegetation_controller: VegetationController = $Vegetation
@onready var brush_controller: BrushController = $Brush
@onready var fances_controller: FenceController = %Fances
@onready var regions_controller: RegionsController = $Regions

enum MODE { NONE, PAINT, FANCE, REGIONS, SCULPT, HARVEST }

const CREATURE_PICK_MASK := 7

var _mode: MODE = MODE.NONE
var _painting_active := false
var _sculpting_active := false
var _harvesting_active := false
var _collect_elapsed := 0.0
var _panning := false
var _rotating := false
var _last_pointer := Vector2.ZERO
var selected_material := 0
var selected_sculpt_tool: TerrainController.SCULPT_TOOL = TerrainController.SCULPT_TOOL.RAISE
var _held_creature: Creature
var _grab_requested := false
var _grab_screen_offset := Vector2.ZERO
var _held_plane_height := 0.0

func _ready() -> void:
	_apply_database()
	if not terrain_controller.initialize(map_size, pixels_per_unit):
		return
	water_controller.initialize(terrain_controller)
	fances_controller.configure_world(pixels_per_unit, Rect2(-Vector2(map_size) * 0.5, Vector2(map_size)))
	fances_controller.configure_surface(terrain_controller)
	fances_controller.configure_inventory(inventory)
	brush_controller.configure_surface()
	environment_controller.initialize(terrain_controller, water_controller)
	vegetation_controller.initialize(terrain_controller, environment_controller)
	rock_controller.initialize(terrain_controller,environment_controller,vegetation_controller)
	harvest_controller.initialize(terrain_controller,vegetation_controller,rock_controller,inventory)
	regions_controller.initialize(terrain_controller, fances_controller, water_controller)
	regions_controller.regions_changed.connect(_update_region_hover)
	if camera_controller != null:
		camera_controller.configure(terrain_controller.world_size)
	InputManager.on_lmb.connect(_on_lmb)
	InputManager.on_mmb.connect(_on_mmb)
	InputManager.on_rmb.connect(_on_rmb)
	InputManager.on_mouse_move.connect(_on_mouse_move)
	InputManager.on_mouse_scroll.connect(_on_mouse_scroll)
	get_window().focus_exited.connect(_on_focus_exited)
	_last_pointer = get_viewport().get_mouse_position()

func _apply_database() -> void:
	if database == null:
		database = load(GameDatabase.DEFAULT_PATH) as GameDatabase
	inventory.configure(database.resources)
	vegetation_controller.species = database.flora
	rock_controller.definitions = database.deposits
	var balance := database.world
	for property in ["starting_height_variation","terrain_wavelength","spawn_clearing_radius","sculpt_speed","maximum_sculpt_slope"]:
		terrain_controller.set(property,balance.get(property))
	water_controller.water_level = balance.water_level
	for property in ["wetting_speed","drying_speed","ground_change_speed"]:
		environment_controller.set(property,balance.get(property))

func _physics_process(delta: float) -> void:
	if _harvesting_active and _mode == MODE.HARVEST and not _is_navigating():
		_collect_elapsed += delta
		if _collect_elapsed >= database.world.gather_interval:
			_collect_elapsed = 0.0
			_collect_at_mouse()
	if _grab_requested:
		_grab_requested = false
		if _mode == MODE.NONE and not _is_navigating() and get_viewport().gui_get_hovered_control() == null:
			_try_grab_creature()
	if is_instance_valid(_held_creature):
		_update_creature_drag()
	else:
		_held_creature = null

func set_mode(mode: MODE) -> void:
	_grab_requested = false
	if mode != MODE.NONE:
		_release_creature()
	_mode = mode
	_painting_active = false
	_sculpting_active = false
	_harvesting_active = false
	terrain_controller.end_sculpt()
	terrain_controller.end_stroke()
	brush_controller.set_sculpting(mode == MODE.SCULPT)
	_update_brush_state()
	harvest_controller.activate(mode == MODE.HARVEST)
	fances_controller.activate(mode == MODE.FANCE and not _is_navigating())
	regions_controller.activate_view(mode == MODE.REGIONS)
	_update_region_hover()
	_update_harvest_hover()

func select_fence(index: int) -> void:
	fances_controller.select_fence(index)

func _pointer_position(prefer_post: bool = false) -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var screen := get_viewport().get_mouse_position()
	if prefer_post:
		var post_id := fances_controller.get_post_at_screen(screen, camera)
		if post_id:
			return fances_controller.map_to_world(fances_controller.get_post(post_id).position)
	var point = GroundPicker3D.from_screen(camera, screen, terrain_controller)
	if point == null or not terrain_controller.contains_world_point(point):
		return null
	return point

func _on_lmb(pressed: bool) -> void:
	if not pressed:
		_release_creature()
	match _mode:
		MODE.NONE:
			_grab_requested = pressed and not _is_navigating() and get_viewport().gui_get_hovered_control() == null
		MODE.PAINT:
			_painting_active = pressed and not _is_navigating() and get_viewport().gui_get_hovered_control() == null
			terrain_controller.end_stroke()
			if _painting_active:
				_paint_at_mouse()
		MODE.SCULPT:
			_sculpting_active = pressed and not _is_navigating() and get_viewport().gui_get_hovered_control() == null
			terrain_controller.end_sculpt()
			var point = _pointer_position()
			if _sculpting_active and point != null:
				terrain_controller.begin_sculpt(selected_sculpt_tool,point,brush_controller.brush_radius,brush_controller.brush_hardness)
		MODE.HARVEST:
			var allowed := not _is_navigating() and get_viewport().gui_get_hovered_control() == null
			_harvesting_active = pressed and allowed and harvest_controller.uses_brush()
			_collect_elapsed = 0.0
			harvest_controller.end_stroke()
			terrain_controller.end_stroke()
			if _harvesting_active:
				_collect_at_mouse()
			elif pressed and allowed and not harvest_controller.uses_brush():
				_update_harvest_hover()
				harvest_controller.strike()
		MODE.FANCE:
			var over_ui := get_viewport().gui_get_hovered_control() != null
			var point = _pointer_position(true)
			if pressed:
				if not over_ui and not _is_navigating() and point != null:
					fances_controller.begin_drawing(point)
			else:
				fances_controller.finish_drawing(point if point != null else Vector3.ZERO, not over_ui and not _is_navigating() and point != null)

func _on_rmb(pressed: bool) -> void:
	if pressed and get_viewport().gui_get_hovered_control() != null:
		return
	if not pressed and not _panning:
		return
	_panning = pressed
	_on_navigation_changed(pressed)

func _on_mmb(pressed: bool) -> void:
	if pressed:
		if get_viewport().gui_get_hovered_control() != null or camera_controller == null:
			return
		if not camera_controller.begin_orbit(terrain_controller):
			return
	elif not _rotating:
		return
	_rotating = pressed
	_on_navigation_changed(pressed)

func _is_navigating() -> bool:
	return _panning or _rotating

func _update_brush_state() -> void:
	brush_controller.activate(not _is_navigating() and (_mode == MODE.PAINT or _mode == MODE.SCULPT or (_mode == MODE.HARVEST and harvest_controller.uses_brush())))

func _on_navigation_changed(started: bool) -> void:
	_last_pointer = get_viewport().get_mouse_position()
	if started:
		_release_creature()
		harvest_controller.cancel_action()
		_painting_active = false
		_sculpting_active = false
		_harvesting_active = false
		terrain_controller.end_sculpt()
		terrain_controller.end_stroke()
	_update_brush_state()
	fances_controller.activate(_mode == MODE.FANCE and not _is_navigating())
	_update_region_hover()
	_update_harvest_hover()

func _on_mouse_move(viewport_position: Vector2) -> void:
	if camera_controller != null:
		if _rotating:
			camera_controller.orbit(viewport_position.x-_last_pointer.x)
		elif _panning:
			camera_controller.pan(_last_pointer,viewport_position,terrain_controller)
	_last_pointer = viewport_position
	_update_region_hover()
	_update_harvest_hover()
	_update_sculpt_target()
	if get_viewport().gui_get_hovered_control() != null:
		harvest_controller.end_stroke()
		terrain_controller.end_stroke()
		return
	if not _is_navigating() and _mode == MODE.PAINT and _painting_active:
		_paint_at_mouse()

func _paint_at_mouse() -> void:
	if get_viewport().gui_get_hovered_control() != null:
		harvest_controller.end_stroke()
		terrain_controller.end_stroke()
		return
	var point = _pointer_position()
	if point == null:
		terrain_controller.end_stroke()
		return
	var available := inventory.amount(selected_material)
	var used := terrain_controller.paint(selected_material,point,brush_controller.brush_radius,brush_controller.brush_hardness,available)
	inventory.spend(selected_material,used)

func _on_mouse_scroll(direction: int) -> void:
	if get_viewport().gui_get_hovered_control() != null:
		return
	if _mode == MODE.PAINT or _mode == MODE.SCULPT or (_mode == MODE.HARVEST and harvest_controller.uses_brush()):
		brush_controller.change_size(direction)
		_update_sculpt_target()
	elif camera_controller != null:
		camera_controller.zoom(direction, get_viewport().get_mouse_position(), terrain_controller)
	_update_region_hover()
	_update_harvest_hover()

func _update_region_hover() -> void:
	if _mode != MODE.REGIONS:
		return
	var point = _pointer_position()
	if _is_navigating() or get_viewport().gui_get_hovered_control() != null or point == null:
		regions_controller.clear_hover()
	else:
		regions_controller.hover_at(point)

func select_sculpt_tool(tool: TerrainController.SCULPT_TOOL) -> void:
	_sculpting_active = false
	terrain_controller.end_sculpt()
	selected_sculpt_tool = tool

func _update_sculpt_target() -> void:
	if not _sculpting_active:
		return
	var point = null if get_viewport().gui_get_hovered_control() != null else _pointer_position()
	terrain_controller.update_sculpt_target(point,brush_controller.brush_radius,brush_controller.brush_hardness)

func _try_grab_creature() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or is_instance_valid(_held_creature):
		return
	var origin := camera.project_ray_origin(_last_pointer)
	var direction := camera.project_ray_normal(_last_pointer)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * camera.far, CREATURE_PICK_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var creature := hit["collider"] as Creature
	if creature == null:
		return
	_held_creature = creature
	_grab_screen_offset = camera.unproject_position(creature.global_position) - _last_pointer
	_held_plane_height = creature.global_position.y + creature.hold_height
	creature.begin_hold()

func _update_creature_drag() -> void:
	if _mode != MODE.NONE:
		_release_creature()
		return
	if _is_navigating() or get_viewport().gui_get_hovered_control() != null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_release_creature()
		return
	var screen := _last_pointer + _grab_screen_offset
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var half_size := (terrain_controller.world_size * 0.5 - Vector2.ONE * 0.6).max(Vector2.ZERO)
	var target := _held_creature.global_position
	for iteration in range(3):
		var plane := Plane(Vector3.UP, Vector3(0.0, _held_plane_height, 0.0))
		var intersection = plane.intersects_ray(origin, direction)
		if intersection == null:
			return
		var local := terrain_controller.to_local(intersection)
		local.x = clampf(local.x, -half_size.x, half_size.x)
		local.z = clampf(local.z, -half_size.y, half_size.y)
		target = terrain_controller.to_global(local)
		_held_plane_height = terrain_controller.surface_position(target).y + _held_creature.get_hold_height()
	target.y = _held_plane_height
	_held_creature.set_hold_target(target)

func _release_creature() -> void:
	_grab_requested = false
	if is_instance_valid(_held_creature):
		_held_creature.release()
	_held_creature = null

func select_harvest_tool(tool: HarvestController.TOOL) -> void:
	_harvesting_active = false
	terrain_controller.end_stroke()
	harvest_controller.select_tool(tool)
	_update_brush_state()
	_update_harvest_hover()

func _collect_at_mouse() -> void:
	if get_viewport().gui_get_hovered_control() != null:
		harvest_controller.end_stroke()
		terrain_controller.end_stroke()
		return
	var point = _pointer_position()
	if point == null:
		harvest_controller.end_stroke()
		terrain_controller.end_stroke()
		return
	harvest_controller.collect(point,brush_controller.brush_radius)

func _update_harvest_hover() -> void:
	harvest_controller.hover_at(get_viewport().get_mouse_position(),get_viewport().get_camera_3d(),_mode == MODE.HARVEST and not _is_navigating() and get_viewport().gui_get_hovered_control() == null)

func _on_focus_exited() -> void:
	_release_creature()
	_panning = false
	_rotating = false
	_painting_active = false
	_sculpting_active = false
	_harvesting_active = false
	terrain_controller.end_stroke()
	terrain_controller.end_sculpt()
	_update_brush_state()
	fances_controller.activate(_mode == MODE.FANCE)
	harvest_controller.cancel_action()
