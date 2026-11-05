@tool
class_name ForgeCreaturePreview
extends VBoxContainer

signal animation_changed(name: String)
signal time_changed(position: float, duration: float)

const CLIP_NAMES := {"Idle":"Bezczynność", "Walk":"Chód", "Work":"Praca", "Rest":"Odpoczynek", "Call":"Zaloty", "Eat":"Jedzenie", "Swim":"Pływanie", "HeldIdle":"Podnoszenie", "Fall":"Spadanie", "Land":"Lądowanie", "Run":"Bieg", "Headbutt":"Uderzenie głową", "ShakeSand":"Strząsanie piasku", "Rub":"Ocieranie", "Attack":"Atak"}
const SPEEDS := [0.25, 0.5, 1.0, 1.5, 2.0]
const PREVIEW_PAIR := preload("res://addons/hatchworks_forge/creatures/preview_pair.gd")
const PREVIEW_EFFECTS := preload("res://addons/hatchworks_forge/creatures/preview_effects.gd")

var frames_per_second := 30.0

var _model: Node3D
var _player: AnimationPlayer
var _skeletons: Array[Skeleton3D] = []
var _clip := ""
var _position := 0.0
var _length := 0.0
var _playing := false
var _speed := 1.0
var _loop := true
var _binding := false
var _center := Vector3.ZERO
var _framing_center := Vector3.ZERO
var _radius := 0.5
var _yaw := 0.64
var _elevation := 0.28
var _zoom := 1.0
var _dragging := false
var _drag_button := MOUSE_BUTTON_LEFT
var _group := ButtonGroup.new()
var _bone_mesh := ImmediateMesh.new()
var _pair := PREVIEW_PAIR.new()
var _effects := PREVIEW_EFFECTS.new()

func _ready() -> void:
	%Front.pressed.connect(_set_view.bind("front"))
	%Side.pressed.connect(_set_view.bind("side"))
	%ThreeQuarter.pressed.connect(_set_view.bind("three"))
	%Fit.pressed.connect(_fit_camera)
	%Grid.toggled.connect(func(active: bool): %GridMesh.visible = active)
	%Bones.toggled.connect(_set_bones)
	%Play.pressed.connect(_toggle_playback)
	%PreviousFrame.pressed.connect(func(): seek((ceilf(_position * frames_per_second - 0.00001) - 1.0) / frames_per_second))
	%NextFrame.pressed.connect(func(): seek((floorf(_position * frames_per_second + 0.00001) + 1.0) / frames_per_second))
	%Timeline.value_changed.connect(_timeline_changed)
	%Speed.item_selected.connect(func(index: int): _speed = SPEEDS[index])
	%Loop.toggled.connect(func(active: bool): _loop = active)
	%ViewportContainer.gui_input.connect(_viewport_input)
	%ViewportContainer.resized.connect(_update_camera)
	%ViewportContainer.mouse_exited.connect(func(): _dragging = false)
	visibility_changed.connect(_sync_visibility)
	get_window().visibility_changed.connect(_sync_visibility)
	_build_grid()
	%BoneMesh.mesh = _bone_mesh
	%BoneMesh.visible = false
	_set_playback_enabled(false)
	_sync_visibility()

