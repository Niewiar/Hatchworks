class_name ScienceProjectsController
extends Node

signal changed()
signal countdown_changed(seconds: int)
signal completed(title: String, points: int)

const MAX_OFFERS := 3

var _map: MapManager
var _offers: Array[Dictionary] = []
var _remaining := 300.0
var _next_id := 1
var _started := false
var _completing := false
var _last_seconds := -1
var _rng := RandomNumberGenerator.new()

func initialize(map: MapManager) -> void:
	_map = map
	_map.discoveries.discovered.connect(_on_discovery)
	_map.inventory.changed.connect(_on_inventory)
	_reset()

func _interval() -> float:
	return _map.database.world.science_project_interval

func _reset() -> void:
	_offers.clear()
	_remaining = _interval()
	_next_id = 1
	_started = false
	_rng.seed = _map.terrain_controller.world_seed+3719
	_try_start()
	_update_processing()
	changed.emit()

func _definition(id: StringName) -> ScienceProjectDefinition:
	for data: ScienceProjectDefinition in _map.database.science_projects:
		if data.id == id:
			return data
	return null

func _eligible() -> Array[ScienceProjectDefinition]:
	var result: Array[ScienceProjectDefinition] = []
	for data: ScienceProjectDefinition in _map.database.science_projects:
		var known := true
		for kind: int in data.costs:
			var resource := _map.inventory.definition(kind)
			var discovery := &"rock" if kind == ResourceInventory.KIND.GROUND_ROCK else resource.id
			if not _map.discoveries.knows(discovery) and _map.inventory.amount(kind) <= 0.0:
				known = false
				break
		if known:
			result.append(data)
	return result

func _try_start() -> void:
	if _started or _eligible().is_empty():
		return
	_started = true
	for slot in MAX_OFFERS:
		if not _append_offer():
			break
	_update_processing()
	changed.emit()

func _append_offer() -> bool:
	var candidates: Array[Dictionary] = []
	var unused: Array[Dictionary] = []
	var easy: Array[Dictionary] = []
	var has_easy := false
	for offer: Dictionary in _offers:
		has_easy = has_easy or offer.reward == 1
	for data: ScienceProjectDefinition in _eligible():
		var used := false
		for offer: Dictionary in _offers:
			used = used or offer.project == data.id
		for tier in range(1,4):
			var duplicate := false
			for offer: Dictionary in _offers:
				if offer.project == data.id and offer.reward == data.science_reward*tier:
					duplicate = true
			if duplicate:
				continue
			var candidate := {"data":data,"tier":tier}
			candidates.append(candidate)
			if not used:
				unused.append(candidate)
			if data.science_reward*tier == 1:
				easy.append(candidate)
	var pool := easy if not has_easy and not easy.is_empty() else (unused if not unused.is_empty() else candidates)
	if pool.is_empty():
		return false
	var choice: Dictionary = pool[_rng.randi_range(0,pool.size()-1)]
	var data: ScienceProjectDefinition = choice.data
	var tier: int = choice.tier
	var costs: Dictionary[int,int] = {}
	var worth := 0.0
	for kind: int in data.costs:
		costs[kind] = data.costs[kind]*tier
		worth += costs[kind]*_map.inventory.definition(kind).trade_value
	var reward := data.science_reward*tier
	var required := reward*_map.database.world.science_trade_value*_map.database.world.science_project_cost_ratio
	var multiplier := maxf(1.0,required/worth)
	for kind: int in costs:
		costs[kind] = ceili(costs[kind]*multiplier)
	_offers.append({"id":_next_id,"project":data.id,"costs":costs,"reward":reward})
	_next_id += 1
	return true

func offers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for offer: Dictionary in _offers:
		var item := offer.duplicate(true)
		var data := _definition(offer.project)
		item["title"] = data.display_name
		item["description"] = data.description
		result.append(item)
	return result

func quote(id: int) -> Dictionary:
	var result := {"id":id,"valid":false,"reason":"This project is no longer available.","title":"","description":"","costs":{},"reward":0}
	for offer: Dictionary in offers():
		if offer.id != id:
			continue
		result.merge(offer,true)
		if _map.science.amount > 2147483647-int(offer.reward):
			result.reason = "The science total is too high."
			return result
		var worth := 0.0
		for kind: int in offer.costs:
			worth += offer.costs[kind]*_map.inventory.definition(kind).trade_value
		if worth <= offer.reward*_map.database.world.science_trade_value:
			result.reason = "Project pricing is unavailable."
			return result
		if not _map.inventory.can_afford_costs(offer.costs):
			result.reason = "Not enough materials."
			return result
		result.valid = true
		result.reason = "Ready to submit materials."
		return result
	return result

