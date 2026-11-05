class_name BuildingController
extends Node3D

signal building_placed(building: Node3D, definition: BuildingDefinition)
signal building_attacked(building: Node3D, attacker: Creature, damage: float)
signal prices_changed
signal obstacles_changed
signal relocation_changed
signal selection_changed(index: int)
signal preview_changed(valid: bool, reason: String)

enum SURFACE_ISSUE { NONE, OUTSIDE_MAP, FLOODED, UNEVEN }

const PREVIEW_SHADER = preload("res://code/contructions/fances/fence_preview.gdshader")

var selected_building := 0
var preview_error := tr("Choose a position on the map")
var _map: Node3D
var _definitions: Array[BuildingDefinition] = []
var _placed: Dictionary[Node3D, BuildingDefinition] = {}
var _health: Dictionary[Node3D,float] = {}
var _paid_costs: Dictionary[Node3D,Dictionary] = {}
var _relocation := BuildingRelocation.new()
var _build_counts: Dictionary[StringName,int] = {}
var _preview: Node3D
var _preview_material: ShaderMaterial
var _preview_basis := Basis.IDENTITY
var _preview_yaw := 0.0
var _active := false
var _target: Variant
var _valid := false

func initialize(map: Node3D) -> void:
	_map = map
	_definitions = map.database.buildings
	_preview_material = ShaderMaterial.new()
	_preview_material.shader = PREVIEW_SHADER
	map.inventory.changed.connect(_on_inventory_changed)
	map.discoveries.discovered.connect(func(_entry): _refresh_preview())
	map.terrain_controller.height_changed.connect(_on_height_changed)
	map.water_controller.water_level_changed.connect(_refresh_preview)
	map.fances_controller.network_changed.connect(_refresh_preview)
	for child in get_children():
		if child is Node3D:
			for data: BuildingDefinition in _definitions:
				if data.scene != null and child.scene_file_path == data.scene.resource_path:
					_build_counts[data.id] = _build_counts.get(data.id,0)+1
					_register_building(child,data)
	select_building(0)

func definition() -> BuildingDefinition:
	return _definitions[selected_building] if selected_building >= 0 and selected_building < _definitions.size() else null

func get_buildings() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for building in _placed:
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			result.append(building)
	return result

func select_building(index: int) -> void:
	if index < 0 or index >= _definitions.size() or not unlocked(_definitions[index]):
		return
	cancel_relocation()
	selected_building = index
	_create_preview(definition())
	selection_changed.emit(index)
	_refresh_preview()

func _create_preview(data: BuildingDefinition) -> void:
	if is_instance_valid(_preview):
		remove_child(_preview)
		_preview.queue_free()
	_preview = null
	if data != null and data.scene != null:
		var model := data.scene.instantiate()
		if model is Node3D:
			_preview = model
			_preview_basis = _preview.basis
			_preview.name = "Preview"
			_preview.process_mode = Node.PROCESS_MODE_DISABLED
			_configure_preview(_preview)
			add_child(_preview)
			_preview.hide()
		else:
			model.free()

func _configure_preview(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is MeshInstance3D:
		node.material_override = _preview_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is Light3D or node is Label3D:
		node.hide()
	for child in node.get_children():
		_configure_preview(child)

func activate(active: bool) -> void:
	_active = active
	if active and not is_instance_valid(_preview):
		var data := definition()
		if data != null and unlocked(data):
			select_building(selected_building)
		else:
			for index in _definitions.size():
				if unlocked(_definitions[index]):
					select_building(index)
					break
	if not active:
		_target = null
	_refresh_preview()

func preview_at(point: Variant) -> void:
	_target = point
	_refresh_preview()

func _refresh_preview() -> void:
	var has_target: bool = _active and _target is Vector3 and is_instance_valid(_preview) and _preview.is_inside_tree()
	if is_instance_valid(_preview):
		_preview.visible = has_target
	if not has_target:
		_set_status(false,tr("Choose a position on the map"))
		return
	var terrain: TerrainController = _map.terrain_controller
	_preview.global_transform = Transform3D(_preview_basis.rotated(Vector3.UP,_preview_yaw),terrain.surface_position(_target))
	var reason := _placement_error(_target)
	_preview_material.set_shader_parameter("valid",reason.is_empty())
	_set_status(reason.is_empty(),reason)

func rotate_preview(radians: float) -> void:
	if not _active or not is_finite(radians):
		return
	_preview_yaw = fposmod(_preview_yaw+radians,TAU)
	_refresh_preview()

func _set_status(valid: bool, reason: String) -> void:
	if _valid == valid and preview_error == reason:
		return
	_valid = valid
	preview_error = reason
	preview_changed.emit(valid,reason)

func _placement_error(point: Vector3) -> String:
	var data := definition()
	if data == null or data.scene == null:
		return tr("No building selected")
	var inventory: ResourceInventory = _map.inventory
	if not is_instance_valid(_relocation.target) and not unlocked(data):
		return tr("Discover %s to unlock this building") % data.display_name
	if not is_instance_valid(_relocation.target) and not inventory.can_afford_costs(placement_costs(data)):
		return tr("Not enough resources")
	var terrain: TerrainController = _map.terrain_controller
	var center := terrain.surface_position(point)
	match surface_issue(center,data):
		SURFACE_ISSUE.OUTSIDE_MAP:
			return tr("The whole building must fit inside the map")
		SURFACE_ISSUE.FLOODED:
			return tr("Choose dry ground")
		SURFACE_ISSUE.UNEVEN:
			return tr("Flatten the ground before building")
	if occupied(center,data.footprint_radius,_relocation.target):
		return tr("Buildings need more space")
	var local := terrain.to_local(center)
	if _map.vegetation_controller.occupied(Vector2(local.x,local.z),data.footprint_radius) or _map.rock_controller.occupied(center,data.footprint_radius):
		return tr("Clear the site before building")
	var shape := CylinderShape3D.new()
	shape.radius = data.footprint_radius
	shape.height = 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,center+Vector3.UP)
	query.collision_mask = 6
	query.exclude = _relocation.collision_rids()
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		return tr("The site is obstructed")
	return ""

