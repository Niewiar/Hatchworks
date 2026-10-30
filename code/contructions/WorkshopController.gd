class_name WorkshopController
extends MeshInstance3D

signal changed

enum STATE { EMPTY, WORKING, READY }

var state: STATE = STATE.EMPTY
var current_egg: EggDefinition
var remaining := 0.0
var _map: Node3D
var _egg_visual: Node3D
var _phase := 0.0

func initialize(map: Node3D) -> void:
	_map = map
	global_position = map.terrain_controller.surface_position(global_position)
	_update_visuals()

func select_egg(egg: EggDefinition) -> void:
	if state != STATE.EMPTY or egg == null or not _map.discoveries.knows(egg.id):
		return
	current_egg = egg
	changed.emit()

func crafting_error() -> String:
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
	if state != STATE.EMPTY or not crafting_error().is_empty():
		return false
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
	if state != STATE.READY:
		return false
	state = STATE.EMPTY
	_map.items.add(current_egg.id,1,origin if origin != null else %Socket.global_position)
	if is_instance_valid(_egg_visual):
		%Socket.remove_child(_egg_visual)
		_egg_visual.queue_free()
	_egg_visual = null
	_update_visuals()
	changed.emit()
	return true

func _process(delta: float) -> void:
	if _map == null:
		return
	_phase += delta
	if state == STATE.WORKING:
		remaining = maxf(0.0,remaining-delta)
		if remaining <= 0.0:
			state = STATE.READY
			SoundEffects.play_at(&"machine_ready",global_position,self)
			_egg_visual = current_egg.model.instantiate() as Node3D
			_egg_visual.process_mode = Node.PROCESS_MODE_DISABLED
			_egg_visual.scale = Vector3.ONE*0.63
			%Socket.add_child(_egg_visual)
			changed.emit()
	_map.noise.set_source(self,0.7,6.0,state == STATE.WORKING)
	SoundEffects.set_machine_loop(self,&"workshop_loop",state == STATE.WORKING)
	_update_visuals()

func _update_visuals() -> void:
	var working := state == STATE.WORKING
	var progress := 1.0-remaining/current_egg.crafting_seconds if working else 0.0
	var turning := smoothstep(0.0,0.16,progress)
	%Wheel.rotation.y = progress*TAU*4.0 if working else 0.0
	%Screw.rotation.y = %Wheel.rotation.y
	%Rotor.rotation.y = progress*TAU if working else 0.0
	var press_depth := smoothstep(0.25,0.65,progress)*(1.0-smoothstep(0.86,1.0,progress))
	%Press.position.y = 1.88-press_depth*0.55
	%Pages.rotation.z = sin(turning*PI)*1.2 if working else 0.0
	for index in %Bowls.get_child_count():
		var bowl := %Bowls.get_child(index) as Node3D
		bowl.position.y = 0.63+(sin(_phase*5.0+index)*0.018 if working and progress > 0.15 and progress < 0.55 else 0.0)
	%Socket.visible = state == STATE.READY
	%Runes.visible = working or state == STATE.READY

func inspection_bounds() -> AABB:
	return AABB(Vector3(-1.6,0,-1.55),Vector3(3.2,2.85,3.1))
