class_name FencePostView
extends MeshInstance3D

var state: FencePostState
var preview_mode := false
var _pixels_per_unit := 32.0
var _geometry_key := 0
var _highlighted := false
var _body: StaticBody3D
var _shape: CollisionShape3D

func configure(post: FencePostState, pixels_per_unit: float = 32.0, post_rotation: float = 0.0) -> void:
	state = post
	_pixels_per_unit = pixels_per_unit
	position = Vector3(post.position.x, 0, post.position.y) / pixels_per_unit
	rotation.y = post_rotation
	var seed_value := 0 if preview_mode else hash(post.position.snapped(Vector2(0.25, 0.25)))
	var key := hash([post.data.id, post.integrity(), seed_value, post.data.height, post.data.post_width, post.data.thickness, pixels_per_unit])
	if key != _geometry_key or mesh == null:
		mesh = FenceGeometry.build_post(post.data, post.integrity(), seed_value, pixels_per_unit)
		_geometry_key = key
	if not preview_mode:
		material_override = FenceGeometry.material(_highlighted)
		_update_collision()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if preview_mode else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func refresh() -> void:
	configure(state, _pixels_per_unit, rotation.y)

func set_highlighted(highlighted: bool) -> void:
	_highlighted = highlighted
	if not preview_mode:
		material_override = FenceGeometry.material(highlighted)

func _update_collision() -> void:
	if _body == null:
		_body = StaticBody3D.new()
		_body.collision_layer = 2
		_body.collision_mask = 0
		add_child(_body)
		_shape = CollisionShape3D.new()
		_shape.shape = BoxShape3D.new()
		_body.add_child(_shape)
	_body.set_meta("fence_post_id", state.id)
	var height := state.data.height + 4
	(_shape.shape as BoxShape3D).size = Vector3(state.data.post_width + 4, height, state.data.thickness * 1.15 + 3) / _pixels_per_unit
	_shape.position = Vector3(0, height * 0.5 / _pixels_per_unit, 0)
