@tool
class_name ForgePreviewEffects
extends RefCounted

const CATALOG := preload("res://addons/hatchworks_forge/creatures/animation_effect_catalog.gd")
const EPSILON := 0.000001

var _preview: ForgeCreaturePreview
var _species: CreatureSpecies
var _female := false
var _visuals := false
var _audio := false
var _volume := 0.7
var _speed := 1.0
var _particles: Array[Dictionary] = []
var _sounds: Array[Dictionary] = []
var _voices: Array[AudioStreamPlayer] = []
var _random := RandomNumberGenerator.new()
var _duration := 0.0

func bind(preview: ForgeCreaturePreview, species: CreatureSpecies, female: bool) -> void:
	clear()
	_preview = preview
	_species = species
	_female = female

func configure(visuals: bool, audio: bool, volume: float) -> int:
	var changes := (1 if _visuals != visuals else 0) | (2 if _audio != audio else 0)
	_visuals = visuals
	_audio = audio
	_volume = clampf(volume, 0.0, 1.0)
	if not _audio or _volume <= 0.0:
		stop_audio()
	_update_voices()
	return changes

func clear() -> void:
	_clear_particles()
	stop_audio()
	_sounds.clear()
	_species = null

func rebuild(primary: Node3D, partner: Node3D, clip: String, duration: float, pair: Dictionary, preserve_audio: bool = false) -> bool:
	var had_particles := not _particles.is_empty()
	_clear_particles()
	_sounds.clear()
	if not preserve_audio:
		stop_audio()
	_duration = duration
	if _species == null:
		return had_particles
	_add_actor(primary, _female, clip, clip, duration, 0.0)
	if is_instance_valid(partner):
		var partner_clip := str(pair.get("partner_animation", "Idle"))
		var delay := 0.4 if clip == "Play" else (0.35 if clip == "Call" and partner_clip == "Call" else 0.0)
		_add_actor(partner, bool(pair.get("partner_female", not _female)), "Call" if clip == "Call" else partner_clip, partner_clip, duration, delay)
	return had_particles or not _particles.is_empty()

func seek(position: float) -> void:
	stop_audio()
	sample(position, true)

func sample(position: float, reset: bool = false) -> void:
	for entry: Dictionary in _particles:
		var particles: CPUParticles3D = entry.node
		if not is_instance_valid(particles):
			continue
		var age := position - float(entry.time)
		var active: bool = age >= 0.0 and (bool(entry.continuous) or age <= particles.lifetime)
		particles.visible = _visuals and active
		if not active:
			entry.simulated = -1.0
			particles.emitting = false
			continue
		var previous := float(entry.simulated)
		if reset or previous < 0.0 or age < previous:
			particles.emitting = true
			particles.restart(true)
			previous = 0.0
		var delta := maxf(age - previous, 0.0)
		if delta > 0.0:
			particles.request_particles_process(delta)
		if entry.continuous and age >= float(entry.active_duration):
			particles.emitting = false
		entry.simulated = age

func begin_playback(position: float, speed: float) -> void:
	_speed = speed
	if position <= EPSILON:
		_emit_between(-2.0 * EPSILON, 0.0)
	elif _audio and _volume > 0.0 and _preview.is_visible_in_tree() and _preview.get_window().visible:
		for sound: Dictionary in _sounds:
			var offset := (position-float(sound.time))*float(sound.pitch)
			if offset >= 0.0 and offset < sound.stream.get_length():
				_play_sound(sound,offset)
	_update_voices()

func advance(previous: float, position: float, wrapped: bool, speed: float) -> void:
	_speed = speed
	if wrapped:
		_emit_between(previous, _duration)
		_emit_between(-2.0 * EPSILON, position)
	else:
		_emit_between(previous, position)
	sample(position, wrapped)
	_update_voices()

func stop_audio() -> void:
	for voice in _voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.queue_free()
	_voices.clear()

func include_bounds(bounds: AABB) -> AABB:
	for entry: Dictionary in _particles:
		var particles: CPUParticles3D = entry.node
		if not is_instance_valid(particles):
			continue
		var effect: AABB = particles.global_transform * entry.bounds
		var top := maxf(effect.end.y, 0.0)
		effect.position.y = maxf(effect.position.y, 0.0)
		effect.size.y = maxf(top - effect.position.y, 0.01)
		bounds = bounds.merge(effect)
	return bounds

