class_name NoiseController
extends Node

var _sources: Dictionary = {}
var _pulses: Array[Dictionary] = []

func set_source(source: Node3D, strength: float, radius: float, active: bool) -> void:
	if not is_instance_valid(source):
		return
	if not active:
		_sources.erase(source)
	elif not _sources.has(source):
		_sources[source] = {"strength":clampf(strength,0.0,1.0),"radius":maxf(radius,0.1)}

func pulse(point: Vector3, strength: float, radius: float, duration: float, source: Node3D = null) -> void:
	if not point.is_finite() or strength <= 0.0 or radius <= 0.0 or duration <= 0.0:
		return
	if _pulses.size() >= 64:
		_pulses.pop_front()
	_pulses.append({"point":point,"strength":clampf(strength,0.0,1.0),"radius":radius,"duration":duration,"remaining":duration,"source":source})

func level_at(point: Vector3, listener: Node3D = null) -> float:
	var level := 0.0
	for source in _sources:
		if not is_instance_valid(source) or source == listener or source.is_queued_for_deletion():
			continue
		var data: Dictionary = _sources[source]
		level += data.strength*_falloff(point,source.global_position,data.radius)
	for data: Dictionary in _pulses:
		if listener != null and data.source == listener:
			continue
		level += data.strength*_falloff(point,data.point,data.radius)*data.remaining/data.duration
	return clampf(level,0.0,1.0)

func clear() -> void:
	_sources.clear()
	_pulses.clear()

func _falloff(point: Vector3, origin: Vector3, radius: float) -> float:
	var weight := clampf(1.0-point.distance_to(origin)/radius,0.0,1.0)
	return weight*weight

func _process(delta: float) -> void:
	for source in _sources.keys():
		if not is_instance_valid(source) or source.is_queued_for_deletion():
			_sources.erase(source)
	for index in range(_pulses.size()-1,-1,-1):
		_pulses[index].remaining -= delta
		if _pulses[index].remaining <= 0.0:
			_pulses.remove_at(index)
