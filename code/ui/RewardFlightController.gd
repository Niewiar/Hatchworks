class_name RewardFlightController
extends Control

signal item_arrived(id: StringName)
signal presentation_reset

@export var map_manager: MapManager
@export var resource_panel: ResourcePanel
@export var game_toolbar: Control
@export_range(1,16,1) var maximum_flights := 8
@export_range(0.3,2.0,0.05) var flight_seconds := 2.0

const FLIGHT = preload("res://scenes/ui/reward_flight.tscn")
var _queued: Array[Dictionary] = []
var _active: Array[Dictionary] = []
var _pending_items: Dictionary[StringName,int] = {}

func _ready() -> void:
	map_manager.inventory.gained.connect(_on_resource_gained)
	map_manager.items.gained.connect(_on_item_gained)
	map_manager.science.gained.connect(_on_science_gained)
	set_process(false)

func _on_resource_gained(kind: int, quantity: float, origin: Variant) -> void:
	var data := map_manager.inventory.definition(kind)
	if data == null or resource_panel.resource_anchor(kind) == null:
		return
	resource_panel.begin_resource_gain(kind,quantity)
	_enqueue({"category":0,"key":kind,"quantity":quantity,"origin":origin,"icon":data.icon})

func _on_item_gained(id: StringName, count: int, origin: Variant) -> void:
	var info := map_manager.database.item_info(id)
	_pending_items[id] = _pending_items.get(id,0)+count
	_enqueue({"category":1,"key":id,"quantity":float(count),"origin":origin,"icon":info.icon})

func _on_science_gained(points: int, origin: Variant) -> void:
	resource_panel.begin_science_gain(points)
	_enqueue({"category":2,"key":0,"quantity":float(points),"origin":origin,"icon":load("res://assets/ui/discoveries.png")})

func _enqueue(entry: Dictionary) -> void:
	for waiting in _queued:
		if waiting.category == entry.category and waiting.key == entry.key and _same_origin(waiting.origin,entry.origin):
			waiting.quantity += entry.quantity
			set_process(true)
			return
	_queued.append(entry)
	set_process(true)

func _same_origin(first: Variant, second: Variant) -> bool:
	if first is Vector3 and second is Vector3:
		return first.distance_squared_to(second) < 0.36
	if first is Vector2 and second is Vector2:
		return first.distance_squared_to(second) < 1600.0
	return first == null and second == null

func _process(delta: float) -> void:
	var covered := map_manager.hatch_presentation != null and map_manager.hatch_presentation.visible
	for entry in _active:
		entry.view.visible = not covered
	if covered:
		return
	while _active.size() < maximum_flights and not _queued.is_empty():
		_start(_queued.pop_front())
	for entry in _active.duplicate():
		entry.elapsed += delta
		var t := clampf(entry.elapsed/flight_seconds,0.0,1.0)
		var eased := t*t*(3.0-2.0*t)
		var target := _destination(entry)
		var start: Vector2 = entry.start
		var bend := clampf(start.distance_to(target)*0.15,45.0,150.0)
		var point := start.bezier_interpolate(start+Vector2(25,-bend),target+Vector2(-20,bend*0.5),target,eased)
		var view := entry.view as RewardFlight
		view.pivot_offset = view.size*0.5
		view.position = point-view.get_combined_minimum_size()*0.5
		view.scale = Vector2.ONE*lerpf(1.0,0.52,eased)
		view.modulate.a = smoothstep(0.0,0.07,t)*(1.0-smoothstep(0.83,1.0,t))
		if t >= 1.0:
			_finish(entry)
	set_process(not _queued.is_empty() or not _active.is_empty())

func _start(entry: Dictionary) -> void:
	var view := FLIGHT.instantiate() as RewardFlight
	view.configure(entry.icon,entry.quantity)
	add_child(view)
	entry.view = view
	entry.start = _origin_point(entry.origin)
	entry.elapsed = 0.0
	_active.append(entry)

func _origin_point(origin: Variant) -> Vector2:
	var bounds := get_viewport_rect().grow(-24.0)
	var point := bounds.get_center()
	if origin is Vector3 and origin.is_finite():
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			if camera.is_position_behind(origin):
				var local := camera.to_local(origin)
				var direction := Vector2(local.x,-local.y)
				if direction.length_squared() < 0.001:
					direction = Vector2.DOWN
				point += direction.normalized()*maxf(bounds.size.x,bounds.size.y)*2.0
			else:
				point = camera.unproject_position(origin)
	elif origin is Vector2 and origin.is_finite():
		point = origin
	return point.clamp(bounds.position,bounds.end)

func _destination(entry: Dictionary) -> Vector2:
	var anchor: Control
	if entry.category == 0:
		anchor = resource_panel.resource_anchor(entry.key)
	elif entry.category == 1:
		anchor = game_toolbar.backpack_anchor()
	else:
		anchor = resource_panel.science_anchor()
	return anchor.get_global_rect().get_center() if is_instance_valid(anchor) else get_viewport_rect().get_center()

func _finish(entry: Dictionary) -> void:
	_active.erase(entry)
	remove_child(entry.view)
	entry.view.queue_free()
	if entry.category == 0:
		resource_panel.finish_resource_gain(entry.key,entry.quantity)
	elif entry.category == 2:
		resource_panel.finish_science_gain(roundi(entry.quantity))
	else:
		var id := StringName(entry.key)
		_pending_items[id] = maxi(0,_pending_items.get(id,0)-roundi(entry.quantity))
		if _pending_items[id] == 0:
			_pending_items.erase(id)
		item_arrived.emit(id)

func item_in_transit(id: StringName) -> bool:
	return _pending_items.get(id,0) > 0

func reset_presentation() -> void:
	for entry in _active:
		remove_child(entry.view)
		entry.view.queue_free()
	_active.clear()
	_queued.clear()
	_pending_items.clear()
	resource_panel.reset_presentation()
	set_process(false)
	presentation_reset.emit()
