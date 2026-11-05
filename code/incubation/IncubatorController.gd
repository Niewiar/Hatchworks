class_name IncubatorController
extends Node3D

signal changed
signal hatch_requested(incubator: IncubatorController)

enum STATE { EMPTY, INCUBATING, READY, PRESENTING }

var state: STATE = STATE.EMPTY
var current_egg: EggDefinition
var remaining := 0.0
var pending_sex: Creature.SEX = Creature.SEX.MALE
var _sex_assigned := false
var _map: Node3D
var _phase := 0.0
var _egg_visual: Node3D
var _warm_materials: Array[ShaderMaterial] = []
var _socket_rest := Vector3.ZERO

func _ready() -> void:
	_warm_materials = BuildingAppearance.configure(self)

func initialize(map: Node3D) -> void:
	_map = map
	_socket_rest = $EggSocket.position
	global_position = map.terrain_controller.surface_position(global_position)

func select_egg(egg: EggDefinition) -> void:
	if _map.building_controller.relocating_building() == self or state != STATE.EMPTY or (egg != null and _map.items.amount(egg.id) < 1):
		return
	current_egg = egg
	if is_instance_valid(_egg_visual):
		_egg_visual.queue_free()
	_egg_visual = null
	if egg != null and egg.model != null:
		_egg_visual = egg.model.instantiate()
		$EggSocket.add_child(_egg_visual)
	$EggSocket.hide()
	changed.emit()

func start_incubation() -> bool:
	if _map.building_controller.relocating_building() == self or state != STATE.EMPTY or current_egg == null or not _map.items.spend(current_egg.id):
		return false
	_sex_assigned = false
	remaining = current_egg.incubation_seconds
	state = STATE.INCUBATING
	SoundEffects.play_at(&"machine_start",global_position,self)
	$EggSocket.show()
	changed.emit()
	return true

func request_hatch() -> bool:
	if _map.building_controller.relocating_building() == self or state != STATE.READY:
		return false
	if not _sex_assigned:
		pending_sex = _choose_sex()
		_sex_assigned = true
	state = STATE.PRESENTING
	changed.emit()
	hatch_requested.emit(self)
	return true

func _choose_sex() -> Creature.SEX:
	var male_weight := 1
	var female_weight := 1
	if _map != null and current_egg != null:
		for node in get_tree().get_nodes_in_group("creatures"):
			if not node is Creature or node.is_queued_for_deletion() or node.species_id != current_egg.creature_id:
				continue
			if node.terrain_controller != _map.terrain_controller or node.get_viewport() != _map.get_viewport():
				continue
			if node.sex == Creature.SEX.MALE:
				female_weight += 1
			elif node.sex == Creature.SEX.FEMALE:
				male_weight += 1
	return Creature.SEX.MALE if randi_range(1,male_weight+female_weight) <= male_weight else Creature.SEX.FEMALE

func accept_hatch(origin: Variant = null) -> Creature:
	if _map.building_controller.relocating_building() == self or state != STATE.PRESENTING:
		return null
	var data: CreatureSpecies = _map.database.creature(current_egg.creature_id)
	if data == null or data.scene == null:
		return null
	var creature := data.scene.instantiate() as Creature
	if creature == null:
		return null
	creature.sex = pending_sex
	creature.prepare_appearance()
	var point = _map.navigation.spawn_position(global_position,creature.body_radius())
	if point == null:
		creature.free()
		return null
	creature.species_id = data.id
	creature.terrain_controller = _map.terrain_controller
	creature.position = _map.get_parent().to_local(point)
	_map.get_parent().add_child(creature)
	_map.discoveries.discover(data.id)
	_map.science.observe(data.id,&"hatch",origin if origin != null else global_position)
	current_egg = null
	state = STATE.EMPTY
	remaining = 0
	$EggSocket.hide()
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
			SoundEffects.play_at(&"machine_ready",global_position,self)
			changed.emit()
	_map.noise.set_source(self,0.3,4.0,state == STATE.INCUBATING)
	SoundEffects.set_machine_loop(self,&"incubator_loop",state == STATE.INCUBATING)
	var warmth := 0.38+sin(_phase*3.0)*0.14 if state == STATE.READY else 0.12+sin(_phase*2.0)*0.06 if state == STATE.INCUBATING else 0.03
	for material in _warm_materials:
		material.set_shader_parameter("warmth", warmth)
	$WarmLight.light_energy = warmth*1.2

func inspection_bounds() -> AABB:
	return AABB(Vector3(-1.26,0,-1.34),Vector3(2.50,2.08,2.68))

func cancel_hatch() -> bool:
	if state != STATE.PRESENTING:
		return false
	state = STATE.READY
	changed.emit()
	return true
