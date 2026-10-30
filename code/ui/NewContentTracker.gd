class_name NewContentTracker
extends Node

signal changed

var _map: MapManager
var _seen: Dictionary[String,bool] = {}

func initialize(map: MapManager) -> void:
	_map = map
	map.items.changed.connect(func(): changed.emit())
	map.items.item_used.connect(mark_item_seen)
	map.discoveries.discovered.connect(func(_entry): changed.emit())
	map.discoveries.seen.connect(func(_id): changed.emit())
	map.building_controller.building_placed.connect(_on_building_placed)

func mark_item_seen(id: StringName) -> void:
	_mark("item:"+str(id))

func mark_building_seen(id: StringName) -> void:
	_mark("building:"+str(id))

func mark_fence_seen(id: StringName) -> void:
	_mark("fence:"+str(id))

func mark_tool_seen(mode: MapManager.MODE, index: int) -> void:
	if mode == MapManager.MODE.SCULPT:
		_mark("sculpt:"+str(index))
	elif mode == MapManager.MODE.HARVEST:
		_mark("harvest:"+str(index))

func item_is_unread(id: StringName) -> bool:
	return _map.items.amount(id) > 0 and not _seen.has("item:"+str(id))

func building_is_unread(id: StringName) -> bool:
	return not _seen.has("building:"+str(id))

func fence_is_unread(id: StringName) -> bool:
	return not _seen.has("fence:"+str(id))

func tool_is_unread(mode: MapManager.MODE, index: int) -> bool:
	return not _seen.has(("sculpt:" if mode == MapManager.MODE.SCULPT else "harvest:")+str(index))

func unread_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in _map.items._amounts:
		if item_is_unread(id):
			result.append(id)
	return result

func unread_count(mode: MapManager.MODE) -> int:
	var count := 0
	match mode:
		MapManager.MODE.BACKPACK:
			return unread_item_ids().size()
		MapManager.MODE.DISCOVERIES:
			for entry: DiscoveryDefinition in _map.discoveries.known_entries():
				if _map.discoveries.is_unread(entry.id):
					count += 1
		MapManager.MODE.BUILD:
			for data: BuildingDefinition in _map.database.buildings:
				if _map.building_controller.unlocked(data) and building_is_unread(data.id):
					count += 1
			for index in _map.database.construction.fances.size():
				if _map.fances_controller.unlocked(index) and fence_is_unread(_map.database.construction.fances[index].id):
					count += 1
		MapManager.MODE.SCULPT:
			for index in TerrainController.SCULPT_TOOL.values():
				if tool_is_unread(mode,index):
					count += 1
		MapManager.MODE.HARVEST:
			for index in [HarvestController.TOOL.PLANTS,HarvestController.TOOL.AXE,HarvestController.TOOL.MINING]:
				if tool_is_unread(mode,index):
					count += 1
	return count

func capture_state() -> Dictionary:
	return {"seen":_seen.keys()}

func restore_state(state: Dictionary) -> void:
	_seen.clear()
	for key in state.get("seen",[]):
		_seen[str(key)] = true
	changed.emit()

func _mark(key: String) -> void:
	if _seen.has(key):
		return
	_seen[key] = true
	changed.emit()

func _on_building_placed(_building: Node3D, data: BuildingDefinition) -> void:
	mark_building_seen(data.id)
