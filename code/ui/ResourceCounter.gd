class_name ResourceCounter
extends HBoxContainer

@export var resource_kind: ResourceInventory.KIND = ResourceInventory.KIND.FIBER
@export var icon: Texture2D

@onready var _value: Label = $Text/Value

var _inventory: ResourceInventory

func _ready() -> void:
	$Icon.texture = icon


func initialize(inventory: ResourceInventory) -> void:
	_inventory = inventory
	$Text/Name.text = inventory.resource_name(resource_kind)
	var data := inventory.definition(resource_kind)
	if data != null:
		$Icon.texture = data.icon
	inventory.changed.connect(_on_changed)
	_on_changed(resource_kind,inventory.amount(resource_kind))

func _on_changed(kind: int, _amount: float) -> void:
	if kind == resource_kind:
		_value.text = _inventory.quantity_text(resource_kind)
