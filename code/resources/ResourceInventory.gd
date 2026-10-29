class_name ResourceInventory
extends Node

signal added(kind: KIND, quantity: float)
signal changed(kind: KIND, amount: float)

enum KIND { FIBER = 5, HERBS = 6, WOOD = 9, STONE = 10 }

const RESERVED_KINDS := [0, 1, 2, 3, 4, 7, 8]

var definitions: Array[ResourceDefinition] = []

var _amounts: Dictionary[int, float] = {}

func _ready() -> void:
	for kind in KIND.values():
		_amounts[kind] = 0.0

func configure(values: Array[ResourceDefinition]) -> void:
	definitions = values
	_amounts.clear()
	for data in definitions:
		_amounts[data.kind] = maxf(0.0,data.starting_amount)

func definition(kind: int) -> ResourceDefinition:
	for data in definitions:
		if data.kind == kind:
			return data
	return null

func resource_name(kind: int) -> String:
	var data := definition(kind)
	return data.display_name if data != null else "Unknown resource"

func amount(kind: int) -> float:
	return _amounts.get(kind,0.0)

func can_afford(kind: int, quantity: float) -> bool:
	return _amounts.has(kind) and is_finite(quantity) and quantity >= 0.0 and amount(kind)+0.00000001 >= quantity

func spend(kind: int, quantity: float) -> bool:
	if not can_afford(kind,quantity):
		return false
	if quantity > 0.0:
		_amounts[kind] = maxf(0.0,_amounts[kind]-quantity)
		changed.emit(kind,_amounts[kind])
	return true

func can_afford_costs(costs: Dictionary[int, int]) -> bool:
	for kind in costs:
		if not can_afford(kind,costs[kind]):
			return false
	return true

func spend_costs(costs: Dictionary[int, int]) -> bool:
	if not can_afford_costs(costs):
		return false
	for kind in costs:
		_amounts[kind] = maxf(0.0,_amounts[kind]-costs[kind])
	for kind in costs:
		if costs[kind] > 0:
			changed.emit(kind,_amounts[kind])
	return true

func add(kind: int, quantity: float) -> void:
	if not _amounts.has(kind) or not is_finite(quantity) or quantity <= 0.0:
		return
	_amounts[kind] += quantity
	changed.emit(kind,_amounts[kind])
	added.emit(kind,quantity)

func quantity_text(kind: int) -> String:
	return str(floori(amount(kind)+0.000001))
