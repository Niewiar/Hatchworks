class_name BuildingEditingController
extends Node

signal changed

enum TOOL { MOVE, REMOVE }

var selected_tool: TOOL = TOOL.MOVE
var _map: MapManager
var _active := false
var _target: Node3D
var _overlay: StandardMaterial3D
var _original_overlays: Dictionary[MeshInstance3D,Material] = {}

func initialize(map: MapManager) -> void:
	_map = map
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_update_color()
	_map.building_controller.relocation_changed.connect(_on_relocation_changed)

func activate(active: bool) -> void:
	_active = active
	if not active:
		cancel_move()
		_clear_target()

func select_tool(tool: TOOL) -> void:
	if tool not in TOOL.values():
		return
	cancel_move()
	_clear_target()
	selected_tool = tool
	_update_color()
	changed.emit()

func is_moving() -> bool:
	return _map != null and is_instance_valid(_map.building_controller.relocating_building())

func hover_at(actor: Node3D) -> void:
	if not _active or is_moving() or not can_target(actor):
		actor = null
	if actor == _target:
		return
	_clear_target()
	_target = actor
	if _target != null:
		if _target is MeshInstance3D:
			_highlight_mesh(_target)
		for mesh: MeshInstance3D in _target.find_children("*","MeshInstance3D",true,false):
			_highlight_mesh(mesh)
	changed.emit()

func _highlight_mesh(mesh: MeshInstance3D) -> void:
	_original_overlays[mesh] = mesh.material_overlay
	mesh.material_overlay = _overlay

func use_at(point: Variant) -> bool:
	if not _active:
		return false
	if is_moving():
		if point is Vector3:
			return _map.building_controller.finish_relocation(point)
		return false
	if not can_target(_target):
		return false
	var actor := _target
	_clear_target()
	if selected_tool == TOOL.MOVE:
		return _map.building_controller.begin_relocation(actor)
	if actor is FenceRepresentation:
		return _map.fances_controller.demolish_span(actor.state.id)
	return _map.building_controller.demolish(actor)

func cancel_move() -> bool:
	if not is_moving():
		return false
	_map.building_controller.cancel_relocation()
	return true

func can_target(actor: Node3D) -> bool:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return false
	if actor is FenceRepresentation:
		return selected_tool == TOOL.REMOVE and not actor.preview_mode and actor.state != null
	if _map.building_controller.building_definition(actor) == null:
		return false
	return selected_tool == TOOL.REMOVE or not (actor is WorkshopController and actor.state == WorkshopController.STATE.RUINED)

func _on_relocation_changed() -> void:
	_clear_target()
	changed.emit()

func _update_color() -> void:
	if _overlay != null:
		_overlay.albedo_color = Color(0.3,0.7,1.0,0.4) if selected_tool == TOOL.MOVE else Color(1.0,0.16,0.08,0.45)

func _clear_target() -> void:
	for mesh: MeshInstance3D in _original_overlays:
		if is_instance_valid(mesh):
			mesh.material_overlay = _original_overlays[mesh]
	_original_overlays.clear()
	_target = null

func _exit_tree() -> void:
	_clear_target()
