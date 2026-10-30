class_name LooseEggController
extends Node3D

var definition: EggDefinition
var _map: Node3D
var _collected := false

func initialize(map: Node3D, egg: EggDefinition, point: Vector3) -> void:
	_map = map
	definition = egg
	global_position = map.terrain_controller.surface_position(point)
	var model := egg.model.instantiate() as Node3D
	model.process_mode = Node.PROCESS_MODE_DISABLED
	model.position.y = 0.37
	model.scale = Vector3.ONE*0.63
	add_child(model)
	$Name.text = egg.display_name+tr("\nClick to collect")
	add_to_group("loose_eggs")
	map.terrain_controller.height_changed.connect(_follow_ground)
	model.scale = Vector3.ONE*0.1
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(model,"scale",Vector3.ONE*0.63,0.35)

func collect() -> bool:
	if _collected or definition == null:
		return false
	_collected = true
	hide()
	_map.items.add(definition.id,1,global_position+Vector3.UP*0.37)
	queue_free()
	return true

func _follow_ground() -> void:
	global_position = _map.terrain_controller.surface_position(global_position)

func inspection_bounds() -> AABB:
	return AABB(Vector3(-0.38,0,-0.38),Vector3(0.76,0.85,0.76))

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and definition != null:
		$Name.text = definition.display_name+tr("\nClick to collect")
