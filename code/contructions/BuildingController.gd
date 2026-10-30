class_name BuildingController
extends Node3D

signal building_placed(building: Node3D, definition: BuildingDefinition)
signal obstacles_changed
signal selection_changed(index: int)
signal preview_changed(valid: bool, reason: String)

const PREVIEW_SHADER = preload("res://code/contructions/fances/fence_preview.gdshader")

var selected_building := 0
var preview_error := tr("Choose a position on the map")
var _map: Node3D
var _definitions: Array[BuildingDefinition] = []
var _placed: Dictionary[Node3D, BuildingDefinition] = {}
var _health: Dictionary[Node3D,float] = {}
var _preview: Node3D
var _preview_material: ShaderMaterial
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
	selected_building = index
	if is_instance_valid(_preview):
		remove_child(_preview)
		_preview.queue_free()
	_preview = null
	var data := definition()
	if data.scene != null:
		var model := data.scene.instantiate()
		if model is Node3D:
			_preview = model
			_preview.name = "Preview"
			_preview.process_mode = Node.PROCESS_MODE_DISABLED
			_configure_preview(_preview)
			add_child(_preview)
			_preview.hide()
		else:
			model.free()
	selection_changed.emit(index)
	_refresh_preview()

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
	_preview.global_position = terrain.surface_position(_target)
	var reason := _placement_error(_target)
	_preview_material.set_shader_parameter("valid",reason.is_empty())
	_set_status(reason.is_empty(),reason)

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
	if not unlocked(data):
		return tr("Discover %s to unlock this building") % data.display_name
	if not inventory.can_afford_costs(data.costs()):
		return tr("Not enough resources")
	var terrain: TerrainController = _map.terrain_controller
	var water: WaterController = _map.water_controller
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
			return tr("The whole building must fit inside the map")
		var height := terrain.surface_position(sample).y
		if height <= water.global_position.y+0.04:
			return tr("Choose dry ground")
		minimum = minf(minimum,height)
		maximum = maxf(maximum,height)
	if maximum-minimum > data.maximum_height_difference:
		return tr("Flatten the ground before building")
	if occupied(center,data.footprint_radius):
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
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		return tr("The site is obstructed")
	return ""

func occupied(point: Vector3, radius: float) -> bool:
	for building in get_buildings():
		var reach := _placed[building].footprint_radius+radius
		if Vector2(point.x-building.global_position.x,point.z-building.global_position.z).length_squared() < reach*reach:
			return true
	return false

func place_at(point: Vector3) -> Node3D:
	if not _active or not _placement_error(point).is_empty():
		return null
	var data := definition()
	var model := data.scene.instantiate()
	if not model is Node3D:
		model.free()
		return null
	var inventory: ResourceInventory = _map.inventory
	var paid := inventory.spend_costs(data.costs())
	if not paid:
		model.free()
		return null
	var building := model as Node3D
	building.name = data.display_name.to_pascal_case()
	add_child(building)
	building.global_position = _map.terrain_controller.surface_position(point)
	_register_building(building,data)
	_refresh_preview()
	return building

func _on_building_removed(building: Node3D) -> void:
	_placed.erase(building)
	_health.erase(building)
	if is_inside_tree():
		obstacles_changed.emit()
		_refresh_preview()

func _on_height_changed() -> void:
	for building in get_buildings():
		building.global_position = _map.terrain_controller.surface_position(building.global_position)
	_refresh_preview()

func _on_inventory_changed(_kind: int, _amount: float) -> void:
	_refresh_preview()

func unlocked(data: BuildingDefinition) -> bool:
	return data.required_discovery.is_empty() or _map.discoveries.knows(data.required_discovery)

func _register_building(building: Node3D, data: BuildingDefinition) -> void:
	if _placed.has(building):
		return
	_placed[building] = data
	_health[building] = data.max_health
	building.tree_exiting.connect(_on_building_removed.bind(building))
	building_placed.emit(building,data)
	obstacles_changed.emit()

func building_definition(building: Node3D) -> BuildingDefinition:
	return _placed.get(building) as BuildingDefinition

func condition(building: Node3D) -> float:
	var data := building_definition(building)
	return clampf(_health.get(building,0.0)/maxf(data.max_health,0.001),0.0,1.0) if data != null else 0.0

func damage_building(building: Node3D, amount: float) -> bool:
	if not is_instance_valid(building) or building.is_queued_for_deletion() or not _placed.has(building) or amount <= 0.0:
		return false
	_health[building] = maxf(0.0,_health[building]-amount)
	if _health[building] <= 0.0:
		if building is IncubatorController and _map.hatch_presentation != null:
			_map.hatch_presentation.cancel_for(building)
		building.queue_free()
	return true

func repair_building(building: Node3D) -> bool:
	var data := building_definition(building)
	if data == null or not is_instance_valid(building) or building.is_queued_for_deletion():
		return false
	_health[building] = data.max_health
	return true
