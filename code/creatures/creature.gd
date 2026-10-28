class_name Creature
extends CharacterBody3D

@export var terrain_controller: TerrainController
@export var animation_player: AnimationPlayer
@export var species_id: StringName = &"mossling"

var hold_height := 1.8
var _species: CreatureSpecies

enum STATE { GROUNDED, HELD, FALLING, LANDING }


var _state: STATE = STATE.GROUNDED
var _ground_offset := 0.5
var _hold_target := Vector3.ZERO
var _rest_rotation := Vector3.ZERO
var _normal_collision_mask := 1
var _model: Node3D
var _model_scale := Vector3.ONE
var _landing_elapsed := 0.0
var _landing_strength := 0.0

func _ready() -> void:
	var database := load(GameDatabase.DEFAULT_PATH) as GameDatabase
	_species = database.creature(species_id)
	if _species == null:
		_species = CreatureSpecies.new()
	hold_height = _species.hold_height
	_rest_rotation = rotation
	if terrain_controller != null:
		_ground_offset = global_position.y - terrain_controller.surface_position(global_position).y
		terrain_controller.height_changed.connect(_follow_ground)
	if animation_player != null:
		_model = animation_player.get_node(animation_player.root_node) as Node3D
		if _model != null:
			_model_scale = _model.scale
		animation_player.animation_finished.connect(_on_animation_finished)
		_play_animation(&"Idle")

func _physics_process(delta: float) -> void:
	if _state == STATE.HELD:
		_update_held(delta)
		return
	_update_rotation(_rest_rotation, delta)
	velocity += get_gravity() * delta
	var impact_speed := maxf(0.0, -velocity.y)
	move_and_slide()
	if is_on_floor():
		if terrain_controller != null:
			_ground_offset = global_position.y - terrain_controller.surface_position(global_position).y
		if _state == STATE.FALLING:
			_state = STATE.LANDING
			_landing_elapsed = 0.0
			_landing_strength = clampf(impact_speed / 8.0, 0.15, 1.0)
			if not _play_animation(&"Land", 0.05):
				_finish_landing()
	elif _state != STATE.FALLING:
		_state = STATE.FALLING
		_reset_model_scale()
		_play_animation(&"Fall")
	if _state == STATE.LANDING:
		_landing_elapsed += delta
		var squash := sin(minf(_landing_elapsed / 0.18, 1.0) * PI) * 0.1 * _landing_strength
		if _model != null:
			_model.scale = _model_scale * Vector3(1.0 + squash * 0.6, 1.0 - squash, 1.0 + squash * 0.6)

func begin_hold() -> void:
	if _state == STATE.HELD:
		return
	_normal_collision_mask = collision_mask
	collision_mask = 0
	velocity = Vector3.ZERO
	_hold_target = global_position
	_rest_rotation = Vector3(0.0, rotation.y, 0.0)
	_state = STATE.HELD
	_reset_model_scale()
	_play_animation(&"HeldIdle")

func set_hold_target(target: Vector3) -> void:
	_hold_target = target

func get_hold_height() -> float:
	return _ground_offset + hold_height

func release() -> void:
	if _state != STATE.HELD:
		return
	collision_mask = _normal_collision_mask
	velocity = Vector3.ZERO
	_state = STATE.FALLING
	_play_animation(&"Fall")

func _update_held(delta: float) -> void:
	var previous := global_position
	global_position = global_position.lerp(_hold_target, 1.0 - exp(-_species.follow_speed * delta))
	var motion := Basis(Vector3.UP, _rest_rotation.y).inverse() * ((global_position - previous) / delta)
	var target_rotation := _rest_rotation + Vector3(
		clampf(motion.z * 0.045, -_species.maximum_tilt, _species.maximum_tilt),
		clampf(-motion.x * 0.012, -0.1, 0.1),
		clampf(-motion.x * 0.045, -_species.maximum_tilt, _species.maximum_tilt)
	)
	_update_rotation(target_rotation, delta)

func _update_rotation(target: Vector3, delta: float) -> void:
	var weight := 1.0 - exp(-_species.rotation_speed * delta)
	rotation = Vector3(
		lerp_angle(rotation.x, target.x, weight),
		lerp_angle(rotation.y, target.y, weight),
		lerp_angle(rotation.z, target.z, weight)
	)

func _follow_ground() -> void:
	if _state == STATE.GROUNDED or _state == STATE.LANDING:
		global_position.y = terrain_controller.surface_position(global_position).y + _ground_offset

func _play_animation(name: StringName, blend: float = 0.12) -> bool:
	if animation_player == null or not animation_player.has_animation(name):
		return false
	if animation_player.current_animation != name:
		animation_player.play(name, blend)
	return true

func _on_animation_finished(name: StringName) -> void:
	if name == &"Land" and _state == STATE.LANDING:
		_finish_landing()

func _finish_landing() -> void:
	_state = STATE.GROUNDED
	_reset_model_scale()
	_play_animation(&"Idle")

func _reset_model_scale() -> void:
	if _model != null:
		_model.scale = _model_scale
