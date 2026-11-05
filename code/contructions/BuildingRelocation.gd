class_name BuildingRelocation
extends RefCounted

var target: Node3D
var original_transform := Transform3D.IDENTITY
var _visible := true
var _processing := false
var _physics_processing := false
var _animations: Array[Dictionary] = []
var _audio: Array[Dictionary] = []

func begin(building: Node3D, map: Node3D) -> void:
	target = building
	original_transform = building.global_transform
	_visible = building.visible
	_processing = building.is_processing()
	_physics_processing = building.is_physics_processing()
	building.hide()
	building.set_process(false)
	building.set_physics_process(false)
	for node in building.find_children("*","AnimationPlayer",true,false):
		var player := node as AnimationPlayer
		_animations.append({"player":player,"active":player.active})
		player.active = false
	SoundEffects.set_machine_loop(building,&"",false)
	for node in building.find_children("*","AudioStreamPlayer3D",true,false):
		var player := node as AudioStreamPlayer3D
		if player.is_queued_for_deletion():
			continue
		_audio.append({"player":player,"paused":player.stream_paused,"mode":player.process_mode})
		player.stream_paused = true
		player.process_mode = Node.PROCESS_MODE_DISABLED
	map.noise.set_source(building,0.0,0.0,false)

func collision_rids() -> Array[RID]:
	var result: Array[RID] = []
	if not is_instance_valid(target):
		return result
	for node in target.find_children("*","CollisionObject3D",true,false):
		result.append((node as CollisionObject3D).get_rid())
	return result

func finish(transform: Transform3D) -> Node3D:
	var building := target
	target = null
	if is_instance_valid(building):
		building.global_transform = transform
		building.visible = _visible
		building.set_process(_processing)
		building.set_physics_process(_physics_processing)
	for entry in _animations:
		if is_instance_valid(entry.player):
			entry.player.active = entry.active
	_animations.clear()
	for entry in _audio:
		if is_instance_valid(entry.player) and not entry.player.is_queued_for_deletion():
			entry.player.process_mode = entry.mode
			entry.player.stream_paused = entry.paused
	_audio.clear()
	return building
