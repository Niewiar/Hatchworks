@tool
extends PanelContainer

@onready var _world: Node3D = %Models
@onready var _camera: Camera3D = %Camera
var _entry: Resource
var _female := false
var _animation: AnimationPlayer
var _playing := true
var _clips: Array[StringName] = []
var _focus := Vector3.ZERO
var _distance := 4.0
var _base_size := 3.0
var _zoom := 1.0
var _yaw := -0.55
var _pitch := 0.3

func _ready() -> void:
	%Male.pressed.connect(_set_sex.bind(false))
	%Female.pressed.connect(_set_sex.bind(true))
	%ResetView.pressed.connect(_reset_view)
	%AnimationChoice.item_selected.connect(_choose_animation)
	%Play.toggled.connect(_set_playing)
	%Stage.gui_input.connect(_on_view_input)

func show_entry(entry: Resource) -> void:
	var previous_clip: StringName = _clips[%AnimationChoice.selected] if not _clips.is_empty() and %AnimationChoice.selected >= 0 else &"Idle"
	_entry = entry
	_animation = null
	for child in _world.get_children():
		_world.remove_child(child)
		child.queue_free()
	%Icon.texture = null
	%IconCenter.hide()
	%Empty.hide()
	%SexControls.visible = entry is CreatureSpecies
	var model: Node3D
	if ((entry is CreatureSpecies or entry is BuildingDefinition) and entry.scene != null) or (entry is EggDefinition and entry.model != null):
		var scene: PackedScene = entry.model if entry is EggDefinition else entry.scene
		var instance := scene.instantiate()
		if instance is Node3D:
			model = instance
			if entry is CreatureSpecies:
				var appearance := _appearance_scene(model,_female)
				var old := model.get_node_or_null("Model") as Node3D
				if old == null:
					old = model.get_node_or_null("mossling_v1") as Node3D
				if appearance != null and old != null:
					var replacement := appearance.instantiate() as Node3D
					replacement.transform = old.transform
					replacement.name = old.name
					model.remove_child(old)
					old.free()
					model.add_child(replacement)
			_prepare_model(model)
			_world.add_child(model)
		else:
			instance.free()
	elif entry is FloraSpecies or entry is DepositDefinition:
		if not entry.variants.is_empty() and entry.variants[0] != null:
			var mesh := MeshInstance3D.new()
			mesh.mesh = entry.variants[0]
			if entry is DepositDefinition:
				mesh.material_override = entry.material
			else:
				var material := load("res://resources/flora/foliage_material.tres").duplicate() as ShaderMaterial
				material.set_shader_parameter("follow_ground",false)
				mesh.material_override = material
			model = mesh
			_world.add_child(model)
	if model != null:
		_animation = model.find_child("AnimationPlayer",true,false) as AnimationPlayer
		if _animation != null:
			_animation.process_mode = Node.PROCESS_MODE_ALWAYS
			_animation.animation_finished.connect(_repeat_animation)
		var bounds := _bounds(model)
		_focus = bounds.get_center()
		_distance = maxf(bounds.size.length(),1.0)*1.7
		_base_size = maxf(maxf(bounds.size.x,bounds.size.z)*1.65,bounds.size.y*1.65)
		_base_size = maxf(_base_size,0.5)
	else:
		var icon: Texture2D = entry.ui_icon if entry is FanceData else (entry.get("icon") as Texture2D if entry != null and _has_property(entry,&"icon") else null)
		%Icon.texture = icon
		%IconCenter.visible = icon != null
		%Empty.visible = icon == null
	_refresh_animations(previous_clip)
	_reset_view()

func _has_property(object: Object, name: StringName) -> bool:
	for property in object.get_property_list():
		if property.name == name:
			return true
	return false

func _appearance_scene(model: Node3D, female: bool) -> PackedScene:
	var property := &"female_appearance" if female else &"male_appearance"
	if _has_property(model,property):
		var scene := model.get(property) as PackedScene
		if scene != null:
			return scene
	var script := model.get_script() as Script
	while script != null:
		var constants := script.get_script_constant_map()
		var scene := constants.get("FEMALE_MODEL" if female else "MALE_MODEL") as PackedScene
		if scene != null:
			return scene
		script = script.get_base_script()
	return null

func _prepare_model(node: Node) -> void:
	var script := node.get_script() as Script
	if script != null and not script.is_tool():
		node.set_script(null)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is RigidBody3D:
		node.freeze = true
	if node is CPUParticles3D or node is GPUParticles3D:
		node.emitting = false
	if node is Label3D:
		node.hide()
	for child in node.get_children():
		_prepare_model(child)

func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	if node is MeshInstance3D and node.mesh != null:
		result = _world.global_transform.affine_inverse()*node.global_transform*node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var box := _bounds(child)
			if box.size.length() > 0.001:
				result = box if result.size.length() < 0.001 else result.merge(box)
	return result

func _set_sex(female: bool) -> void:
	_female = female
	%Male.set_pressed_no_signal(not female)
	%Female.set_pressed_no_signal(female)
	show_entry(_entry)

func _refresh_animations(previous: StringName) -> void:
	_clips.clear()
	%AnimationChoice.clear()
	if _animation != null:
		for clip: StringName in _animation.get_animation_list():
			if clip != &"RESET":
				_clips.append(clip)
				%AnimationChoice.add_item(clip)
	%AnimationControls.visible = not _clips.is_empty()
	if not _clips.is_empty():
		var index := _clips.find(previous)
		if index < 0:
			index = maxi(0,_clips.find(&"Idle"))
		%AnimationChoice.select(index)
		_choose_animation(index)

func _choose_animation(index: int) -> void:
	if _animation == null or index < 0 or index >= _clips.size():
		return
	_animation.speed_scale = 1.0
	_animation.play(_clips[index])
	_animation.advance(0)
	if not _playing:
		_animation.pause()

func _repeat_animation(name: StringName) -> void:
	if _playing and _animation != null and %AnimationChoice.selected >= 0 and name == _clips[%AnimationChoice.selected]:
		_animation.play(name)

func _set_playing(active: bool) -> void:
	_playing = active
	%Play.text = "Pause" if active else "Play"
	if _animation != null:
		if active:
			_animation.play()
		else:
			_animation.pause()

func _reset_view() -> void:
	_yaw = -0.55
	_pitch = 0.3
	_zoom = 1.0
	_update_camera()

func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw -= event.relative.x*0.008
		_pitch = clampf(_pitch+event.relative.y*0.006,-0.1,1.25)
		_update_camera()
		%Stage.accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom*(0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1),0.35,2.5)
			_update_camera()
			%Stage.accept_event()

func _update_camera() -> void:
	_camera.position = _focus+Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*_distance
	_camera.look_at(_focus)
	_camera.size = _base_size*_zoom
