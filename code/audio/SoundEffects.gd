extends Node

const STREAMS := {
	&"tuftling_voice":"res://assets/audio/effects/tuftling_voice.wav",
	&"rootle_voice":"res://assets/audio/effects/rootle_voice.wav",
	&"pebblit_voice":"res://assets/audio/effects/pebblit_voice.wav",
	&"bloomlet_voice":"res://assets/audio/effects/bloomlet_voice.wav",
	&"plant_work":"res://assets/audio/effects/plant_work.wav",
	&"herb_work":"res://assets/audio/effects/herb_work.wav",
	&"grass_work":"res://assets/audio/effects/grass_work.wav",
	&"stone_impact":"res://assets/audio/effects/stone_impact.wav",
	&"wood_hit":"res://assets/audio/effects/wood_hit.wav",
	&"mining_hit":"res://assets/audio/effects/mining_hit.wav",
	&"machine_start":"res://assets/audio/effects/machine_start.wav",
	&"machine_ready":"res://assets/audio/effects/machine_ready.wav",
	&"incubator_loop":"res://assets/audio/effects/incubator_loop.wav",
	&"workshop_loop":"res://assets/audio/effects/workshop_loop.wav",
	&"water_splash":"res://assets/audio/effects/water_splash.wav"
}

var volume: float:
	get:
		return _volume
var _volume := 0.7
var _voices: Array[WeakRef] = []
var _loops: Dictionary = {}
var _streams: Dictionary = {}
var _cooldowns: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Effects") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count-1,"Effects")
	set_volume(Localization.sound_volume())
	Localization.sound_volume_changed.connect(set_volume)

func set_volume(value: float) -> void:
	_volume = clampf(value,0.0,1.0)
	var bus := AudioServer.get_bus_index("Effects")
	if bus >= 0:
		AudioServer.set_bus_mute(bus,_volume <= 0.0)
		AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(_volume,0.0001)))

func play_at(id: StringName, point: Vector3, voice_owner: Node = null, pitch: float = 1.0) -> void:
	if not STREAMS.has(id) or get_tree().paused or not point.is_finite():
		return
	var parent := voice_owner if is_instance_valid(voice_owner) and not voice_owner.is_queued_for_deletion() else get_tree().current_scene
	if parent == null or not parent.is_inside_tree():
		return
	var key := str(parent.get_instance_id())+":"+str(id)
	var now := Time.get_ticks_msec()
	if now-int(_cooldowns.get(key,-1000)) < 180:
		return
	_cooldowns[key] = now
	_voices = _voices.filter(func(voice): return is_instance_valid(voice.get_ref()))
	if _voices.size() >= 32:
		return
	var player := _make_player(id)
	player.pitch_scale = clampf(pitch*randf_range(0.96,1.04),0.5,2.0)
	parent.add_child(player)
	player.global_position = point
	player.finished.connect(player.queue_free)
	_voices.append(weakref(player))
	player.play()

func set_machine_loop(source: Node3D, id: StringName, active: bool) -> void:
	if not is_instance_valid(source):
		return
	if not active:
		if _loops.has(source):
			var player: AudioStreamPlayer3D = _loops[source]
			if is_instance_valid(player):
				player.stop()
				player.queue_free()
			_loops.erase(source)
		return
	if _loops.has(source) or not STREAMS.has(id):
		return
	var player := _make_player(id)
	player.volume_db = -15.0
	source.add_child(player)
	player.position = Vector3.UP*0.6
	_loops[source] = player
	player.play()

func _make_player(id: StringName) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	if not _streams.has(id):
		_streams[id] = load(STREAMS[id]) as AudioStream
	player.stream = _streams[id]
	if str(id).ends_with("_loop") and player.stream is AudioStreamWAV:
		var loop := player.stream.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = roundi(loop.get_length()*loop.mix_rate)
		player.stream = loop
	player.bus = &"Effects"
	player.volume_db = -7.0
	player.unit_size = 12.0
	player.max_distance = 45.0
	player.attenuation_filter_cutoff_hz = 18000.0
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	return player

func _process(_delta: float) -> void:
	for source in _loops.keys():
		if not is_instance_valid(source) or not is_instance_valid(_loops[source]):
			_loops.erase(source)
	var now := Time.get_ticks_msec()
	for key in _cooldowns.keys():
		if now-int(_cooldowns[key]) > 30000:
			_cooldowns.erase(key)
