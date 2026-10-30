class_name MapManager
extends Node3D

@export var database: GameDatabase
@export var map_size := Vector2i(512, 512)
@export var pixels_per_unit := 32.0
@export var inspection_panel: InspectionPanel
@export var hatch_presentation: HatchPresentation
@export var camera_controller: MapCameraController

@onready var noise: NoiseController = $Noise
@onready var wellbeing: CreatureWellbeingController = $Wellbeing
@onready var new_content: NewContentTracker = $NewContent
@onready var discoveries: DiscoveryController = $Discoveries
@onready var items: ItemInventory = $Items
@onready var science: ScienceController = $Science
@onready var breeding: BreedingController = $Breeding
@onready var navigation: CreatureNavigation = $Navigation
@onready var building_controller: BuildingController = $Buildings
@onready var inventory: ResourceInventory = $Inventory
@onready var harvest_controller: HarvestController = $Harvest
@onready var rock_controller: RockController = $Rocks
@onready var terrain_controller: TerrainController = $Terrain
@onready var water_controller: WaterController = $Water
@onready var environment_controller: EnvironmentController = $Environment
@onready var vegetation_controller: VegetationController = $Vegetation
@onready var planting_controller: PlantingController = $Planting
@onready var brush_controller: BrushController = $Brush
@onready var fances_controller: FenceController = %Fances
@onready var regions_controller: RegionsController = $Regions

enum MODE { NONE = 0, FANCE = 2, SCULPT = 4, HARVEST = 5, BUILD = 6, DISCOVERIES = 7, BACKPACK = 8, PLANT = 9 }

signal mode_changed(mode: MODE)
signal modal_changed(active: bool)

const CREATURE_HOLD_DELAY := 0.22
const CREATURE_DRAG_DISTANCE := 6.0

var modal_active := false

var _mode: MODE = MODE.NONE
var _sculpting_active := false
var _harvesting_active := false
var _collect_elapsed := 0.0
var _panning := false
var _rotating := false
var _keyboard_navigating := false
var _camera_direction := Vector2.ZERO
var _camera_turn := 0.0
var _last_pointer := Vector2.ZERO
var selected_sculpt_tool: TerrainController.SCULPT_TOOL = TerrainController.SCULPT_TOOL.RAISE
var _held_creature: Creature
var _pressed_actor: Node3D
var _press_position := Vector2.ZERO
var _press_elapsed := 0.0
var _drag_requested := false
var _grab_screen_offset := Vector2.ZERO
var _held_plane_height := 0.0

func _ready() -> void:
	_apply_database()
	if not terrain_controller.initialize(map_size, pixels_per_unit, environment_controller.enabled):
		return
	water_controller.initialize(terrain_controller)
	fances_controller.configure_world(pixels_per_unit, Rect2(-Vector2(map_size) * 0.5, Vector2(map_size)))
	fances_controller.configure_surface(terrain_controller)
	fances_controller.configure_inventory(inventory,discoveries)
	brush_controller.configure_surface()
	environment_controller.initialize(terrain_controller, water_controller)
	vegetation_controller.initialize(terrain_controller, environment_controller)
	planting_controller.initialize(self)
	rock_controller.initialize(terrain_controller,environment_controller,vegetation_controller)
	harvest_controller.initialize(terrain_controller,vegetation_controller,rock_controller,inventory)
	regions_controller.initialize(terrain_controller, fances_controller, water_controller)
	building_controller.building_placed.connect(_on_building_placed)
	science.initialize(database)
	breeding.initialize(self)
	discoveries.initialize(self)
	building_controller.initialize(self)
	wellbeing.initialize(self)
	new_content.initialize(self)
	navigation.initialize(self)
	if camera_controller != null:
		camera_controller.configure(terrain_controller.world_size)
	InputManager.on_lmb.connect(_on_lmb)
	InputManager.on_mmb.connect(_on_mmb)
	InputManager.on_rmb.connect(_on_rmb)
	InputManager.on_mouse_move.connect(_on_mouse_move)
	InputManager.on_mouse_scroll.connect(_on_mouse_scroll)
	InputManager.on_camera_move.connect(_on_camera_move)
	InputManager.on_camera_turn.connect(_on_camera_turn)
	get_window().focus_exited.connect(_on_focus_exited)
	_last_pointer = get_viewport().get_mouse_position()