func configure(species: CreatureSpecies, female: bool) -> void:
	if not is_node_ready():
		await ready
	_clear_model()
	%ModelStatus.text = "Wczytywanie modelu…"
	%ModelStatus.show()
	if species == null:
		%ModelStatus.text = "Wybierz kreaturę"
		return
	var packed := _appearance(species, female)
	if packed == null:
		%ModelStatus.text = "Nie znaleziono modelu"
		return
	_model = packed.instantiate() as Node3D
	if _model == null:
		%ModelStatus.text = "Scena nie zawiera modelu 3D"
		return
	_prepare_model(_model)
	%ModelRoot.add_child(_model)
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeletons.assign(_model.find_children("*", "Skeleton3D", true, false))
	var bounds := _model_bounds(_model)
	_model.position.y -= bounds.position.y
	bounds.position.y = 0.0
	_pair.bind(self, species, _model)
	_effects.bind(self, species, female)
	%ModelLabel.text = "%.2f m · %s" % [bounds.size.y, "Samica" if female else "Samiec"]
	%ModelStatus.hide()
	_frame_models()
	var names := PackedStringArray()
	if _player != null:
		_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for name in _player.get_animation_list():
			_player.get_animation(name).loop_mode = Animation.LOOP_NONE
			if name != &"RESET":
				names.append(name)
	for name in names:
		var button := %ClipTemplate.duplicate() as Button
		button.unique_name_in_owner = false
		button.name = "Clip_" + name.validate_node_name()
		button.text = CLIP_NAMES.get(name, name)
		button.button_group = _group
		button.set_meta("clip", name)
		button.pressed.connect(play_animation.bind(name))
		%ClipButtons.add_child(button)
		button.show()
	%ClipCount.text = str(names.size())
	%NoAnimations.visible = names.is_empty()
	_set_playback_enabled(not names.is_empty())
	if not names.is_empty():
		play_animation("Idle" if names.has("Idle") else names[0])
	else:
		animation_changed.emit("")
	_update_bones()
	_sync_visibility()

func selected_animation() -> String:
	return _clip

func current_time() -> float:
	return _position

func duration() -> float:
	return _length

func configure_pair(enabled: bool, partner_female: bool) -> void:
	_pair.configure(enabled, partner_female)
	if is_instance_valid(_model):
		_refresh_pair()

func pair_context() -> Dictionary:
	return _pair.context()

func configure_effects(visuals: bool, audio: bool, volume: float) -> void:
	var changes := _effects.configure(visuals, audio, volume)
	get_node("ViewportFrame/FrameContent/ViewFooter/Muted").text = "Dźwięk włączony" if audio and volume > 0.0 else "Dźwięk wyciszony"
	if changes != 0 and is_instance_valid(_model):
		_refresh_effects(true)
		if changes & 1:
			_frame_models()

func play_animation(name: String) -> void:
	if _player == null or not _player.has_animation(name):
		return
	_clip = name
	_position = 0.0
	_length = _player.get_animation(name).length
	_player.play(name)
	_player.seek(0.0, true)
	_refresh_pair()
	_playing = true
	_effects.begin_playback(_position, _speed)
	%Play.text = "Ⅱ"
	%NativeClip.text = name
	%Timeline.max_value = maxf(_length, 0.001)
	for child in %ClipButtons.get_children():
		if child is Button and child != %ClipTemplate:
			child.set_pressed_no_signal(child.get_meta("clip", "") == name)
	_refresh_time()
	_update_bones()
	animation_changed.emit(name)

func seek(seconds: float) -> void:
	if _player == null or _clip.is_empty():
		return
	_playing = false
	_position = clampf(seconds, 0.0, _length)
	_player.seek(_position, true)
	_pair.sample(_clip, _position)
	_effects.seek(_position)
	%Play.text = "▶"
	_refresh_time()
	_update_bones()

func _process(delta: float) -> void:
	if _player != null and _playing and not _clip.is_empty():
		var previous := _position
		var wrapped := false
		_position += delta * _speed
		if _position >= _length:
			if _loop and _length > 0.0:
				_position = fposmod(_position, _length)
				wrapped = true
			else:
				_position = _length
				_playing = false
				%Play.text = "▶"
		_player.seek(_position, true)
		_pair.sample(_clip, _position)
		_effects.advance(previous, _position, wrapped, _speed)
		_refresh_time()
		if %Bones.button_pressed:
			_update_bones()

func _appearance(species: CreatureSpecies, female: bool) -> PackedScene:
	if species.scene != null:
		var state := species.scene.get_state()
		for index in state.get_node_count():
			for property in state.get_node_property_count(index):
				var name := str(state.get_node_property_name(index, property))
				if name == ("female_appearance" if female else "male_appearance"):
					var value: Variant = state.get_node_property_value(index, property)
					if value is PackedScene:
						return value
			if not female and state.get_node_name(index) == &"Model":
				var instance := state.get_node_instance(index)
				if instance != null:
					return instance
	var path := "res://scenes/creatures/%s%s_model.tscn" % [species.id, "_female" if female else ""]
	return ResourceLoader.load(path, "PackedScene") as PackedScene if ResourceLoader.exists(path) else null

