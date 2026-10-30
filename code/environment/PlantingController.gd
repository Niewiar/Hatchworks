class_name PlantingController
extends MeshInstance3D

signal preview_changed

var selected: FloraSpecies
var preview_error := tr("Choose a planting position")
var _map: Node3D
var _active := false
var _point: Variant
var _material: ShaderMaterial

func initialize(map: Node3D) -> void:
	_map = map
	_material = ShaderMaterial.new()
	_material.shader = preload("res://code/contructions/fances/fence_preview.gdshader")
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()

func select_plant(data: FloraSpecies) -> void:
	selected = data
	mesh = data.variants[0] if data != null and not data.variants.is_empty() else null

func activate(active: bool) -> void:
	_active = active
	if not active:
		hide()

func preview_at(point: Variant) -> void:
	_point = point
	visible = _active and point is Vector3 and mesh != null
	if not visible:
		return
	global_position = _map.terrain_controller.surface_position(point)
	preview_error = placement_error(point)
	_material.set_shader_parameter("valid",preview_error.is_empty())
	preview_changed.emit()

func placement_error(point: Vector3) -> String:
	if selected == null or _map.items.amount(selected.sapling_item) < 1:
		return tr("No saplings available")
	if not _map.vegetation_controller.can_plant(selected,point):
		return tr("Unsuitable ground or plants too close")
	var radius := selected.trunk_radius+0.3 if selected.kind == FloraSpecies.KIND.TREE else 0.3
	if _map.building_controller.occupied(point,radius) or _map.rock_controller.occupied(point,radius):
		return tr("The site is obstructed")
	if not _map.navigation.space_available(point,null,maxf(radius,0.4)):
		return tr("Leave space for creatures")
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = point+Vector3.UP*radius
	query.collision_mask = 6
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		return tr("The site is obstructed")
	return ""

func place_at(point: Vector3) -> bool:
	if not _active or not placement_error(point).is_empty():
		return false
	if not _map.vegetation_controller.plant_specimen(selected,point):
		return false
	_map.items.spend(selected.sapling_item)
	preview_at(point)
	return true