func complete(id: int, origin: Variant = null) -> bool:
	if _completing:
		return false
	var offer := quote(id)
	if not offer.valid:
		return false
	_completing = true
	var index := -1
	for position in _offers.size():
		if _offers[position].id == id:
			index = position
			break
	var record: Dictionary = _offers[index]
	_offers.remove_at(index)
	if not _map.inventory.spend_costs(offer.costs):
		_offers.insert(index,record)
		_completing = false
		return false
	if not _map.science.award_project(offer.title,offer.reward,origin):
		_offers.insert(index,record)
		_map.inventory.refund_costs(offer.costs)
		changed.emit()
		_completing = false
		return false
	_update_processing()
	completed.emit(offer.title,offer.reward)
	changed.emit()
	_completing = false
	return true

func seconds_remaining() -> int:
	return ceili(_remaining) if _started and _offers.size() < MAX_OFFERS else 0

func _update_processing() -> void:
	set_process(_started and _offers.size() < MAX_OFFERS)
	_emit_countdown()

func _emit_countdown() -> void:
	var seconds := seconds_remaining()
	if seconds != _last_seconds:
		_last_seconds = seconds
		countdown_changed.emit(seconds)

func _process(delta: float) -> void:
	if not _started or get_tree().paused or _offers.size() >= MAX_OFFERS:
		return
	_remaining -= delta
	var added := false
	while _remaining <= 0.0 and _offers.size() < MAX_OFFERS:
		if not _append_offer():
			_remaining = 0.0
			break
		_remaining += _interval()
		added = true
	if _offers.size() == MAX_OFFERS:
		_remaining = _interval()
	_update_processing()
	if added:
		changed.emit()

func _on_discovery(_entry: DiscoveryDefinition) -> void:
	if not _completing:
		_try_start()

func _on_inventory(_kind: int, _amount: float) -> void:
	if not _completing:
		_try_start()

func capture_state() -> Dictionary:
	return {"started":_started,"offers":_offers.duplicate(true),"remaining":_remaining,"next_id":_next_id,"rng_seed":_rng.seed,"rng_state":_rng.state}

func validate_state(state: Variant) -> String:
	var error := "The saved science projects are invalid."
	if not state is Dictionary or not state.get("started") is bool or not state.get("offers") is Array:
		return error
	if state.offers.size() > MAX_OFFERS or (not state.started and not state.offers.is_empty()):
		return error
	if not (state.get("remaining") is float or state.get("remaining") is int) or not is_finite(float(state.remaining)) or state.remaining < 0.0 or state.remaining > 86400.0:
		return error
	if not state.get("next_id") is int or state.next_id < 1 or state.next_id > 1000000000000:
		return error
	if not state.get("rng_seed") is int or not state.get("rng_state") is int:
		return error
	var ids := {}
	for offer in state.offers:
		if not offer is Dictionary or not offer.get("id") is int or offer.id < 1 or offer.id >= state.next_id or ids.has(offer.id):
			return error
		ids[offer.id] = true
		if not (offer.get("project") is String or offer.get("project") is StringName):
			return error
		var data := _definition(StringName(offer.project))
		if data == null or not offer.get("costs") is Dictionary or offer.costs.size() != data.costs.size():
			return error
		if not offer.get("reward") is int or offer.reward < data.science_reward or offer.reward > data.science_reward*3 or offer.reward%data.science_reward != 0:
			return error
		for kind in offer.costs:
			if not kind is int or not data.costs.has(kind) or not offer.costs[kind] is int or offer.costs[kind] < 1 or offer.costs[kind] > 1000000000:
				return error
	return ""

func restore_state(state: Dictionary) -> void:
	if state.is_empty():
		_reset()
		return
	if not validate_state(state).is_empty():
		return
	_offers.clear()
	for record: Dictionary in state.offers:
		var costs: Dictionary[int,int] = {}
		costs.assign(record.costs)
		var worth := 0.0
		for kind: int in costs:
			worth += costs[kind]*_map.inventory.definition(kind).trade_value
		if worth <= record.reward*_map.database.world.science_trade_value:
			var required: float = record.reward*_map.database.world.science_trade_value*_map.database.world.science_project_cost_ratio
			for kind: int in costs:
				costs[kind] = ceili(costs[kind]*required/worth)
		_offers.append({"id":record.id,"project":StringName(record.project),"costs":costs,"reward":record.reward})
	_started = state.started
	_remaining = minf(float(state.remaining),_interval())
	_next_id = state.next_id
	_rng.seed = state.rng_seed
	_rng.state = state.rng_state
	_update_processing()
	changed.emit()
