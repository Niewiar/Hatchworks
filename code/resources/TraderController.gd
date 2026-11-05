class_name TraderController
extends Node

signal exchanged(source: int, target: int, given: float, received: float)

const SCIENCE := 2147483647

var _database: GameDatabase
var _inventory: ResourceInventory
var _science: ScienceController
var _exchanging := false

func initialize(database: GameDatabase, inventory: ResourceInventory, science: ScienceController) -> void:
	_database = database
	_inventory = inventory
	_science = science

func resources() -> Array[ResourceDefinition]:
	var result: Array[ResourceDefinition] = []
	if _database != null:
		for data: ResourceDefinition in _database.resources:
			if is_finite(data.trade_value) and data.trade_value > 0.0:
				result.append(data)
	return result

func available(kind: int) -> float:
	if _inventory == null or _science == null:
		return 0.0
	return float(_science.amount) if kind == SCIENCE else _inventory.amount(kind)

func quantity_step(kind: int) -> float:
	return 0.01 if kind in ResourceInventory.GROUND_TYPES else 1.0

func quote(source: int, target: int, quantity: float) -> Dictionary:
	var result := {"valid":false,"reason":"Choose two different resources.","source":source,"target":target,"given":0.0,"received":0.0,"source_before":available(source),"source_after":available(source),"target_before":available(target),"target_after":available(target)}
	if _database == null or _inventory == null or _science == null or _database.world == null:
		result.reason = "Trading is unavailable."
		return result
	var destination := _inventory.definition(target)
	var origin := _inventory.definition(source)
	if source == target or destination == null or (source != SCIENCE and origin == null):
		return result
	if not is_finite(destination.trade_value) or destination.trade_value <= 0.0 or (source != SCIENCE and (not is_finite(origin.trade_value) or origin.trade_value <= 0.0)):
		result.reason = "This resource cannot be traded."
		return result
	if not is_finite(quantity) or quantity <= 0.0 or quantity > 1000000000000.0:
		result.reason = "Enter a positive amount."
		return result
	var step := quantity_step(source)
	var given := roundf(quantity/step)*step
	if given < step or absf(given-quantity) > 0.000001:
		result.reason = "Enter whole units, or hundredths of a square metre for terrain."
		return result
	var worth := _database.world.science_trade_value if source == SCIENCE else origin.trade_value*(1.0-_database.world.trade_fee_percent/100.0)
	if not is_finite(worth) or worth <= 0.0:
		result.reason = "Trading is unavailable."
		return result
	var target_step := quantity_step(target)
	var received := floorf(given*worth/destination.trade_value/target_step+0.000000001)*target_step
	if not is_finite(received) or received < target_step:
		result.reason = "Offer more to receive at least one unit."
		return result
	result.given = given
	result.received = received
	result.source_after = result.source_before-given
	result.target_after = result.target_before+received
	if result.source_before+0.00000001 < given:
		result.reason = "Not enough science." if source == SCIENCE else "Not enough resources."
		return result
	if not is_finite(result.target_after) or result.target_after > 1000000000000.0:
		result.reason = "The resulting amount is too large."
		return result
	result.source_after = maxf(0.0,result.source_after)
	result.reason = "Ready to exchange."
	result.valid = true
	return result

func exchange(source: int, target: int, quantity: float, origin: Variant = null) -> bool:
	if _exchanging:
		return false
	var offer := quote(source,target,quantity)
	if not offer.valid:
		return false
	_exchanging = true
	var paid := _science.spend(roundi(offer.given)) if source == SCIENCE else _inventory.spend(source,offer.given)
	if paid:
		_inventory.add(target,offer.received,origin)
	_exchanging = false
	if paid:
		exchanged.emit(source,target,offer.given,offer.received)
	return paid

