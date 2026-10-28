class_name HarvestableDeposit
extends MeshInstance3D

signal depleted(deposit: HarvestableDeposit)

enum KIND { TREE, ROCK }

@export var kind: KIND = KIND.TREE
var resource_kind := 9
var hits_required := 4
var yield_amount := 16

@onready var _body: StaticBody3D = $Body
@onready var _collision: CollisionShape3D = $Body/CollisionShape3D
@onready var _progress: Label3D = $Progress

var exhausted := false
var _hits := 0
var _rest_rotation := Vector3.ZERO
var _reaction: Tween

func configure(source: Mesh, surface: Material, yaw: float, trunk_radius: float = 0.12, trunk_height: float = 1.3) -> void:
	mesh = source
	material_override = surface
	rotation = Vector3(0,yaw,0)
	_rest_rotation = rotation
	var shape := CylinderShape3D.new()
	shape.radius = trunk_radius
	shape.height = trunk_height
	_collision.shape = shape
	_collision.position.y = trunk_height*0.5
	_progress.position.y = 0.8 if kind == KIND.TREE else source.get_aabb().end.y+0.25

func set_growth(growth: float, base_scale: float) -> void:
	if exhausted:
		return
	visible = growth >= 0.025
	scale = Vector3.ONE*maxf(0.02,growth*base_scale)
	_body.collision_layer = 2 if growth >= 0.6 else 0

func hover_distance(screen: Vector2, camera: Camera3D) -> float:
	if exhausted or not is_visible_in_tree() or _body.collision_layer == 0 or camera.is_position_behind(global_position):
		return INF
	var base := camera.unproject_position(global_position)
	var top := camera.unproject_position(global_position+Vector3.UP*(0.4 if kind == KIND.TREE else 0.35))
	var nearest := Geometry2D.get_closest_point_to_segment(screen,base,top)
	var side := camera.unproject_position(global_position+camera.global_basis.x.normalized()*(0.23 if kind == KIND.TREE else 0.6)*scale.x)
	var radius := clampf(base.distance_to(side)+6.0,12.0,48.0)
	return screen.distance_squared_to(nearest)/(radius*radius)

func set_hovered(active: bool) -> void:
	_progress.visible = active and not exhausted and _hits > 0

func strike() -> int:
	if exhausted or not visible:
		return 0
	_hits += 1
	_progress.text = "%d / %d" % [_hits,hits_required]
	_progress.show()
	if _reaction != null and _reaction.is_valid():
		_reaction.kill()
	_reaction = create_tween()
	if _hits < hits_required:
		_reaction.tween_property(self,"rotation",_rest_rotation+Vector3(0.035,0,0.065),0.055)
		_reaction.tween_property(self,"rotation",_rest_rotation-Vector3(0.015,0,0.03),0.08)
		_reaction.tween_property(self,"rotation",_rest_rotation,0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return 0
	exhausted = true
	_body.set_deferred("collision_layer",0)
	_progress.hide()
	depleted.emit(self)
	if kind == KIND.TREE:
		_reaction.tween_property(self,"rotation",_rest_rotation+Vector3(1.45,0,0.15),0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_reaction.tween_property(self,"scale",Vector3.ONE*0.02,0.2)
	else:
		_reaction.tween_property(self,"scale",scale*0.82,0.08)
		_reaction.tween_property(self,"scale",Vector3.ONE*0.02,0.24)
	_reaction.tween_callback(queue_free)
	return yield_amount
