extends MeshInstance3D

var state: FenceSpanState
var data: FanceData
var start_point := Vector2.ZERO
var end_point := Vector2.ZERO
var preview_mode := false
var _pixels_per_unit := 32.0
var _geometry_key := 0
var _body: StaticBody3D
var _shape: CollisionShape3D

func configure(span: FenceSpanState, start: Vector2, end: Vector2, pixels_per_unit: float = 32.0) -> void:
	state = span
	data = span.data
	_pixels_per_unit = pixels_per_unit
	start_point = start
	end_point = end
	if start_point.x > end_point.x or (start_point.x == end_point.x and start_point.y > end_point.y):
		var swap := start_point
		start_point = end_point
		end_point = swap
	var center := (start_point + end_point) * 0.5
	position = Vector3(center.x, 0, center.y) / pixels_per_unit
	var seed_value := 0 if preview_mode else hash([start_point.snapped(Vector2(0.25, 0.25)), end_point.snapped(Vector2(0.25, 0.25)), data.id])
	var delta := end_point - start_point
	var key := hash([data.id, delta.snapped(Vector2(0.001, 0.001)), state.integrity(), seed_value, pixels_per_unit])
	if key != _geometry_key or mesh == null:
		mesh = FenceGeometry.build_span(data, start_point - center, end_point - center, state.integrity(), seed_value, pixels_per_unit)
		_geometry_key = key
	if not preview_mode:
		material_override = FenceGeometry.material()
		_update_collision()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if preview_mode else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func refresh() -> void:
	configure(state, start_point, end_point, _pixels_per_unit)

func _update_collision() -> void:
	if _body == null:
		_body = StaticBody3D.new()
		_body.collision_layer = 2
		_body.collision_mask = 0
		add_child(_body)
		_shape = CollisionShape3D.new()
		_shape.shape = BoxShape3D.new()
		_body.add_child(_shape)
	var delta := end_point - start_point
	(_shape.shape as BoxShape3D).size = Vector3(maxf(delta.length(), 0.1), data.height, data.thickness) / _pixels_per_unit
	_shape.position = Vector3(0, data.height * 0.5 / _pixels_per_unit, 0)
	_shape.rotation.y = -atan2(delta.y, delta.x)
