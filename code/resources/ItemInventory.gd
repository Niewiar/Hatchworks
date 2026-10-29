class_name ItemInventory
extends Node

signal item_added(id: StringName, count: int)
signal changed

var _amounts: Dictionary[StringName, int] = {}

func amount(id: StringName) -> int:
	return _amounts.get(id,0)

func add(id: StringName, count: int = 1) -> void:
	if id.is_empty() or count <= 0:
		return
	_amounts[id] = amount(id)+count
	changed.emit()
	item_added.emit(id,count)

func spend(id: StringName, count: int = 1) -> bool:
	if count <= 0 or amount(id) < count:
		return false
	_amounts[id] -= count
	changed.emit()
	return true