func _add_actor(actor: Node3D, female: bool, visual_clip: String, sound_clip: String, duration: float, offset: float) -> void:
	if _visuals:
		for effect: Dictionary in CATALOG.get_particles(_species, female, StringName(visual_clip), duration):
			var particles: CPUParticles3D = effect.template
			particles.speed_scale = 0.0
			particles.preprocess = 0.0
			particles.fixed_fps = 60
			particles.use_fixed_seed = true
			particles.seed = (str(_species.id) + str(female) + visual_clip + particles.name).hash() & 0xffffffff
			particles.transform = effect.transform
			var bounds := _particle_bounds(particles)
			particles.visibility_aabb = bounds
			actor.add_child(particles)
			_particles.append({"node": particles, "time": float(effect.time) + offset, "continuous": bool(effect.continuous), "active_duration": float(effect.active_duration), "simulated": -1.0, "bounds": bounds})
	if _audio:
		for sound: Dictionary in CATALOG.get_sounds(_species, female, StringName(sound_clip), duration):
			sound.time = float(sound.time) + offset
			_sounds.append(sound)

func _particle_bounds(particles: CPUParticles3D) -> AABB:
	var life := particles.lifetime
	var speed := maxf(absf(particles.initial_velocity_min), absf(particles.initial_velocity_max))
	var direction := particles.direction.normalized()
	var spread := deg_to_rad(particles.spread)
	var radius := particles.emission_sphere_radius if particles.emission_shape == CPUParticles3D.EMISSION_SHAPE_SPHERE else 0.0
	if particles.emission_shape == CPUParticles3D.EMISSION_SHAPE_BOX:
		radius = particles.emission_box_extents.length()
	if particles.mesh != null:
		radius += particles.mesh.get_aabb().size.length() * 0.5 * maxf(particles.scale_amount_max, 1.0)
	var minimum := Vector3.ONE * -radius
	var maximum := Vector3.ONE * radius
	for axis in 3:
		var lateral := sqrt(maxf(1.0 - direction[axis] * direction[axis], 0.0)) * sin(spread)
		var center := direction[axis] * cos(spread)
		minimum[axis] += minf((center - lateral) * speed * life, 0.0) + minf(particles.gravity[axis], 0.0) * life * life * 0.5
		maximum[axis] += maxf((center + lateral) * speed * life, 0.0) + maxf(particles.gravity[axis], 0.0) * life * life * 0.5
	return AABB(minimum, maximum - minimum).grow(0.025)

func _emit_between(start: float, finish: float) -> void:
	if not _audio or _volume <= 0.0 or not _preview.is_visible_in_tree() or not _preview.get_window().visible:
		return
	for sound: Dictionary in _sounds:
		var time := float(sound.time)
		if time > start + EPSILON and time <= finish + EPSILON:
			_play_sound(sound)

func _play_sound(sound: Dictionary, offset: float = 0.0) -> void:
	_voices = _voices.filter(func(voice): return is_instance_valid(voice))
	if _voices.size() >= 32:
		return
	var voice := AudioStreamPlayer.new()
	voice.name = "PreviewSound_" + str(sound.id)
	voice.stream = sound.stream
	var random_pitch: Vector2 = sound.pitch_random
	voice.set_meta("profile_volume_db", float(sound.volume_db))
	voice.set_meta("source_pitch", float(sound.pitch) * _random.randf_range(random_pitch.x, random_pitch.y))
	_preview.add_child(voice)
	voice.finished.connect(voice.queue_free)
	_voices.append(voice)
	_update_voices()
	voice.play(offset)

func _update_voices() -> void:
	for voice in _voices:
		if is_instance_valid(voice):
			voice.volume_db = float(voice.get_meta("profile_volume_db")) + linear_to_db(maxf(_volume, 0.0001))
			voice.pitch_scale = clampf(float(voice.get_meta("source_pitch")) * _speed, 0.05, 4.0)

func _clear_particles() -> void:
	for entry: Dictionary in _particles:
		if is_instance_valid(entry.node):
			entry.node.get_parent().remove_child(entry.node)
			entry.node.free()
	_particles.clear()
