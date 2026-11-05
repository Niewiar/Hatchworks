class_name HarvestController
extends Node

enum TOOL { GROUND = 0, HOE = 1, AXE = 2, MINING = 3 }

@export var tool_view: HarvestTool

const HOE_RADIUS := 0.22

var selected_tool: TOOL = TOOL.HOE
var _terrain: TerrainController
var _vegetation: VegetationController
var _rocks: RockController
var _inventory: ResourceInventory
var _target: HarvestableDeposit
var _camera: Camera3D
var _active := false
var _hoe_active := false
var _has_collect_point := false
var _last_collect_point := Vector3.ZERO
var _last_hoe_pointer := Vector3.ZERO

func initialize(terrain: TerrainController, vegetation: VegetationController, rocks: RockController, inventory: ResourceInventory) -> void:
	_terrain = terrain
	_vegetation = vegetation
	_rocks = rocks
	_inventory = inventory
	set_process(false)

func activate(active: bool) -> void:
	_active = active
	cancel_action()
	set_process(active and selected_tool in [TOOL.AXE,TOOL.MINING])

func cancel_action() -> void:
	end_hoe()
	_set_target(null)
	tool_view.cancel()

func select_tool(tool: TOOL) -> void:
	cancel_action()
	selected_tool = tool
	if tool == TOOL.HOE:
		tool_view.select_hoe()
	elif tool in [TOOL.AXE,TOOL.MINING]:
		tool_view.select_mining(tool == TOOL.MINING)
	set_process(_active and tool in [TOOL.AXE,TOOL.MINING])

func _set_target(target: HarvestableDeposit) -> void:
	if is_instance_valid(_target) and _target != target:
		_target.set_hovered(false)
	_target = target
	if is_instance_valid(_target):
		_target.set_hovered(true)
	tool_view.activate(is_instance_valid(_target))

func hover_at(screen: Vector2, camera: Camera3D, allowed: bool) -> void:
	_camera = camera
	if selected_tool == TOOL.GROUND:
		_set_target(null)
		tool_view.activate(false)
		return
	if selected_tool == TOOL.HOE:
		var point = GroundPicker3D.from_screen(camera,screen,_terrain) if _active and allowed and camera != null else null
		if point == null or not _terrain.contains_world_point(point):
			_has_collect_point = false
			tool_view.activate(false)
		else:
			if not _hoe_active:
				tool_view.point_on_ground(point,camera,_terrain,false)
			tool_view.activate(true)
		return
	var target: HarvestableDeposit
	if _active and allowed and camera != null:
		target = _vegetation.tree_at_screen(screen,camera) if selected_tool == TOOL.AXE else _rocks.rock_at_screen(screen,camera)
	if is_instance_valid(target) and _vegetation.occludes_target(screen,camera,target):
		target = null
	_set_target(target)
	if is_instance_valid(_target):
		tool_view.point_at(_target.global_position,camera)

func begin_hoe(point: Vector3) -> void:
	if not _active or selected_tool != TOOL.HOE:
		return
	_hoe_active = true
	_has_collect_point = false
	update_hoe(point)

func update_hoe(point: Variant) -> void:
	if not _hoe_active or not _active or selected_tool != TOOL.HOE:
		return
	if not point is Vector3 or not _terrain.contains_world_point(point) or not is_instance_valid(_camera):
		_has_collect_point = false
		tool_view.reset_rake_contact()
		tool_view.activate(false)
		return
	_last_hoe_pointer = point
	var contact := tool_view.point_on_ground(point,_camera,_terrain,true)
	if not _terrain.contains_world_point(contact):
		_has_collect_point = false
		tool_view.activate(false)
		return
	var path := tool_view.rake_path
	if path.is_empty():
		path.append(contact)
	for head_point in path:
		if not _terrain.contains_world_point(head_point):
			_has_collect_point = false
			continue
		var start: Vector3 = _last_collect_point if _has_collect_point else head_point
		var rewards := _vegetation.gather_segment(start,head_point,HOE_RADIUS)
		rewards.append_array(_rocks.collect_pebbles_segment(start,head_point,HOE_RADIUS))
		for reward in rewards:
			_inventory.add(reward.kind,reward.quantity,reward.origin)
		_last_collect_point = head_point
		_has_collect_point = true
	tool_view.activate(true)

func end_hoe() -> void:
	var was_active := _hoe_active
	_hoe_active = false
	_has_collect_point = false
	if was_active and is_instance_valid(_camera) and tool_view.visible:
		tool_view.point_on_ground(_last_hoe_pointer,_camera,_terrain,false)

func strike() -> void:
	if not _active or selected_tool not in [TOOL.AXE,TOOL.MINING] or not is_instance_valid(_target) or _target.exhausted:
		return
	tool_view.swing()
	var source := _target.global_position
	var map := get_parent() as MapManager
	if map != null:
		map.noise.pulse(source,0.8 if selected_tool == TOOL.MINING else 0.65,7.0 if selected_tool == TOOL.MINING else 5.5,5.0)
	SoundEffects.play_at(&"mining_hit" if selected_tool == TOOL.MINING else &"wood_hit",source,_target)
	var resource := _target.resource_kind
	var origin := _target.global_position+Vector3.UP*0.6
	var quantity := _target.strike()
	_inventory.add(resource,quantity,origin)
	if _target.exhausted:
		_set_target(null)

func _process(_delta: float) -> void:
	if not is_instance_valid(_target) or _target.exhausted:
		_set_target(null)
	elif is_instance_valid(_camera):
		tool_view.point_at(_target.global_position,_camera)
