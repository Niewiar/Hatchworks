class_name HarvestTool
extends Node3D

@export var axe_scene: PackedScene
@export var pickaxe_scene: PackedScene
@export var rake_scene: PackedScene
@export var rake_contact := Vector3(0,0.8,-0.1)
@export var rake_teeth := PackedVector3Array()
@export var axe_contact := Vector3(-0.18,0.6,0)
@export var pickaxe_contact := Vector3(-0.28,0.65,0)

const CEL_SHADER = preload("res://code/creatures/creature_cel.gdshader")
const OUTLINE_SHADER = preload("res://code/creatures/pebblit_outline.gdshader")
const RAKE_TILT := 0.6981317
const RAKE_DEPTH := 0.012
const RAKE_HOVER := 0.10

var rake_path := PackedVector3Array()

var _active := false
var _mining := false
var _hoe := true
var _yaw := 0.0
var _swing := 0.0
var _motion: Tween
var _model: Node3D
var _strike_target := Vector3.ZERO
var _rake_initialized := false
var _rake_contacting := false
var _rake_head := Vector3.ZERO
var _rake_pointer := Vector3.ZERO

func _ready() -> void:
	select_hoe()

func _set_model(scene: PackedScene) -> void:
	if is_instance_valid(_model):
		_model.hide()
		_model.queue_free()
	_model = scene.instantiate() as Node3D
	add_child(_model)
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("width",0.0015)
	outline.set_shader_parameter("ink_color",Vector3(0.013,0.017,0.014))
	var meshes := _model.find_children("*","MeshInstance3D",true,false)
	if _model is MeshInstance3D:
		meshes.append(_model)
	for node in meshes:
		var mesh_node := node as MeshInstance3D
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh_node.mesh.get_surface_count():
			var original := mesh_node.mesh.surface_get_material(surface) as BaseMaterial3D
			if original == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = CEL_SHADER
			material.set_shader_parameter("base_color",original.albedo_color)
			material.set_shader_parameter("use_vertex_color",original.vertex_color_use_as_albedo)
			material.set_shader_parameter("use_texture",original.albedo_texture != null)
			if original.albedo_texture != null:
				material.set_shader_parameter("color_texture",original.albedo_texture)
			material.next_pass = outline
			mesh_node.set_surface_override_material(surface,material)

func reset_rake_contact() -> void:
	_rake_initialized = false
	_rake_contacting = false
	rake_path.clear()

func cancel() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	_swing = 0.0
	_active = false
	reset_rake_contact()
	hide()
	set_process(false)

func select_mining(mining: bool) -> void:
	cancel()
	_hoe = false
	_mining = mining
	_set_model(pickaxe_scene if mining else axe_scene)

func select_hoe() -> void:
	cancel()
	_hoe = true
	_set_model(rake_scene)

func _surface_up(point: Vector3, terrain: TerrainController) -> Vector3:
	var right := terrain.surface_position(point+Vector3.RIGHT*0.04)-terrain.surface_position(point-Vector3.RIGHT*0.04)
	var forward := terrain.surface_position(point+Vector3.BACK*0.04)-terrain.surface_position(point-Vector3.BACK*0.04)
	return forward.cross(right).normalized()

func _place_rake(point: Vector3, camera: Camera3D, terrain: TerrainController, contact: bool) -> void:
	var screen := camera.unproject_position(point)
	var ray_origin := camera.project_ray_origin(screen)
	var ray_direction := camera.project_ray_normal(screen)
	var up := _surface_up(point,terrain)
	var height := rake_contact.y*sin(RAKE_TILT)-rake_contact.z*cos(RAKE_TILT)
	var travel := (point.y+height-ray_origin.y)/ray_direction.y if absf(ray_direction.y)>0.0001 else ray_origin.distance_to(point)
	var grip := ray_origin+ray_direction*travel
	var direction := -camera.global_basis.z.slide(up).normalized()
	var head := _rake_head if _rake_initialized else grip+direction*rake_contact.length()
	var anchor := head
	var tool_basis := Basis.IDENTITY
	for iteration in 8:
		up = _surface_up(head,terrain)
		var toward_head := (anchor-grip).slide(up)
		if toward_head.length_squared()>0.000001:
			direction = toward_head.normalized()
		else:
			direction = direction.slide(up).normalized()
		var reach := rake_contact.y*cos(RAKE_TILT)+rake_contact.z*sin(RAKE_TILT)
		var shaft_direction := direction.rotated(up,atan2(rake_contact.x,reach))
		var shaft := shaft_direction*cos(RAKE_TILT)-up*sin(RAKE_TILT)
		var back := shaft_direction*sin(RAKE_TILT)+up*cos(RAKE_TILT)
		tool_basis = Basis(shaft.cross(back).normalized(),shaft,back).orthonormalized()
		var candidate := grip+tool_basis*rake_contact
		head = candidate
		var ground := terrain.surface_position(candidate)
		var clearance := (-RAKE_DEPTH if contact else RAKE_HOVER)*up.y
		var correction := ground.y+clearance-candidate.y
		for tooth in rake_teeth:
			var tip := grip+tool_basis*tooth
			correction = minf(correction,terrain.surface_position(tip).y+clearance-tip.y)
		if absf(ray_direction.y)>0.0001:
			travel += correction/ray_direction.y
		grip = ray_origin+ray_direction*travel
	global_transform = Transform3D(tool_basis,grip)
	_rake_head = global_transform*rake_contact
	_rake_initialized = true

func point_on_ground(point: Vector3, camera: Camera3D, terrain: TerrainController, contact: bool) -> Vector3:
	rake_path.clear()
	if _rake_initialized and point.is_equal_approx(_rake_pointer) and contact == _rake_contacting:
		return _rake_head
	var start := _rake_pointer if _rake_initialized else point
	var steps := clampi(ceili(start.distance_to(point)/maxf(0.025,rake_contact.length()*0.12)),1,128)
	for step in steps:
		_place_rake(start.lerp(point,float(step+1)/steps),camera,terrain,contact)
		rake_path.append(_rake_head)
	_rake_pointer = point
	_rake_contacting = contact
	return _rake_head

func point_at(point: Vector3, camera: Camera3D) -> void:
	_strike_target = point+Vector3.UP*(0.35 if _mining else 0.55)
	_yaw = camera.global_rotation.y
	_pose_swing()

func activate(active: bool) -> void:
	_active = active
	if active:
		show()
		set_process(not _hoe)
	elif _motion == null or not _motion.is_running():
		if _hoe:
			reset_rake_contact()
		hide()
		set_process(false)

func swing() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = create_tween()
	_motion.tween_property(self,"_swing",1.0,0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion.tween_property(self,"_swing",0.0,0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	show()
	set_process(true)

func _pose_swing() -> void:
	var impact_angle := 1.0 if _mining else 0.4
	var facing := Basis(Vector3.UP,_yaw)
	var impact := facing*Basis(Vector3.FORWARD,impact_angle)
	var tip := pickaxe_contact if _mining else axe_contact
	global_transform = Transform3D(facing*Basis(Vector3.FORWARD,lerpf(-0.55,impact_angle,_swing)),_strike_target-impact*tip)

func _process(_delta: float) -> void:
	_pose_swing()
	if not _active and (_motion == null or not _motion.is_running()):
		hide()
		set_process(false)
