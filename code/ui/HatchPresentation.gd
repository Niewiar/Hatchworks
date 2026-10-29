class_name HatchPresentation
extends Control

@export var map_manager: Node3D
@export var tooltip_controller: TooltipController

var _incubator: IncubatorController
var _egg: EggShell
var _creature: Node3D
var _accepted := false
var _ready_to_accept := false

func _ready() -> void:
	hide()
	set_process(false)
	%Accept.pressed.connect(_accept)

func present(incubator: IncubatorController) -> void:
	_incubator = incubator
	_accepted = false
	_ready_to_accept = false
	for child in %Models.get_children():
		%Models.remove_child(child)
		child.queue_free()
	_egg = incubator.current_egg.model.instantiate() as EggShell
	_egg.position.y = 0.58
	%Models.add_child(_egg)
	_egg.hatching_finished.connect(_show_card)
	var species: CreatureSpecies = map_manager.database.creature(incubator.current_egg.creature_id)
	_creature = species.scene.instantiate() as Node3D
	_creature.set_script(null)
	_creature.process_mode = Node.PROCESS_MODE_DISABLED
	if _creature is CollisionObject3D:
		_creature.collision_layer = 0
		_creature.collision_mask = 0
	%Models.add_child(_creature)
	_creature.position.y = 0.55
	_creature.hide()
	%CreatureCard.configure(species,incubator.pending_sex,map_manager.database,tooltip_controller)
	%Card.hide()
	%Accept.disabled = true
	%Hint.text = "A new life is stirring…"
	modulate.a = 0.0
	show()
	create_tween().tween_property(self,"modulate:a",1.0,0.25)
	_egg.start_hatching()
	set_process(true)
	map_manager.set_modal(true)

func _process(_delta: float) -> void:
	var progress := _egg.reveal_progress
	if progress > 0.0:
		_creature.show()
		_creature.scale = Vector3.ONE*lerpf(0.68,1.0,smoothstep(0.0,1.0,progress))

func _show_card() -> void:
	_ready_to_accept = true
	%Card.show()
	%Accept.disabled = false
	%Hint.text = "Welcome to Hatchworks"

func _accept() -> void:
	if _accepted or not _ready_to_accept:
		return
	var creature := _incubator.accept_hatch()
	if creature == null:
		%Hint.text = "Clear some land beside the incubator to welcome your creature."
		return
	_accepted = true
	%Accept.disabled = true
	set_process(false)
	tooltip_controller.hide_tooltip()
	var transition := create_tween()
	transition.tween_property(self,"modulate:a",0.0,0.25)
	transition.tween_callback(_finish)

func _finish() -> void:
	hide()
	for child in %Models.get_children():
		%Models.remove_child(child)
		child.queue_free()
	_egg = null
	_creature = null
	map_manager.set_modal(false)