func _apply_database() -> void:
	if database == null:
		database = load(GameDatabase.DEFAULT_PATH) as GameDatabase
	inventory.configure(database.resources)
	vegetation_controller.species = database.flora
	rock_controller.definitions = database.deposits
	var balance := database.world
	terrain_controller.generate_on_start = balance.generate_nature_on_start
	environment_controller.enabled = balance.generate_nature_on_start
	for property in ["starting_height_variation","terrain_wavelength","spawn_clearing_radius","sculpt_speed","maximum_sculpt_slope","starting_pond_radius","starting_pond_offset"]:
		terrain_controller.set(property,balance.get(property))
	vegetation_controller.spawn_clearing_radius = balance.spawn_clearing_radius
	water_controller.water_level = balance.water_level
	terrain_controller.starting_water_level = balance.water_level

func _physics_process(delta: float) -> void:
	if inspection_panel != null and inspection_panel.focused and is_instance_valid(inspection_panel.target):
		camera_controller.track_focus(inspection_panel.focus_position())
	_tick_keyboard_navigation(delta)
	if modal_active:
		return
	if _harvesting_active and _mode == MODE.HARVEST and not _is_navigating():
		_collect_elapsed += delta
		if _collect_elapsed >= database.world.gather_interval:
			_collect_elapsed = 0.0
			_collect_at_mouse()
	if is_instance_valid(_pressed_actor) and not is_instance_valid(_held_creature):
		if _mode != MODE.NONE or _is_navigating() or get_viewport().gui_get_hovered_control() != null:
			_cancel_pointer_action()
		else:
			_press_elapsed += delta
			if _pressed_actor is Creature and (_press_elapsed >= CREATURE_HOLD_DELAY or _drag_requested):
				_begin_creature_hold(_pressed_actor)
	if is_instance_valid(_held_creature):
		_update_creature_drag()
	else:
		_held_creature = null

func set_mode(mode: MODE) -> void:
	_release_creature()
	if inspection_panel != null:
		inspection_panel.close_focus()
	_mode = mode
	_sculpting_active = false
	_harvesting_active = false
	terrain_controller.end_sculpt()
	brush_controller.set_sculpting(mode == MODE.SCULPT)
	_update_brush_state()
	harvest_controller.activate(mode == MODE.HARVEST)
	fances_controller.activate(mode == MODE.FANCE and not _is_navigating())
	_update_harvest_hover()
	building_controller.activate(mode == MODE.BUILD and not _is_navigating())
	_update_build_preview()
	set_modal(mode in [MODE.DISCOVERIES,MODE.BACKPACK])
	mode_changed.emit(mode)

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
	if pressed and _mode != MODE.NONE and not _is_navigating() and get_viewport().gui_get_hovered_control() == null:
		var actor := _pick_actor(get_viewport().get_mouse_position())
		if actor != null and building_controller.building_definition(actor) != null:
			set_mode(MODE.NONE)
			_begin_actor_click(get_viewport().get_mouse_position())
			return
	if modal_active:
		return
	match _mode:
		MODE.NONE:
			if pressed:
				_begin_actor_click(get_viewport().get_mouse_position())
			else:
				_finish_actor_click()
		MODE.PLANT:
			if pressed and not _is_navigating() and get_viewport().gui_get_hovered_control() == null:
				var point = _pointer_position()
				if point != null and planting_controller.place_at(point) and items.amount(planting_controller.selected.sapling_item) == 0:
					set_mode(MODE.NONE)
		MODE.BUILD:
			if pressed and not _is_navigating() and get_viewport().gui_get_hovered_control() == null:
				var point = _pointer_position()
				if point != null:
					building_controller.place_at(point)
		MODE.SCULPT:
			_sculpting_active = pressed and not _is_navigating() and get_viewport().gui_get_hovered_control() == null
			terrain_controller.end_sculpt()
			var point = _pointer_position()
			if _sculpting_active and point != null:
				new_content.mark_tool_seen(MODE.SCULPT,int(selected_sculpt_tool))
				terrain_controller.begin_sculpt(selected_sculpt_tool,point,brush_controller.brush_radius,brush_controller.brush_hardness)
		MODE.HARVEST:
			var allowed := not _is_navigating() and get_viewport().gui_get_hovered_control() == null
			_harvesting_active = pressed and allowed and harvest_controller.uses_brush()
			_collect_elapsed = 0.0
			harvest_controller.end_stroke()
			if _harvesting_active:
				_collect_at_mouse()
			elif pressed and allowed and not harvest_controller.uses_brush():
				_update_harvest_hover()
				new_content.mark_tool_seen(MODE.HARVEST,int(harvest_controller.selected_tool))
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
	if not pressed:
		return
	for panel in get_tree().get_nodes_in_group("discovery_panels"):
		if panel.get_viewport() == get_viewport() and panel.owns_secondary_action():
			return
	if _mode != MODE.NONE:
		set_mode(MODE.NONE)
		return
	if modal_active:
		return
	_release_creature()
	if inspection_panel != null and inspection_panel.focused:
		inspection_panel.close_focus()

