class_name IncubatorController
extends MeshInstance3D

signal changed
signal hatch_requested(incubator: IncubatorController)

enum STATE { EMPTY, INCUBATING, READY, PRESENTING }

var state: STATE = STATE.EMPTY
var current_egg: EggDefinition
var remaining := 0.0
var pending_sex: Creature.SEX = Creature.SEX.MALE
var _map: Node3D
var _phase := 0.0
var _egg_visual: Node3D
var _glow: StandardMaterial3D
var _socket_rest := Vector3.ZERO

func initialize(map: Node3D) -> void:
	_map = map
	_socket_rest = $EggSocket.position
	global_position = map.terrain_controller.surface_position(global_position)
	_glow = $Glow.material_override.duplicate() as StandardMaterial3D
	$Glow.material_override = _glow
	_update_label()

func select_egg(egg: EggDefinition) -> void:
	if state != STATE.EMPTY or (egg != null and _map.items.amount(egg.id) < 1):
		return
	current_egg = egg
	if is_instance_valid(_egg_visual):
		_egg_visual.queue_free()
	_egg_visual = null
	if egg != null and egg.model != null:
		_egg_visual = egg.model.instantiate()
		$EggSocket.add_child(_egg_visual)
	$EggSocket.hide()
	_update_label()
	changed.emit()

func start_incubation() -> bool:
	if state != STATE.EMPTY or current_egg == null or not _map.items.spend(current_egg.id):
		return false
	remaining = current_egg.incubation_seconds
	state = STATE.INCUBATING
	$EggSocket.show()
	_update_label()
	changed.emit()
	return true

func request_hatch() -> bool:
	if state != STATE.READY:
		return false
	pending_sex = Creature.SEX.MALE if randi()%2 == 0 else Creature.SEX.FEMALE
	state = STATE.PRESENTING
	_update_label()
	changed.emit()
	hatch_requested.emit(self)
	return true

func accept_hatch() -> Creature:
	if state != STATE.PRESENTING:
		return null
	var point = _map.navigation.spawn_position(global_position)
	if point == null:
		return null
	var data: CreatureSpecies = _map.database.creature(current_egg.creature_id)
	if data == null or data.scene == null:
		return null
	var creature := data.scene.instantiate() as Creature
	if creature == null:
		return null
	creature.species_id = data.id
	creature.sex = pending_sex
	creature.terrain_controller = _map.terrain_controller
	creature.position = _map.get_parent().to_local(point)
	_map.get_parent().add_child(creature)
	current_egg = null
	state = STATE.EMPTY
	remaining = 0
	$EggSocket.hide()
	_update_label()
	changed.emit()
	return creature

func _process(delta: float) -> void:
	_phase += delta
	if _map == null:
		return
	if state == STATE.INCUBATING:
		remaining = maxf(0.0,remaining-delta)
		$EggSocket.rotation.y += delta*0.3
		$EggSocket.rotation.z = sin(_phase*3.1)*0.035
		$EggSocket.position.y = _socket_rest.y+sin(_phase*2.0)*0.012
		if remaining <= 0:
			state = STATE.READY
			changed.emit()
		_update_label()
	_glow.emission_energy_multiplier = 1.5+sin(_phase*3.0)*0.7 if state == STATE.READY else 0.45+sin(_phase*2.0)*0.2

func _update_label() -> void:
	match state:
		STATE.EMPTY: $Timer.text = "Incubator\nEmpty" if current_egg == null else "Incubator\nChoose an egg"
		STATE.INCUBATING: $Timer.text = "%02d:%02d" % [ceili(remaining)/60,ceili(remaining)%60]
		STATE.READY: $Timer.text = "Ready to hatch"
		STATE.PRESENTING: $Timer.text = "Hatching…"

func inspection_bounds() -> AABB:
	return AABB(Vector3(-1.27,0,-1.05),Vector3(2.36,2.45,2.13))
