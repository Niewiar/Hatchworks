class_name ResourceInventory
extends Node

signal changed(kind: KIND, amount: float)

enum KIND { GRASS = 0, MOSS = 2, SAND = 3, GROUND_ROCK = 4, FIBER = 5, HERBS = 6, WOOD = 9, STONE = 10 }

const RESERVED_KINDS := [1, 7, 8]

const GROUND_TYPES := [KIND.GRASS, KIND.MOSS, KIND.SAND, KIND.GROUND_ROCK]
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

func add(kind: int, quantity: float) -> void:
	if not _amounts.has(kind) or not is_finite(quantity) or quantity <= 0.0:
		return
	_amounts[kind] += quantity
	changed.emit(kind,_amounts[kind])

func quantity_text(kind: int) -> String:
	return "%.1f" % amount(kind) if kind in GROUND_TYPES else str(floori(amount(kind)+0.000001))