func _on_mmb(pressed: bool) -> void:
	if modal_active or (inspection_panel != null and inspection_panel.focused):
		return
	if pressed:
		if get_viewport().gui_get_hovered_control() != null or camera_controller == null:
			return
		_rotating = Input.is_key_pressed(KEY_ALT)
		if _rotating and not camera_controller.begin_orbit(terrain_controller):
			_rotating = false
			return
		_panning = not _rotating
	else:
		if not _panning and not _rotating:
			return
		_panning = false
		_rotating = false
	_on_navigation_changed(pressed)

func _on_camera_move(direction: Vector2) -> void:
	_camera_direction = direction

func _on_camera_turn(direction: float) -> void:
	_camera_turn = direction

func _tick_keyboard_navigation(delta: float) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	var blocked := modal_active or (inspection_panel != null and inspection_panel.focused) or owner is LineEdit or owner is TextEdit
	var moving := not blocked and (not _camera_direction.is_zero_approx() or not is_zero_approx(_camera_turn)) and camera_controller != null
	if moving != _keyboard_navigating:
		_keyboard_navigating = moving
		_on_navigation_changed(moving)
	if not moving:
		return
	camera_controller.pan_direction(_camera_direction,delta,terrain_controller)
	if not is_zero_approx(_camera_turn) and camera_controller.begin_orbit(terrain_controller):
		camera_controller.orbit(_camera_turn*180.0*delta)

func _is_navigating() -> bool:
	return _panning or _rotating or _keyboard_navigating

func _update_brush_state() -> void:
	brush_controller.activate(not _is_navigating() and (_mode == MODE.SCULPT or (_mode == MODE.HARVEST and harvest_controller.uses_brush())))

func _on_navigation_changed(started: bool) -> void:
	_last_pointer = get_viewport().get_mouse_position()
	if started:
		if camera_controller != null:
			camera_controller.begin_navigation()
		_release_creature()
		harvest_controller.cancel_action()
		_sculpting_active = false
		_harvesting_active = false
		terrain_controller.end_sculpt()
	_update_brush_state()
	fances_controller.activate(_mode == MODE.FANCE and not _is_navigating())
	building_controller.activate(_mode == MODE.BUILD and not _is_navigating())
	_update_build_preview()
	_update_harvest_hover()

