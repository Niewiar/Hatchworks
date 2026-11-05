@tool
class_name ForgeAnimationEffectCatalog
extends RefCounted

const SOUND_LIBRARY = preload("res://code/audio/SoundEffects.gd")

static func get_particles(species: CreatureSpecies, female: bool, clip: StringName, duration: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if species == null or species.scene == null:
		return result
	var name := StringName(str(clip).get_file())
	var emitter := &""
	var time := 0.0
	var continuous := false
	if name == &"Call":
		emitter = &"Hearts"
		continuous = true
	elif name == &"Sleep" and species.id == &"tuftling":
		emitter = &"SleepSigns"
		continuous = true
	elif name == &"Work" and species.id in [&"tuftling",&"rootle",&"bloomlet",&"pebblit"]:
		emitter = &"Splash"
		continuous = species.id == &"tuftling"
		time = _impact_time(species,duration) if species.id == &"pebblit" else 0.0
	elif name == &"ShakeSand" and species.id == &"pebblit":
		emitter = &"Splash"
		time = _impact_time(species,duration)
	if emitter.is_empty():
		return result
	var actor := species.scene.instantiate()
	var source := actor.get_node_or_null(NodePath(emitter)) as CPUParticles3D
	if source != null:
		var template := source.duplicate(0) as CPUParticles3D
		_strip_scripts(template)
		var transform := source.transform
		if species.id == &"pebblit" and emitter == &"Splash":
			transform.origin = Vector3(0,-0.04,0) if female else Vector3(0,-0.05,0.15)
		transform.origin.y += _body_radius(species,actor,female)
		template.transform = Transform3D.IDENTITY
		template.emitting = false
		template.visible = true
		if template.mesh != null:
			template.mesh = template.mesh.duplicate(true) as Mesh
		result.append({"template":template,"time":time,"continuous":continuous,"transform":transform,"active_duration":maxf(duration,0.0) if continuous else 0.0})
	actor.free()
	return result

static func get_sounds(species: CreatureSpecies, female: bool, clip: StringName, duration: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if species == null:
		return result
	var name := StringName(str(clip).get_file())
	var id := &""
	var time := 0.0
	var pitch := 1.0
	if name == &"Call":
		id = &"tuftling_call" if species.id == &"tuftling" else StringName(str(species.id)+"_voice")
		pitch = 1.1 if female else 0.9
	elif name == &"HeldIdle":
		id = StringName(str(species.id)+"_voice")
		pitch = 1.1
	elif name == &"Swim" and species.id != &"tuftling":
		id = &"water_splash"
	elif name == &"Work":
		match species.id:
			&"tuftling":
				id = &"tuftling_shake"
			&"rootle", &"bloomlet":
				id = &"plant_work" if species.id == &"rootle" else &"herb_work"
				time = _impact_time(species,duration)
			&"pebblit":
				id = &"stone_impact"
				time = _impact_time(species,duration)
	elif name == &"ShakeSand" and species.id == &"pebblit":
		id = &"stone_impact"
		time = _impact_time(species,duration)
		pitch = 1.3
	elif name == &"Headbutt" and species.id == &"pebblit":
		id = &"stone_impact"
		time = clampf(0.18,0.0,maxf(duration,0.0))
	elif name == &"Attack" and species.id == &"pebblit":
		id = &"stone_impact"
		time = _impact_time(species,duration)
	if not SOUND_LIBRARY.STREAMS.has(id):
		return result
	var service: Node = SOUND_LIBRARY.new()
	var player: AudioStreamPlayer3D = service._make_player(id)
	var pitch_random := Vector2(0.96,1.04)
	if id == &"tuftling_shake":
		pitch = player.stream.get_length()/maxf(duration,0.001)
		pitch_random = Vector2.ONE
	result.append({"id":id,"stream":player.stream,"time":time,"pitch":pitch,"volume_db":player.volume_db,"pitch_random":pitch_random})
	player.free()
	service.free()
	return result

static func _impact_time(species: CreatureSpecies, duration: float) -> float:
	return maxf(duration,0.0)*clampf(species.impact_time/maxf(species.production_seconds,0.001),0.0,1.0)

static func _body_radius(species: CreatureSpecies, actor: Node, female: bool) -> float:
	if species.id == &"pebblit":
		return 0.26 if female else 0.31
	var collider := actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null and (collider.shape is SphereShape3D or collider.shape is CapsuleShape3D):
		return collider.shape.radius
	return 0.0

static func _strip_scripts(node: Node) -> void:
	if node.get_script() != null:
		node.set_script(null)
	for child in node.get_children():
		_strip_scripts(child)
