class_name Creature
extends CharacterBody3D

@export var terrain_controller: TerrainController
@export var animation_player: AnimationPlayer
@export var species_id: StringName = &"tuftling"

var satiety := 100.0
var happiness := 75.0
var space_per_creature := 0.0
var companions := 0
var _wellbeing_elapsed := 1.0
var _happiness_target := 75.0
var breeding_cooldown := 0.0
var hold_height := 1.8
var _species: CreatureSpecies
var _navigation: CreatureNavigation
var _normal_collision_layer := 8

enum SEX { MALE, FEMALE }

var sex: SEX = SEX.MALE:
	set(value):
		sex = value
		if is_node_ready():
			_apply_sex_appearance()

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
var _airborne_elapsed := 0.0

func _ready() -> void:
	var host := get_parent() if get_parent() is MapManager else get_parent().get_node_or_null("Map")
	var database: GameDatabase = host.database if host is MapManager else load(GameDatabase.DEFAULT_PATH) as GameDatabase
	_species = database.creature(species_id)
	if _species == null:
		_species = CreatureSpecies.new()
	hold_height = _species.hold_height
	floor_snap_length = body_radius()*0.8
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(50.0)
	max_slides = 8
	add_to_group("creatures")
	var map := get_parent().get_node_or_null("Map") if get_parent() != null else null
	if map == null and get_parent() is MapManager:
		map = get_parent()
	if map != null:
		_navigation = map.navigation
		_navigation.register_actor(self)
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
	_apply_sex_appearance()

func _physics_process(delta: float) -> void:
	if _state == STATE.HELD:
		_update_held(delta)
		return
	_update_rotation(_rest_rotation, delta)
	velocity += get_gravity() * delta
	var impact_speed := maxf(0.0, -velocity.y)
	_apply_avoidance(delta)
	move_and_slide()
	if is_on_floor():
		_airborne_elapsed = 0.0
		if terrain_controller != null:
			_ground_offset = global_position.y - terrain_controller.surface_position(global_position).y
		if _state == STATE.FALLING:
			_state = STATE.LANDING
			_landing_elapsed = 0.0
			_landing_strength = clampf(impact_speed / 8.0, 0.15, 1.0)
			if not _play_animation(&"Land", 0.05):
				_finish_landing()
	else:
		_airborne_elapsed += delta
		if _state != STATE.FALLING and _airborne_elapsed >= 0.12:
			_state = STATE.FALLING
			_reset_model_scale()
			_play_animation(&"Fall")
	if _state == STATE.LANDING:
		_landing_elapsed += delta
		var duration := animation_player.get_animation(&"Land").length/maxf(absf(animation_player.speed_scale),0.01) if animation_player != null and animation_player.has_animation(&"Land") else 0.18
		if _landing_elapsed >= duration+0.15:
			_finish_landing()
		var squash := sin(minf(_landing_elapsed / 0.18, 1.0) * PI) * 0.1 * _landing_strength
		if _model != null:
			_model.scale = _model_scale * Vector3(1.0 + squash * 0.6, 1.0 - squash, 1.0 + squash * 0.6)

func begin_hold() -> void:
	if _state == STATE.HELD:
		return
	_normal_collision_mask = collision_mask
	_normal_collision_layer = collision_layer
	collision_mask = 0
	collision_layer = 0
	if _navigation != null:
		_navigation.release_place(self)
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

func release() -> bool:
	if _state != STATE.HELD:
		return true
	if _navigation != null:
		var point = _navigation.drop_position(self,global_position)
		if point == null:
			return false
		global_position = point
	collision_mask = _normal_collision_mask
	collision_layer = _normal_collision_layer
	velocity = Vector3.ZERO
	_state = STATE.FALLING
	_airborne_elapsed = 0.0
	_play_animation(&"Fall")
	return true

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

func species_data() -> CreatureSpecies:
	return _species

func inspection_bounds() -> AABB:
	var radius := body_radius()+0.12
	return AABB(Vector3(-radius,-radius,-radius),Vector3(radius*2.0,radius*2.0+0.65,radius*2.0))