func _prepare_model(node: Node) -> void:
	if node.get_script() != null and not node is CreatureCelAppearance:
		node.set_script(null)
	if node is AnimationPlayer:
		for library_name in node.get_animation_library_list():
			var original: AnimationLibrary = node.get_animation_library(library_name)
			var library := AnimationLibrary.new()
			for animation_name in original.get_animation_list():
				var animation := original.get_animation(animation_name).duplicate(true) as Animation
				for track in range(animation.get_track_count() - 1, -1, -1):
					if animation.track_get_type(track) in [Animation.TYPE_AUDIO, Animation.TYPE_METHOD]:
						animation.remove_track(track)
				animation.loop_mode = Animation.LOOP_NONE
				library.add_animation(animation_name, animation)
			node.remove_animation_library(library_name)
			node.add_animation_library(library_name, library)
		node.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		if not node.autoplay.is_empty():
			node.autoplay = ""
	for child in node.get_children():
		_prepare_model(child)

func _clear_model() -> void:
	_effects.clear()
	_pair.clear()
	_playing = false
	_player = null
	_skeletons.clear()
	_clip = ""
	_position = 0.0
	_length = 0.0
	if is_instance_valid(_model):
		_model.get_parent().remove_child(_model)
		_model.free()
	_model = null
	for child in %ClipButtons.get_children():
		if child != %ClipTemplate:
			%ClipButtons.remove_child(child)
			child.queue_free()
	_bone_mesh.clear_surfaces()
	_set_playback_enabled(false)
	%ClipCount.text = "0"
	%NativeClip.text = ""
	%ModelLabel.text = ""
	_refresh_time()

func _bounds() -> AABB:
	var result := _model_bounds(_model)
	if is_instance_valid(_pair.model):
		result = result.merge(_model_bounds(_pair.model))
	return _effects.include_bounds(result)