func _on_mouse_move(viewport_position: Vector2) -> void:
	if modal_active:
		return
	if camera_controller != null:
		if _rotating:
			camera_controller.orbit(viewport_position.x-_last_pointer.x)
		elif _panning:
			camera_controller.pan(_last_pointer,viewport_position,terrain_controller)
	_last_pointer = viewport_position
	if is_instance_valid(_pressed_actor) and viewport_position.distance_to(_press_position) >= CREATURE_DRAG_DISTANCE:
		_drag_requested = true
	_update_harvest_hover()
	_update_sculpt_target()
	_update_build_preview()
	if get_viewport().gui_get_hovered_control() != null:
		harvest_controller.end_stroke()
		return

func _on_mouse_scroll(direction: int) -> void:
	if modal_active or (inspection_panel != null and inspection_panel.focused):
		return
	if get_viewport().gui_get_hovered_control() != null:
		return
	if _mode == MODE.SCULPT or (_mode == MODE.HARVEST and harvest_controller.uses_brush()):
		brush_controller.change_size(direction)
		_update_sculpt_target()
	elif camera_controller != null:
		camera_controller.zoom(direction, get_viewport().get_mouse_position(), terrain_controller)
	_update_harvest_hover()
	_update_build_preview()

func select_sculpt_tool(tool: TerrainController.SCULPT_TOOL) -> void:
	_sculpting_active = false
	terrain_controller.end_sculpt()
	selected_sculpt_tool = tool

func _update_sculpt_target() -> void:
	if not _sculpting_active:
		return
	var point = null if get_viewport().gui_get_hovered_control() != null else _pointer_position()
	terrain_controller.update_sculpt_target(point,brush_controller.brush_radius,brush_controller.brush_hardness)

func _begin_actor_click(screen: Vector2) -> void:
	_release_creature()
	if _mode != MODE.NONE or modal_active or _is_navigating() or get_viewport().gui_get_hovered_control() != null:
		return
	_pressed_actor = _pick_actor(screen)
	_press_position = screen
	_last_pointer = screen

func _pick_actor(screen: Vector2) -> Node3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var chosen: Node3D
	var nearest := camera.far
	var candidates: Array = get_tree().get_nodes_in_group("creatures")
	candidates.append_array(building_controller.get_buildings())
	candidates.append_array(fances_controller.get_damageable_views())
	candidates.append_array(get_tree().get_nodes_in_group("loose_eggs"))
	for actor: Node3D in candidates:
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.get_viewport() != get_viewport() or not actor.is_visible_in_tree():
			continue
		if not (actor is Creature or actor is IncubatorController or actor is FeederController or actor is WorkshopController or actor is LooseEggController or actor.has_method("structure_condition")):
			continue
		var inverse := actor.global_transform.affine_inverse()
		var bounds: AABB = actor.inspection_bounds()
		var hit = bounds.intersects_ray(inverse*origin,inverse.basis*direction)
		if hit != null:
			var distance := origin.distance_to(actor.global_transform*hit)
			if distance < nearest:
				nearest = distance
				chosen = actor
	return chosen

func _finish_actor_click() -> void:
	var actor := _pressed_actor
	var clicked := is_instance_valid(actor) and not is_instance_valid(_held_creature) and not _drag_requested
	clicked = clicked and _mode == MODE.NONE and not modal_active and not _is_navigating() and get_viewport().gui_get_hovered_control() == null
	if clicked and actor is Creature and _press_elapsed >= CREATURE_HOLD_DELAY:
		clicked = false
	_release_creature()
	if clicked and actor is LooseEggController:
		actor.collect()
	elif clicked and inspection_panel != null:
		var data := building_controller.building_definition(actor)
		if data != null:
			new_content.mark_building_seen(data.id)
		inspection_panel.inspect(actor)

func _cancel_pointer_action() -> void:
	_pressed_actor = null
	_press_elapsed = 0.0
	_drag_requested = false

func _begin_creature_hold(creature: Creature) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(creature):
		_cancel_pointer_action()
		return
	if inspection_panel != null:
		inspection_panel.close_focus()
	if camera_controller != null:
		camera_controller.begin_navigation()
	_held_creature = creature
	_grab_screen_offset = camera.unproject_position(creature.global_position) - _press_position
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
	_cancel_pointer_action()
	if is_instance_valid(_held_creature):
		if not _held_creature.release():
			return
	_held_creature = null

