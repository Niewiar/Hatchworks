class_name ResourceCounter
extends HBoxContainer

@export var resource_kind: ResourceInventory.KIND = ResourceInventory.KIND.FIBER
@export var icon: Texture2D

@onready var _value: Label = $Text/Value

var _inventory: ResourceInventory
var _pending_gain := 0.0

func _ready() -> void:
	$Icon.texture = icon

func initialize(inventory: ResourceInventory) -> void:
	_inventory = inventory
	$Text/Name.text = inventory.resource_name(resource_kind)
	var data := inventory.definition(resource_kind)
	if data != null:
		$Icon.texture = data.icon
	inventory.changed.connect(_on_changed)
	reset_presentation()

func begin_gain(quantity: float) -> void:
	_pending_gain += quantity

func finish_gain(quantity: float) -> void:
	_pending_gain = maxf(0.0,_pending_gain-quantity)
	_refresh_value()

func reset_presentation() -> void:
	_pending_gain = 0.0
	_refresh_value()

func reward_anchor() -> Control:
	return $Icon

func _on_changed(kind: int, _amount: float) -> void:
	if kind == resource_kind:
		_refresh_value()

func _refresh_value() -> void:
	if _inventory != null:
		_value.text = str(floori(maxf(0.0,_inventory.amount(resource_kind)-_pending_gain)+0.000001))

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _inventory != null:
		$Text/Name.text = _inventory.resource_name(resource_kind)
