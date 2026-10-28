class_name HarvestTool
extends MeshInstance3D

@export var axe_mesh: Mesh
@export var pickaxe_mesh: Mesh

var _active := false
var _mining := false
var _yaw := 0.0
var _swing := 0.0
var _motion: Tween

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	select_mining(false)

func cancel() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	_swing = 0.0
	_active = false
	hide()
	set_process(false)

func select_mining(mining: bool) -> void:
	cancel()
	_mining = mining
	mesh = pickaxe_mesh if mining else axe_mesh

func point_at(point: Vector3, camera: Camera3D) -> void:
	global_position = point+camera.global_basis.x.normalized()*(0.68 if _mining else 0.48)+Vector3.UP*(0.35 if _mining else 0.1)
	_yaw = camera.global_rotation.y

func activate(active: bool) -> void:
	_active = active
	if active:
		show()
		set_process(true)
	elif _motion == null or not _motion.is_running():
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

func _process(_delta: float) -> void:
	var impact_angle := 1.0 if _mining else 0.2
	global_rotation = Vector3(0,_yaw,lerpf(-0.55,impact_angle,_swing))
	if not _mining:
		rotate_object_local(Vector3.UP,PI)
	if not _active and (_motion == null or not _motion.is_running()):
		hide()
		set_process(false)
