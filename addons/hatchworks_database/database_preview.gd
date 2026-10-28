@tool
extends SubViewportContainer

@onready var _world: Node3D = $Viewport/Models
@onready var _camera: Camera3D = $Viewport/Camera

func show_entry(entry: Resource) -> void:
	for child in _world.get_children():
		_world.remove_child(child)
		child.queue_free()
	$Icon.hide()
	$Icon.texture = null
	if entry is ResourceDefinition or entry is FanceData:
		$Icon.texture = entry.icon if entry is ResourceDefinition else entry.ui_icon
		$Icon.show()
	var bounds := AABB()
	if entry is CreatureSpecies and entry.scene != null:
		var model: Node = entry.scene.instantiate()
		if not model is Node3D:
			model.free()
			return
		model.process_mode = Node.PROCESS_MODE_DISABLED
		_world.add_child(model)
		bounds = _bounds(model as Node3D)
	elif entry is FloraSpecies or entry is DepositDefinition:
		if not entry.variants.is_empty() and entry.variants[0] != null:
			var mesh := MeshInstance3D.new()
			mesh.mesh = entry.variants[0]
			if entry is DepositDefinition:
				mesh.material_override = entry.material
			else:
				var material := load("res://resources/flora/foliage_material.tres").duplicate() as ShaderMaterial
				material.set_shader_parameter("follow_ground",false)
				mesh.material_override = material
			_world.add_child(mesh)
			bounds = mesh.get_aabb()
	if bounds.size.length() < 0.001:
		return
	var focus := bounds.get_center()
	_camera.position = focus+Vector3(-1.3,0.9,1.7).normalized()*maxf(bounds.size.length(),1.0)*1.7
	_camera.look_at(focus)
	_camera.size = maxf(maxf(bounds.size.x,bounds.size.z)*1.5,bounds.size.y*1.5)

func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	if node is MeshInstance3D and node.mesh != null:
		result = _world.global_transform.affine_inverse()*node.global_transform*node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var box := _bounds(child)
			if box.size.length() > 0.001:
				result = box if result.size.length() < 0.001 else result.merge(box)
	return result
