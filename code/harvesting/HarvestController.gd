class_name HarvestController
extends Node

enum TOOL { GROUND, PLANTS, AXE, MINING }

@export var tool_view: HarvestTool

var selected_tool: TOOL = TOOL.GROUND
var _terrain: TerrainController
var _vegetation: VegetationController
var _rocks: RockController
var _inventory: ResourceInventory
var _target: HarvestableDeposit
var _camera: Camera3D
var _active := false
var _has_collect_point := false
var _last_collect_point := Vector3.ZERO

func initialize(terrain: TerrainController, vegetation: VegetationController, rocks: RockController, inventory: ResourceInventory) -> void:
	_terrain = terrain
	_vegetation = vegetation
	_rocks = rocks
	_inventory = inventory
	set_process(false)

func uses_brush() -> bool:
	return selected_tool == TOOL.GROUND or selected_tool == TOOL.PLANTS

func activate(active: bool) -> void:
	_active = active
	cancel_action()
	set_process(active and not uses_brush())

func cancel_action() -> void:
	_set_target(null)
	end_stroke()
	tool_view.cancel()

func select_tool(tool: TOOL) -> void:
	selected_tool = tool
	_set_target(null)
	end_stroke()
	tool_view.select_mining(tool == TOOL.MINING)
	set_process(_active and not uses_brush())

func _set_target(target: HarvestableDeposit) -> void:
	if is_instance_valid(_target) and _target != target:
		_target.set_hovered(false)
	_target = target
	if is_instance_valid(_target):
		_target.set_hovered(true)
	tool_view.activate(is_instance_valid(_target))

func hover_at(screen: Vector2, camera: Camera3D, allowed: bool) -> void:
	_camera = camera
	var target: HarvestableDeposit
	if _active and not uses_brush() and allowed and camera != null:
		target = _vegetation.tree_at_screen(screen,camera) if selected_tool == TOOL.AXE else _rocks.rock_at_screen(screen,camera)
	if is_instance_valid(target) and _vegetation.occludes_target(screen,camera,target):
		target = null
	_set_target(target)
	if is_instance_valid(_target):
		tool_view.point_at(_target.global_position,camera)

func end_stroke() -> void:
	_has_collect_point = false

func collect(point: Vector3, radius: float) -> void:
	if not _active:
		return
	if selected_tool == TOOL.GROUND:
		var collected := _terrain.harvest_ground(point,radius)
		for kind in ResourceInventory.GROUND_TYPES:
			_inventory.add(kind,collected[kind])
	elif selected_tool == TOOL.PLANTS:
		var world_radius := radius/_terrain.pixels_per_unit
		var steps := maxi(1,ceili(_last_collect_point.distance_to(point)/maxf(0.05,world_radius*0.5))) if _has_collect_point else 1
		if not _has_collect_point:
			_last_collect_point = point
		var totals: Dictionary[int, int] = {}
		for step in range(1,steps+1):
			var collected := _vegetation.gather_plants(_last_collect_point.lerp(point,float(step)/steps),world_radius)
			for kind in collected:
				totals[kind] = totals.get(kind,0)+collected[kind]
		for kind in totals:
			_inventory.add(kind,totals[kind])
		_last_collect_point = point
		_has_collect_point = true

func strike() -> void:
	if not _active or not is_instance_valid(_target) or _target.exhausted:
		return
	tool_view.swing()
	var resource := _target.resource_kind
	var quantity := _target.strike()
	_inventory.add(resource,quantity)
	if _target.exhausted:
		_set_target(null)

func _process(_delta: float) -> void:
	if not is_instance_valid(_target) or _target.exhausted:
		_set_target(null)
	elif is_instance_valid(_camera):
		tool_view.point_at(_target.global_position,_camera)