func _model_bounds(model: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var local: AABB = mesh.global_transform * mesh.get_aabb()
		result = result.merge(local) if initialized else local
		initialized = true
	return result if initialized else AABB(Vector3.ZERO, Vector3.ONE * 0.5)

func _refresh_pair() -> void:
	var changed := _pair.update(_clip)
	_pair.sample(_clip, _position)
	var effects_changed := _refresh_effects()
	_skeletons.assign(_model.find_children("*", "Skeleton3D", true, false))
	if is_instance_valid(_pair.model):
		for skeleton in _pair.model.find_children("*", "Skeleton3D", true, false):
			_skeletons.append(skeleton as Skeleton3D)
	if changed or effects_changed:
		_frame_models()
	_update_bones()

func _refresh_effects(preserve_audio: bool = false) -> bool:
	var changed := _effects.rebuild(_model, _pair.model, _clip, _length, _pair.context(), preserve_audio)
	_effects.sample(_position, true)
	return changed

func _frame_models() -> void:
	var bounds := _bounds()
	_center = bounds.get_center()
	_framing_center = _center
	_radius = maxf(bounds.size.length() * 0.5, 0.05)
	%Camera.near = maxf(_radius / 100.0, 0.001)
	%Camera.far = maxf(_radius * 100.0, 20.0)
	%GridMesh.scale = Vector3.ONE * maxf(_radius, 0.1)
	_fit_camera()

func _build_grid() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index in range(-20, 21):
		var coordinate := float(index) * 0.25
		mesh.surface_add_vertex(Vector3(coordinate, -0.001, -5.0))
		mesh.surface_add_vertex(Vector3(coordinate, -0.001, 5.0))
		mesh.surface_add_vertex(Vector3(-5.0, -0.001, coordinate))
		mesh.surface_add_vertex(Vector3(5.0, -0.001, coordinate))
	mesh.surface_end()
	%GridMesh.mesh = mesh

func _set_bones(active: bool) -> void:
	%BoneMesh.visible = active
	if active:
		_update_bones()

func _update_bones() -> void:
	_bone_mesh.clear_surfaces()
	if not %Bones.button_pressed or _skeletons.is_empty():
		return
	_bone_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var count := 0
	for skeleton in _skeletons:
		for bone in skeleton.get_bone_count():
			var parent := skeleton.get_bone_parent(bone)
			if parent < 0:
				continue
			_bone_mesh.surface_add_vertex(skeleton.global_transform * skeleton.get_bone_global_pose(parent).origin)
			_bone_mesh.surface_add_vertex(skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin)
			count += 1
	if count > 0:
		_bone_mesh.surface_end()
	else:
		_bone_mesh.clear_surfaces()

func _timeline_changed(value: float) -> void:
	if not _binding:
		seek(value)

func _toggle_playback() -> void:
	if _player == null:
		return
	if not _playing and _position >= _length:
		_position = 0.0
		_player.seek(_position, true)
		_pair.sample(_clip, _position)
		_effects.seek(_position)
		_refresh_time()
	_playing = not _playing
	if _playing:
		_effects.begin_playback(_position, _speed)
	else:
		_effects.stop_audio()
	%Play.text = "Ⅱ" if _playing else "▶"

func _refresh_time() -> void:
	_binding = true
	%Timeline.set_value_no_signal(_position)
	%Time.text = ("%.2f / %.2f s" % [_position, _length]).replace(".", ",")
	_binding = false
	time_changed.emit(_position, _length)

func _set_playback_enabled(enabled: bool) -> void:
	for control in [%Play, %PreviousFrame, %NextFrame, %Speed, %Loop]:
		control.disabled = not enabled
	%Timeline.editable = enabled
	%NoAnimations.visible = not enabled

func _set_view(view: String) -> void:
	_yaw = 0.0 if view == "front" else (PI * 0.5 if view == "side" else 0.64)
	_elevation = 0.16 if view != "three" else 0.28
	%Front.set_pressed_no_signal(view == "front")
	%Side.set_pressed_no_signal(view == "side")
	%ThreeQuarter.set_pressed_no_signal(view == "three")
	_update_camera()

func _fit_camera() -> void:
	_zoom = 1.0
	_center = _framing_center
	_set_view("three")

func _update_camera() -> void:
	if not is_node_ready():
		return
	var aspect := maxf(float(%Viewport.size.x) / maxf(%Viewport.size.y, 1), 0.2)
	var half_fov := deg_to_rad(%Camera.fov) * 0.5
	var vertical := atan(tan(half_fov) * minf(aspect, 1.0))
	var distance := _radius / sin(vertical) * 1.12 * _zoom
	var direction := Vector3(sin(_yaw) * cos(_elevation), sin(_elevation), cos(_yaw) * cos(_elevation))
	%Camera.position = _center + direction * distance
	%Camera.look_at(_center, Vector3.UP)

func _viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_dragging = event.pressed
			_drag_button = event.button_index
			if event.pressed:
				%ViewportContainer.grab_focus()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom = clampf(_zoom * (0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.12), 0.3, 4.0)
			_update_camera()
		%ViewportContainer.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if _drag_button == MOUSE_BUTTON_RIGHT:
			var camera: Camera3D = %Camera
			var distance := camera.position.distance_to(_center)
			var unit := 2.0 * distance * tan(deg_to_rad(camera.fov) * 0.5) / maxf(%ViewportContainer.size.y, 1.0)
			_center += (-camera.basis.x * event.relative.x + camera.basis.y * event.relative.y) * unit
		else:
			_yaw -= event.relative.x * 0.008
			_elevation = clampf(_elevation + event.relative.y * 0.006, 0.03, PI * 0.48)
			for button in [%Front, %Side, %ThreeQuarter]:
				button.set_pressed_no_signal(false)
		_update_camera()
		%ViewportContainer.accept_event()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_toggle_playback()
		%ViewportContainer.accept_event()

func _sync_visibility() -> void:
	if not is_node_ready():
		return
	var active := is_visible_in_tree() and get_window().visible
	if not active:
		_effects.stop_audio()
	set_process(active)
	%Viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