func surface_issue(point: Vector3, data: BuildingDefinition) -> SURFACE_ISSUE:
	var terrain: TerrainController = _map.terrain_controller
	var center := terrain.surface_position(point)
	var minimum := center.y
	var maximum := center.y
	for index in 17:
		var offset := Vector3.ZERO
		if index > 0:
			var angle := (index-1)%8*TAU/8.0
			var radius := data.footprint_radius*(0.5 if index <= 8 else 1.0)
			offset = Vector3(cos(angle),0,sin(angle))*radius
		var sample := center+offset
		if not terrain.contains_world_point(sample):
			return SURFACE_ISSUE.OUTSIDE_MAP
		var height := terrain.surface_position(sample).y
		if height <= _map.water_controller.global_position.y+0.04:
			return SURFACE_ISSUE.FLOODED
		minimum = minf(minimum,height)
		maximum = maxf(maximum,height)
	return SURFACE_ISSUE.UNEVEN if maximum-minimum > data.maximum_height_difference else SURFACE_ISSUE.NONE

func occupied(point: Vector3, radius: float, ignored: Node3D = null) -> bool:
	for building in get_buildings():
		if building == ignored:
			continue
		var reach := _placed[building].footprint_radius+radius
		if Vector2(point.x-building.global_position.x,point.z-building.global_position.z).length_squared() < reach*reach:
			return true
	return false

func place_at(point: Vector3) -> Node3D:
	if not _active or is_instance_valid(_relocation.target) or not _placement_error(point).is_empty():
		return null
	var data := definition()
	var model := data.scene.instantiate()
	if not model is Node3D:
		model.free()
		return null
	var inventory: ResourceInventory = _map.inventory
	var costs := placement_costs(data)
	var paid := inventory.spend_costs(costs)
	if not paid:
		model.free()
		return null
	var building := model as Node3D
	building.name = data.display_name.to_pascal_case()
	add_child(building)
	building.global_transform = Transform3D(_preview_basis.rotated(Vector3.UP,_preview_yaw),_map.terrain_controller.surface_position(point))
	_build_counts[data.id] = _build_counts.get(data.id,0)+1
	_register_building(building,data,costs)
	_refresh_preview()
	return building

func _on_building_removed(building: Node3D) -> void:
	if _relocation.target == building:
		cancel_relocation()
	_placed.erase(building)
	_paid_costs.erase(building)
	_health.erase(building)
	if is_inside_tree():
		obstacles_changed.emit()
		_refresh_preview()
	prices_changed.emit()

func _on_height_changed() -> void:
	for building in get_buildings():
		building.global_position = _map.terrain_controller.surface_position(building.global_position)
		if building == _relocation.target:
			_relocation.original_transform.origin = building.global_position
	_refresh_preview()

func _on_inventory_changed(_kind: int, _amount: float) -> void:
	_refresh_preview()

func placement_count(data: BuildingDefinition) -> int:
	var count := 0
	if data == null:
		return count
	for building in get_buildings():
		if _placed[building] == data and _health.get(building,0.0) > 0.0:
			count += 1
	return count

func first_placement_available(data: BuildingDefinition) -> bool:
	return data != null and data.first_placement_free and _build_counts.get(data.id,0) == 0 and placement_count(data) == 0

func placement_costs(data: BuildingDefinition) -> Dictionary[int, int]:
	return data.scaled_costs(placement_count(data),_build_counts.get(data.id,0) > 0) if data != null else {}

