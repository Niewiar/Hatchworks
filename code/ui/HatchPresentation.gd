class_name HatchPresentation
extends Control

@export var map_manager: Node3D
@export var tooltip_controller: TooltipController

var _incubator: IncubatorController
var _egg: EggShell
var _creature: Node3D
var _animation: AnimationPlayer
var _transition: Tween
var _accepted := false
var _ready_to_accept := false
var _hint_key := "A new life is stirring…"

func _ready() -> void:
	hide()
	set_process(false)
	%Accept.pressed.connect(_accept)
	%Return.pressed.connect(_return_to_incubator)

func present(incubator: IncubatorController) -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_incubator = incubator
	_accepted = false
	_ready_to_accept = false
	for child in %Models.get_children():
		%Models.remove_child(child)
		child.queue_free()
	_egg = incubator.current_egg.model.instantiate() as EggShell
	_egg.position.y = 0.58
	%Models.add_child(_egg)
	_egg.hatching_finished.connect(_move_to_left)
	var species: CreatureSpecies = map_manager.database.creature(incubator.current_egg.creature_id)
	_creature = species.scene.instantiate() as Node3D
	var appearance := _creature.get_node_or_null("Model")
	if appearance == null:
		appearance = _creature.get_node_or_null("mossling_v1")
	if appearance != null and appearance.has_method("apply_sex"):
		appearance.apply_sex(incubator.pending_sex)
	var floor_offset := 0.55
	var collider := _creature.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null and collider.shape is SphereShape3D:
		floor_offset = collider.shape.radius+0.005
		if appearance is Node3D:
			floor_offset = maxf(floor_offset,-appearance.position.y+0.005)
	_creature.set_script(null)
	_creature.process_mode = Node.PROCESS_MODE_DISABLED
	if _creature is CollisionObject3D:
		_creature.collision_layer = 0
		_creature.collision_mask = 0
	%Models.add_child(_creature)
	_creature.position.y = floor_offset
	_creature.hide()
	_animation = _creature.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if _animation != null:
		_animation.process_mode = Node.PROCESS_MODE_ALWAYS
	_play_animation(&"Idle")
	%CreatureCard.configure(species,incubator.pending_sex,map_manager.database,tooltip_controller)
	%Card.hide()
	%Accept.disabled = true
	%Return.hide()
	_set_hint("A new life is stirring…")
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

func _move_to_left() -> void:
	set_process(false)
	_play_animation(&"Walk")
	_transition = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(_creature,"rotation:y",-PI*0.5,0.12)
	_transition.tween_property(_creature,"position:x",-0.9,0.75)
	_transition.tween_property(_creature,"rotation:y",0.0,0.12)
	_transition.tween_callback(_show_card)

func _show_card() -> void:
	_play_animation(&"Idle")
	%Card.modulate.a = 0.0
	%Card.show()
	_set_hint("Welcome to Hatchworks")
	_transition = create_tween()
	_transition.tween_property(%Card,"modulate:a",1.0,0.25)
	_transition.tween_callback(_finish_reveal)

func _finish_reveal() -> void:
	_ready_to_accept = true
	%Accept.disabled = false

func _play_animation(id: StringName) -> void:
	if _animation != null and _animation.has_animation(id):
		_animation.play(id)

func _accept() -> void:
	if _accepted or not _ready_to_accept:
		return
	var creature := _incubator.accept_hatch(%Accept.get_global_rect().get_center())
	if creature == null:
		_set_hint("Clear some land beside the incubator to welcome your creature.")
		%Return.show()
		return
	_accepted = true
	%Accept.disabled = true
	%Return.hide()
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

func cancel_for(incubator: IncubatorController) -> void:
	if _incubator != incubator or not visible:
		return
	if _transition != null and _transition.is_valid():
		_transition.kill()
	set_process(false)
	for child in %Models.get_children():
		child.set_process(false)
		child.set_physics_process(false)
		%Models.remove_child(child)
		child.queue_free()
	_incubator = null
	_egg = null
	_creature = null
	_accepted = true
	_ready_to_accept = false
	%Accept.disabled = true
	hide()
	map_manager.set_modal(false)

func _return_to_incubator() -> void:
	if not is_instance_valid(_incubator) or _incubator.state != IncubatorController.STATE.PRESENTING:
		return
	var chosen := _incubator
	chosen.cancel_hatch()
	cancel_for(chosen)

func _set_hint(key: String) -> void:
	_hint_key = key
	%Hint.text = tr(key)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		%Hint.text = tr(_hint_key)
