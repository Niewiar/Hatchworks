@tool
class_name ForgePreviewPair
extends RefCounted

var model: Node3D
var player: AnimationPlayer
var _preview: ForgeCreaturePreview
var _species: CreatureSpecies
var _primary: Node3D
var _primary_transform := Transform3D.IDENTITY
var _partner_transform := Transform3D.IDENTITY
var _enabled := false
var _female := true
var _model_female := true
var _source_clip := ""
var _paired_clip := ""
var _playing_clip := ""

func configure(enabled: bool, female: bool) -> void:
	_enabled = enabled
	_female = female

func bind(preview: ForgeCreaturePreview, species: CreatureSpecies, primary: Node3D) -> void:
	clear()
	_preview = preview
	_species = species
	_primary = primary
	_primary_transform = primary.transform

func clear() -> void:
	_clear_partner()
	_primary = null
	_species = null

func context() -> Dictionary:
	return {"partner_female": _female, "partner_animation": _paired_clip} if is_instance_valid(model) else {}

func update(clip: String) -> bool:
	var paired_clip := _counterpart(clip)
	if paired_clip.is_empty() or not is_instance_valid(_primary):
		var was_active := is_instance_valid(model)
		_clear_partner()
		return was_active
	var changed := not is_instance_valid(model) or _model_female != _female or _source_clip != clip
	if is_instance_valid(model) and _model_female != _female:
		_clear_partner()
	if not is_instance_valid(model):
		var packed := _preview._appearance(_species, _female)
		if packed == null:
			return false
		model = packed.instantiate() as Node3D
		if model == null:
			return false
		_preview._prepare_model(model)
		_preview.get_node("%ModelRoot").add_child(model)
		var bounds := _preview._model_bounds(model)
		model.position.y -= bounds.position.y
		_partner_transform = model.transform
		player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player == null or not player.has_animation(paired_clip):
			_clear_partner()
			return false
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for name in player.get_animation_list():
			player.get_animation(name).loop_mode = Animation.LOOP_NONE
		_model_female = _female
	_primary.transform = _primary_transform
	model.transform = _partner_transform
	if clip == "Call":
		var distance := _call_distance()
		_primary.position.x -= distance * 0.5
		model.position.x += distance * 0.5
		_primary.rotate_y(PI * 0.5)
		model.rotate_y(-PI * 0.5)
	else:
		_primary.position.x -= 0.275
		model.position.x += 0.275
	_source_clip = clip
	_paired_clip = paired_clip
	return changed

func sample(clip: String, position: float) -> void:
	if not is_instance_valid(player):
		return
	var animation := _paired_clip
	var time := position
	if clip == "Play" or clip == "Call" and _paired_clip == "Call":
		var delay := 0.4 if clip == "Play" else 0.35
		animation = "Idle" if position < delay else _paired_clip
		time = 0.0 if position < delay else position-delay
	if not player.has_animation(animation):
		return
	var length := player.get_animation(animation).length
	if clip == "Call" or clip == "Play" and time >= length:
		time = fposmod(time, length) if length > 0.0 else 0.0
	else:
		time = clampf(time, 0.0, length)
	if _playing_clip != animation:
		player.play(animation)
		_playing_clip = animation
	player.seek(time, true)

func _counterpart(clip: String) -> String:
	if not _enabled or _species == null:
		return ""
	if clip == "Call":
		return "Call" if _species.id == &"tuftling" else "Idle"
	if _species.id == &"tuftling" and clip == "Play":
		return "Play"
	return ""

func _clear_partner() -> void:
	if is_instance_valid(_primary):
		_primary.transform = _primary_transform
	if is_instance_valid(model):
		model.get_parent().remove_child(model)
		model.free()
	model = null
	player = null
	_source_clip = ""
	_paired_clip = ""
	_playing_clip = ""

func _call_distance() -> float:
	if _species.scene != null:
		var state := _species.scene.get_state()
		for node in state.get_node_count():
			if state.get_node_name(node) != &"CollisionShape3D":
				continue
			for property in state.get_node_property_count(node):
				if state.get_node_property_name(node, property) == &"shape":
					var shape: Variant = state.get_node_property_value(node, property)
					if shape is SphereShape3D:
						return shape.radius * 2.0 + 0.22
	var primary_bounds := _preview._model_bounds(_primary)
	var partner_bounds := _preview._model_bounds(model)
	return maxf(0.7, (primary_bounds.size.z + partner_bounds.size.z) * 0.5 + 0.22)
