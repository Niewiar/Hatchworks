class_name HatchPresentation
extends Control

@export var map_manager: Node3D
@export var tooltip_controller: TooltipController

enum PHASE { CLOSED, HATCHING, MOVING, REVEALING, READY, ACCEPTING }

var _incubator: IncubatorController
var _egg: EggShell
var _creature: Node3D
var _animation: AnimationPlayer
var _transition: Tween
var _phase := PHASE.CLOSED
var _ready_frame := -1
var _held_shortcuts: Dictionary[int,bool] = {}
var _hint_key := "A new life is stirring…\nLMB / RMB / Esc — skip"

func _ready() -> void:
	hide()
	set_process(false)
	%Accept.pressed.connect(_accept)
	%Return.pressed.connect(close_presentation)

func _input(event: InputEvent) -> void:
	var shortcut := 0
	var echo := false
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		shortcut = event.button_index
	elif event is InputEventKey and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		shortcut = KEY_ESCAPE
		echo = event.echo
	else:
		return
	if not event.is_pressed():
		if _held_shortcuts.erase(shortcut) or (is_visible_in_tree() and not get_tree().paused):
			get_viewport().set_input_as_handled()
		return
	if echo:
		if _held_shortcuts.has(shortcut) or (is_visible_in_tree() and not get_tree().paused):
			get_viewport().set_input_as_handled()
		return
	if not is_visible_in_tree() or get_tree().paused:
		return
	get_viewport().set_input_as_handled()
	if _held_shortcuts.has(shortcut):
		return
	_held_shortcuts[shortcut] = true
	if _phase == PHASE.ACCEPTING:
		return
	if event is InputEventMouseButton and shortcut == MOUSE_BUTTON_LEFT and %Return.is_visible_in_tree() and %Return.get_global_rect().has_point(event.position):
		close_presentation()
		return
	if _phase == PHASE.READY:
		if Engine.get_process_frames() > _ready_frame:
			_accept()
	elif _phase in [PHASE.HATCHING,PHASE.MOVING,PHASE.REVEALING]:
		complete_reveal()

func present(incubator: IncubatorController) -> void:
	if not is_instance_valid(incubator) or incubator.state != IncubatorController.STATE.PRESENTING or incubator.current_egg == null:
		return
	if visible and _incubator == incubator:
		return
	if is_instance_valid(_incubator) and _incubator != incubator and _incubator.state == IncubatorController.STATE.PRESENTING:
		_incubator.cancel_hatch()
	_stop_transition()
	_clear_models()
	_incubator = incubator
	_phase = PHASE.HATCHING
	_ready_frame = -1
	_egg = incubator.current_egg.model.instantiate() as EggShell
	_egg.position.y = 0.30
	%Models.add_child(_egg)
	_egg.hatching_finished.connect(_move_to_left)
	var species: CreatureSpecies = map_manager.database.creature(incubator.current_egg.creature_id)
	_creature = species.scene.instantiate() as Node3D
	var actor := _creature as Creature
	actor.sex = incubator.pending_sex
	actor.prepare_appearance()
	var appearance := _creature.get_node_or_null("Model")
	if appearance == null:
		appearance = _creature.get_node_or_null("mossling_v1")
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
	_set_hint("A new life is stirring…\nLMB / RMB / Esc — skip")
	modulate.a = 0.0
	show()
	_transition = create_tween()
	_transition.tween_property(self,"modulate:a",1.0,0.25)
	_egg.start_hatching()
	set_process(true)
	map_manager.set_modal(true)

func _process(_delta: float) -> void:
	if _phase == PHASE.HATCHING and is_instance_valid(_egg) and _egg.reveal_progress > 0.0:
		_creature.show()

