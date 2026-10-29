class_name EggShell
extends Node3D

signal hatching_finished

const DURATION := 4.2

var reveal_progress: float:
	get:
		return clampf((_elapsed-1.95)/0.95,0.0,1.0)

var _fragments: Array[RigidBody3D] = []
var _elapsed := 0.0
var _hatching := false
var _rest := Transform3D.IDENTITY
var _crack_material: ShaderMaterial

func _ready() -> void:
	for child in get_children():
		if child is RigidBody3D:
			_fragments.append(child)
	_crack_material = $Cracks.material_override.duplicate() as ShaderMaterial
	$Cracks.material_override = _crack_material
	$Cracks.hide()
	set_physics_process(false)

func start_hatching() -> void:
	if _hatching:
		return
	_hatching = true
	_elapsed = 0.0
	_rest = transform
	_crack_material.set_shader_parameter("progress",0.0)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 1.45:
		var strength := smoothstep(0.0,1.4,_elapsed)
		transform = _rest
		rotation.z += sin(_elapsed*23.0)*0.028*strength
		rotation.x += sin(_elapsed*17.0)*0.017*strength
		position.y += absf(sin(_elapsed*12.0))*0.012*strength
	else:
		transform = _rest
	$Cracks.visible = _elapsed > 0.5 and _elapsed < 1.5
	_crack_material.set_shader_parameter("progress",clampf((_elapsed-0.5)/0.95,0.0,1.0))
	for index in _fragments.size():
		var body := _fragments[index]
		if not body.freeze or _elapsed < float(body.get_meta("release_time")):
			continue
		var outward := Vector2(body.position.x,body.position.z).normalized()
		var speed := 1.0+float((index*17)%9)*0.07
		body.collision_layer = 2
		body.collision_mask = 1
		body.freeze = false
		body.linear_velocity = global_basis*Vector3(outward.x*speed,0.65+maxf(body.position.y,0.0)*1.2,outward.y*speed)
		body.angular_velocity = Vector3(sin(index*7.1),cos(index*4.7),sin(index*3.9))*3.5
	if _elapsed >= DURATION:
		set_physics_process(false)
		hatching_finished.emit()
