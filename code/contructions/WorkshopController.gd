class_name WorkshopController
extends Node3D

signal changed

enum STATE { EMPTY, WORKING, READY, RUINED }

var state: STATE = STATE.EMPTY
var current_egg: EggDefinition
var remaining := 0.0
var _map: Node3D
var _egg_visual: Node3D
var _phase := 0.0
var _player: AnimationPlayer
var _anchor: Node3D
var _anchor_rest := Vector3.ZERO
var _socket_rest := Vector3.ZERO
var _collected_egg: Node3D
var _collect_elapsed := 0.0
var _animation: StringName = &""

func _ready() -> void:
	BuildingAppearance.configure(self)
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_anchor = find_child("EggSocket", true, false) as Node3D
	_socket_rest = %Socket.position
	if _anchor != null:
		_anchor_rest = to_local(_anchor.global_position)
	if _player != null:
		_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_update_visuals()

func initialize(map: Node3D) -> void:
	_map = map
	global_position = map.terrain_controller.surface_position(global_position)
	_update_visuals()

func select_egg(egg: EggDefinition) -> void:
	if _map.building_controller.relocating_building() == self or state != STATE.EMPTY or egg == null or not _map.discoveries.knows(egg.id):
		return
	current_egg = egg
	changed.emit()

func crafting_error() -> String:
	if state == STATE.RUINED:
		return tr("This workshop has been destroyed.")
	if current_egg == null:
		return tr("Discover an egg recipe to begin.")
	if not _map.discoveries.knows(current_egg.id):
		return tr("This egg recipe has not been discovered.")
	if not _map.science.can_afford(current_egg.science_cost):
		return tr("Not enough science. Discover new recipes or a species' first actions.")
	if not _map.inventory.can_afford_costs(current_egg.costs()):
		return tr("Not enough materials.")
	return ""

func start_crafting() -> bool:
	if _map.building_controller.relocating_building() == self or state != STATE.EMPTY or not crafting_error().is_empty():
		return false
	_finish_collection()
	state = STATE.WORKING
	SoundEffects.play_at(&"machine_start",global_position,self)
	remaining = current_egg.crafting_seconds
	_map.science.spend(current_egg.science_cost)
	_map.inventory.spend_costs(current_egg.costs())
	_phase = 0.0
	_update_visuals()
	changed.emit()
	return true

func collect_egg(origin: Variant = null) -> bool:
	if _map.building_controller.relocating_building() == self or state != STATE.READY:
		return false
	state = STATE.EMPTY
	_map.items.add(current_egg.id,1,origin if origin != null else %Socket.global_position)
	_collected_egg = _egg_visual
	_egg_visual = null
	_collect_elapsed = 0.0
	_update_visuals()
	changed.emit()
	return true

func _process(delta: float) -> void:
	if _map == null:
		return
	_phase += delta
	if state == STATE.RUINED:
		_update_visuals(delta)
		if _phase >= 2.6:
			set_process(false)
		return
	if is_instance_valid(_collected_egg):
		_collect_elapsed += delta
		if _collect_elapsed >= 2.0:
			_finish_collection()
	if state == STATE.WORKING:
		remaining = maxf(0.0,remaining-delta)
		if remaining <= 0.0:
			state = STATE.READY
			_phase = 0.0
			SoundEffects.play_at(&"machine_ready",global_position,self)
			_egg_visual = current_egg.model.instantiate() as Node3D
			_egg_visual.process_mode = Node.PROCESS_MODE_DISABLED
			_egg_visual.scale = Vector3.ONE*0.63
			%Socket.add_child(_egg_visual)
			changed.emit()
	_map.noise.set_source(self,0.7,6.0,state == STATE.WORKING)
	SoundEffects.set_machine_loop(self,&"workshop_loop",state == STATE.WORKING)
	_update_visuals(delta)

func _update_visuals(delta: float = 0.0) -> void:
	if not is_node_ready():
		return
	var clip: StringName = &"Idle"
	var time := 0.0
	if state == STATE.RUINED:
		clip = &"Destroy" if _phase < 2.6 else &"Ruins"
		time = minf(_phase,2.6) if clip == &"Destroy" else 0.0
	elif state == STATE.WORKING and current_egg != null:
		clip = &"Working"
		time = clampf(1.0-remaining/current_egg.crafting_seconds,0.0,1.0)*12.0
	elif state == STATE.READY:
		clip = &"Ready"
		time = minf(_phase,4.0)
	elif is_instance_valid(_collected_egg):
		clip = &"Collect"
		time = minf(_collect_elapsed,2.0)
	if _player != null and _player.has_animation(clip):
		if _animation != clip:
			_player.play(clip,0.16 if clip == &"Destroy" else 0.0)
			_animation = clip
		if clip == &"Destroy":
			_player.advance(delta)
		_player.seek(time,true)
	%Socket.position = _socket_rest
	if _anchor != null:
		%Socket.position += to_local(_anchor.global_position)-_anchor_rest
	%Socket.visible = state == STATE.READY or is_instance_valid(_collected_egg)

func destroy() -> void:
	if state == STATE.RUINED:
		return
	state = STATE.RUINED
	_phase = 0.0
	_stop_production()
	_update_visuals()
	changed.emit()

func restore_ruins() -> void:
	state = STATE.RUINED
	_phase = 2.6
	_stop_production()
	_update_visuals()
	set_process(false)

func _stop_production() -> void:
	_finish_collection()
	if is_instance_valid(_egg_visual):
		_egg_visual.queue_free()
	_egg_visual = null
	current_egg = null
	remaining = 0.0
	SoundEffects.set_machine_loop(self,&"workshop_loop",false)
	if _map != null:
		_map.noise.set_source(self,0.7,6.0,false)
	var shape := CylinderShape3D.new()
	shape.radius = 1.5
	shape.height = 0.9
	$Body/CollisionShape3D.shape = shape
	$Body/CollisionShape3D.position.y = 0.45

func _finish_collection() -> void:
	if is_instance_valid(_collected_egg):
		_collected_egg.queue_free()
	_collected_egg = null
	_collect_elapsed = 0.0

func inspection_bounds() -> AABB:
	if state == STATE.RUINED:
		return AABB(Vector3(-2.01,0,-1.12),Vector3(4.06,1.2,2.58))
	return AABB(Vector3(-1.747,0,-1.119),Vector3(3.494,2.63,2.374))
