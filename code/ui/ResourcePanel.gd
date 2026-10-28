extends PanelContainer

const COUNTER := preload("res://scenes/ui/resource_counter.tscn")

@export var inventory: ResourceInventory
@export var ground_only := false

func _ready() -> void:
	var existing: Array[int] = []
	for counter: ResourceCounter in $Counters.get_children():
		existing.append(counter.resource_kind)
	for data in inventory.definitions:
		if (data.kind in ResourceInventory.GROUND_TYPES) == ground_only and data.kind not in existing:
			var counter := COUNTER.instantiate() as ResourceCounter
			counter.name = data.display_name.to_pascal_case()+str(data.kind)
			counter.resource_kind = data.kind
			$Counters.add_child(counter)
	for counter: ResourceCounter in $Counters.get_children():
		counter.initialize(inventory)