func _process(delta: float) -> void:
	breeding_cooldown = maxf(0.0,breeding_cooldown-delta)
	if _species == null:
		return
	satiety = maxf(0.0,satiety-100.0/maxf(_species.satiety_seconds,1.0)*delta)
	if _state == STATE.HELD:
		return
	_wellbeing_elapsed += delta
	if _wellbeing_elapsed >= 1.0:
		_wellbeing_elapsed = 0.0
		_update_habitat_needs()
	happiness = move_toward(happiness,_happiness_target,100.0/maxf(_species.happiness_response_seconds,1.0)*delta)

func _update_habitat_needs() -> void:
	if _navigation == null:
		return
	var map := _navigation.get_parent() as MapManager
	if map == null:
		return
	var region := map.regions_controller.get_region_at(global_position)
	if region == null:
		return
	var population := 1
	companions = 0
	for other: Node in get_tree().get_nodes_in_group("creatures"):
		if not other is Creature or other == self or not other.blocks_space() or other.get_viewport() != get_viewport():
			continue
		if map.regions_controller.region_id_at(other.global_position) != region.id:
			continue
		population += 1
		if other.species_id == species_id and Vector2(other.global_position.x-global_position.x,other.global_position.z-global_position.z).length() <= _species.company_radius:
			companions += 1
	space_per_creature = maxf(0.0,region.area-region.water_area)/population
	var space_score := clampf(space_per_creature/maxf(_species.preferred_area,0.1),0.0,1.0)
	var company_score := 1.0 if companions > 0 else 0.0
	_happiness_target = clampf(satiety*0.45+space_score*35.0+company_score*20.0,0.0,100.0)

func work_efficiency() -> float:
	return lerpf(0.7,1.1,clampf(happiness/100.0,0.0,1.0))

func _apply_sex_appearance() -> void:
	var appearance := get_node_or_null("Model")
	if appearance == null:
		appearance = get_node_or_null("mossling_v1")
	if appearance != null and appearance.has_method("apply_sex"):
		appearance.apply_sex(sex)

func restore_satiety(amount: float) -> void:
	satiety = clampf(satiety+maxf(0.0,amount),0.0,100.0)

func available_for_breeding() -> bool:
	return _state == STATE.GROUNDED and not is_queued_for_deletion()

func interrupt_activity() -> void:
	if _navigation != null:
		_navigation.release_place(self)
	velocity.x = 0.0
	velocity.z = 0.0

func walk_direction(direction: Vector2, speed: float) -> void:
	velocity.x = direction.x*speed
	velocity.z = direction.y*speed
	_rest_rotation.y = atan2(direction.x,direction.y)
	_play_animation(movement_animation())

func face_point(point: Vector3, animation: StringName = &"Idle") -> void:
	var difference := Vector2(point.x-global_position.x,point.z-global_position.z)
	if difference.length_squared() > 0.001:
		_rest_rotation.y = atan2(difference.x,difference.y)
	_play_animation(animation)

func set_breeding_effect(active: bool) -> void:
	var hearts := get_node_or_null("Hearts") as CPUParticles3D
	if hearts != null:
		hearts.emitting = active

func body_radius() -> float:
	var collider := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null and (collider.shape is SphereShape3D or collider.shape is CapsuleShape3D):
		var current_basis := global_basis if is_inside_tree() else basis
		return collider.shape.radius*maxf(current_basis.x.length(),current_basis.z.length())
	return 0.5

func blocks_space() -> bool:
	return _state != STATE.HELD and not is_queued_for_deletion()

func movement_animation() -> StringName:
	return &"Walk"

func _apply_avoidance(delta: float) -> void:
	if _navigation == null or not _navigation.ready_for_paths:
		return
	var movement := _navigation.steer(self,Vector2(velocity.x,velocity.z),delta)
	velocity.x = movement.x
	velocity.z = movement.y
	if movement.length_squared() > 0.01:
		_rest_rotation.y = atan2(movement.x,movement.y)