func _move_to_left() -> void:
	if _phase != PHASE.HATCHING:
		return
	_phase = PHASE.MOVING
	set_process(false)
	_stop_transition()
	_creature.show()
	_play_animation(&"Walk")
	var duration := 0.75
	var appearance := _creature.get_node_or_null("Model") as CreatureCelAppearance
	if appearance != null and _animation != null and _animation.has_animation(&"Walk"):
		duration = 0.9 / appearance.walk_speed
		_animation.speed_scale = appearance.walk_speed * _animation.get_animation(&"Walk").length / maxf(appearance.walk_distance * absf(appearance.scale.x), 0.001)
	_transition = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(_creature,"rotation:y",-PI*0.5,0.12)
	_transition.tween_property(_creature,"position:x",-0.9,duration).set_trans(Tween.TRANS_LINEAR)
	_transition.tween_property(_creature,"rotation:y",0.0,0.12)
	_transition.tween_callback(_show_card)

func complete_reveal() -> bool:
	if not visible or _phase in [PHASE.CLOSED,PHASE.READY,PHASE.ACCEPTING]:
		return false
	_stop_transition()
	set_process(false)
	modulate.a = 1.0
	_creature.show()
	_creature.position.x = -0.9
	_creature.rotation.y = 0.0
	_show_card(true)
	return true

func _show_card(immediate: bool = false) -> void:
	if _phase not in [PHASE.HATCHING,PHASE.MOVING,PHASE.REVEALING]:
		return
	_phase = PHASE.REVEALING
	_stop_transition()
	_stop_hatching()
	_play_animation(&"Idle")
	%Card.modulate.a = 1.0 if immediate else 0.0
	%Card.show()
	_set_hint("Welcome to Hatchworks\nLMB / RMB / Esc — confirm")
	if immediate:
		_finish_reveal()
		return
	_transition = create_tween()
	_transition.tween_property(%Card,"modulate:a",1.0,0.25)
	_transition.tween_callback(_finish_reveal)

func _finish_reveal() -> void:
	if _phase != PHASE.REVEALING:
		return
	_phase = PHASE.READY
	_ready_frame = Engine.get_process_frames()
	%Accept.disabled = false

func _stop_transition() -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_transition = null

func _stop_hatching() -> void:
	if not is_instance_valid(_egg):
		return
	if _egg.hatching_finished.is_connected(_move_to_left):
		_egg.hatching_finished.disconnect(_move_to_left)
	_egg.set_process(false)
	_egg.stop_hatching()
	_egg.hide()

func _clear_models() -> void:
	_stop_hatching()
	for child in %Models.get_children():
		%Models.remove_child(child)
		child.queue_free()
	_egg = null
	_creature = null
	_animation = null

func _play_animation(id: StringName) -> void:
	if _animation != null and _animation.has_animation(id):
		_animation.speed_scale = 1.0
		_animation.play(id)

func _accept() -> void:
	if _phase != PHASE.READY or not is_instance_valid(_incubator):
		return
	_phase = PHASE.ACCEPTING
	%Accept.disabled = true
	var creature := _incubator.accept_hatch(%Accept.get_global_rect().get_center())
	if creature == null:
		_phase = PHASE.READY
		%Accept.disabled = false
		_set_hint("Clear some land beside the incubator to welcome your creature.")
		%Return.show()
		return
	%Return.hide()
	set_process(false)
	tooltip_controller.hide_tooltip()
	_stop_transition()
	_transition = create_tween()
	_transition.tween_property(self,"modulate:a",0.0,0.25)
	_transition.tween_callback(_finish)

func _finish() -> void:
	if _phase != PHASE.ACCEPTING:
		return
	_phase = PHASE.CLOSED
	_stop_transition()
	hide()
	_clear_models()
	_incubator = null
	map_manager.set_modal(false)

func cancel_for(incubator: IncubatorController) -> void:
	if _incubator != incubator or not visible:
		return
	_phase = PHASE.CLOSED
	_stop_transition()
	set_process(false)
	_clear_models()
	_incubator = null
	%Accept.disabled = true
	hide()
	map_manager.set_modal(false)

func close_presentation() -> void:
	if _phase == PHASE.ACCEPTING or not is_instance_valid(_incubator) or _incubator.state != IncubatorController.STATE.PRESENTING:
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