func select_harvest_tool(tool: HarvestController.TOOL) -> void:
	_harvesting_active = false
	harvest_controller.select_tool(tool)
	_update_brush_state()
	_update_harvest_hover()

func _collect_at_mouse() -> void:
	if get_viewport().gui_get_hovered_control() != null:
		harvest_controller.end_stroke()
		return
	var point = _pointer_position()
	if point == null:
		harvest_controller.end_stroke()
		return
	new_content.mark_tool_seen(MODE.HARVEST,int(harvest_controller.selected_tool))
	harvest_controller.collect(point,brush_controller.brush_radius)

func _update_harvest_hover() -> void:
	harvest_controller.hover_at(get_viewport().get_mouse_position(),get_viewport().get_camera_3d(),_mode == MODE.HARVEST and not _is_navigating() and get_viewport().gui_get_hovered_control() == null)

func _on_focus_exited() -> void:
	_release_creature()
	_camera_direction = Vector2.ZERO
	_camera_turn = 0.0
	_keyboard_navigating = false
	_panning = false
	_rotating = false
	_sculpting_active = false
	_harvesting_active = false
	terrain_controller.end_sculpt()
	_update_brush_state()
	fances_controller.activate(_mode == MODE.FANCE)
	building_controller.activate(_mode == MODE.BUILD)
	_update_build_preview()
	harvest_controller.cancel_action()

func _update_build_preview() -> void:
	planting_controller.activate(_mode == MODE.PLANT and not modal_active and not _is_navigating())
	if _mode not in [MODE.BUILD,MODE.PLANT]:
		return
	var allowed := not modal_active and not _is_navigating() and get_viewport().gui_get_hovered_control() == null
	var point = _pointer_position() if allowed else null
	if _mode == MODE.PLANT:
		planting_controller.preview_at(point)
	else:
		building_controller.preview_at(point)

func _on_building_placed(building: Node3D, _definition: BuildingDefinition) -> void:
	discoveries.discover(_definition.id,building.global_position)
	if building is IncubatorController:
		building.initialize(self)
		building.hatch_requested.connect(_on_hatch_requested)
		discoveries.discover(&"life",building.global_position)
	elif building is FeederController:
		building.initialize(self,_definition)
	elif building is WorkshopController:
		building.initialize(self)

func _on_hatch_requested(incubator_node: IncubatorController) -> void:
	if hatch_presentation != null:
		hatch_presentation.present(incubator_node)

func set_modal(active: bool) -> void:
	modal_active = active
	_camera_direction = Vector2.ZERO
	_camera_turn = 0.0
	_keyboard_navigating = false
	_panning = false
	_rotating = false
	_sculpting_active = false
	_harvesting_active = false
	_release_creature()
	terrain_controller.end_sculpt()
	harvest_controller.cancel_action()
	brush_controller.activate(false)
	fances_controller.activate(false)
	building_controller.activate(false)
	planting_controller.activate(false)
	if not active:
		_update_brush_state()
		fances_controller.activate(_mode == MODE.FANCE)
		building_controller.activate(_mode == MODE.BUILD)
		_update_build_preview()

	modal_changed.emit(active)

func cancel_action() -> bool:
	if _mode in [MODE.DISCOVERIES,MODE.BACKPACK]:
		set_mode(MODE.NONE)
		return true
	if modal_active:
		return true
	if inspection_panel != null and inspection_panel.focused:
		inspection_panel.close_focus()
		return true
	if _mode != MODE.NONE or is_instance_valid(_held_creature) or is_instance_valid(_pressed_actor):
		set_mode(MODE.NONE)
		return true
	return false

func current_mode() -> MODE:
	return _mode

func start_planting(id: StringName) -> void:
	var data := database.plant(id)
	if data == null or items.amount(data.sapling_item) <= 0:
		return
	planting_controller.select_plant(data)
	set_mode(MODE.PLANT)