func unlocked(data: BuildingDefinition) -> bool:
	return data.required_discovery.is_empty() or _map.discoveries.knows(data.required_discovery)

func _register_building(building: Node3D, data: BuildingDefinition, costs: Variant = null) -> void:
	if _placed.has(building):
		return
	_placed[building] = data
	_health[building] = data.max_health
	var paid: Dictionary[int,int] = {}
	paid.assign(costs if costs is Dictionary else data.costs())
	_paid_costs[building] = paid
	building.tree_exiting.connect(_on_building_removed.bind(building))
	building_placed.emit(building,data)
	prices_changed.emit()
	obstacles_changed.emit()

func building_definition(building: Node3D) -> BuildingDefinition:
	return _placed.get(building) as BuildingDefinition

func condition(building: Node3D) -> float:
	var data := building_definition(building)
	return clampf(_health.get(building,0.0)/maxf(data.max_health,0.001),0.0,1.0) if data != null else 0.0

func damage_building(building: Node3D, amount: float, attacker: Creature = null) -> bool:
	if not is_instance_valid(building) or building.is_queued_for_deletion() or not _placed.has(building) or amount <= 0.0 or _health.get(building,0.0) <= 0.0:
		return false
	if _relocation.target == building:
		cancel_relocation()
	var previous_health: float = _health[building]
	_health[building] = maxf(0.0,previous_health-amount)
	if is_instance_valid(attacker) and _health[building] < previous_health:
		building_attacked.emit(building,attacker,previous_health-_health[building])
	if _health[building] <= 0.0:
		if building is IncubatorController and _map.hatch_presentation != null:
			_map.hatch_presentation.cancel_for(building)
		if building is WorkshopController:
			building.destroy()
		else:
			building.queue_free()
		_refresh_preview()
		prices_changed.emit()
	return true

func paid_costs(building: Node3D) -> Dictionary[int,int]:
	var result: Dictionary[int,int] = {}
	result.assign(_paid_costs.get(building,{}))
	return result

func relocating_building() -> Node3D:
	return _relocation.target if is_instance_valid(_relocation.target) else null

func begin_relocation(building: Node3D) -> bool:
	if not is_instance_valid(building) or building.is_queued_for_deletion():
		return false
	var data := building_definition(building)
	if data == null or condition(building) <= 0.0:
		return false
	if building is IncubatorController and building.state == IncubatorController.STATE.PRESENTING:
		return false
	cancel_relocation()
	selected_building = _definitions.find(data)
	_create_preview(data)
	if not is_instance_valid(_preview):
		return false
	_relocation.begin(building,_map)
	_preview_basis = _relocation.original_transform.basis
	_preview_yaw = 0.0
	_active = true
	_target = building.global_position
	_refresh_preview()
	relocation_changed.emit()
	return true

func finish_relocation(point: Vector3) -> bool:
	if not _active or not is_instance_valid(_relocation.target) or _relocation.target.is_queued_for_deletion() or not _placement_error(point).is_empty():
		return false
	var transform := Transform3D(_preview_basis.rotated(Vector3.UP,_preview_yaw),_map.terrain_controller.surface_position(point))
	_relocation.finish(transform)
	_end_relocation_preview()
	obstacles_changed.emit()
	return true

func cancel_relocation() -> void:
	if not is_instance_valid(_relocation.target):
		return
	_relocation.finish(_relocation.original_transform)
	_end_relocation_preview()

func _end_relocation_preview() -> void:
	_active = false
	_target = null
	_preview_yaw = 0.0
	_create_preview(definition())
	_refresh_preview()
	relocation_changed.emit()

func demolish(building: Node3D) -> bool:
	if not is_instance_valid(building) or building.is_queued_for_deletion() or building_definition(building) == null:
		return false
	if _relocation.target == building:
		cancel_relocation()
	if building is WorkshopController and building.state == WorkshopController.STATE.RUINED:
		return clear_ruins(building)
	var refund := paid_costs(building)
	var origin := building.global_position
	if building is IncubatorController and _map.hatch_presentation != null:
		_map.hatch_presentation.cancel_for(building)
	building.queue_free()
	for kind: int in refund:
		_map.inventory.add(kind,refund[kind],origin)
	return true

func repair_building(building: Node3D) -> bool:
	var data := building_definition(building)
	if data == null or not is_instance_valid(building) or building.is_queued_for_deletion():
		return false
	if building is WorkshopController and building.state == WorkshopController.STATE.RUINED:
		return false
	_health[building] = data.max_health
	return true

func clear_ruins(building: Node3D) -> bool:
	if not is_instance_valid(building) or building.is_queued_for_deletion() or not _placed.has(building):
		return false
	if not building is WorkshopController or building.state != WorkshopController.STATE.RUINED or building._phase < 2.6:
		return false
	building.queue_free()
	return true
