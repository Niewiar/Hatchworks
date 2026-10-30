class_name ResourcePanel
extends MarginContainer

const COUNTER := preload("res://scenes/ui/resource_counter.tscn")

@export var inventory: ResourceInventory
@export var science: ScienceController
@export var tooltip_controller: TooltipController

var _pending_science := 0

func _ready() -> void:
	science.changed.connect(_on_science_changed)
	_on_science_changed(science.amount)
	%ScienceCounter.mouse_entered.connect(func(): tooltip_controller.show_hint(tr("Science\nEvery new discovery brings another spark of understanding."),%ScienceCounter))
	%ScienceCounter.mouse_exited.connect(tooltip_controller.hide_text.bind(%ScienceCounter))
	var existing: Array[int] = []
	for child in %Counters.get_children():
		if not child is ResourceCounter:
			continue
		var counter := child as ResourceCounter
		existing.append(counter.resource_kind)
	for data in inventory.definitions:
		if data.kind not in existing:
			var counter := COUNTER.instantiate() as ResourceCounter
			counter.name = data.display_name.to_pascal_case()+str(data.kind)
			counter.resource_kind = data.kind
			%Counters.add_child(counter)
	for child in %Counters.get_children():
		if not child is ResourceCounter:
			continue
		var counter := child as ResourceCounter
		counter.initialize(inventory)

func _on_science_changed(amount: int) -> void:
	%ScienceValue.text = str(maxi(0,amount-_pending_science))

func resource_anchor(kind: int) -> Control:
	var counter := _counter(kind)
	return counter.reward_anchor() if counter != null else null

func science_anchor() -> Control:
	return %ScienceCounter.get_node("Icon")

func begin_resource_gain(kind: int, quantity: float) -> void:
	var counter := _counter(kind)
	if counter != null:
		counter.begin_gain(quantity)

func finish_resource_gain(kind: int, quantity: float) -> void:
	var counter := _counter(kind)
	if counter != null:
		counter.finish_gain(quantity)

func begin_science_gain(points: int) -> void:
	_pending_science += points

func finish_science_gain(points: int) -> void:
	_pending_science = maxi(0,_pending_science-points)
	_on_science_changed(science.amount)

func reset_presentation() -> void:
	_pending_science = 0
	_on_science_changed(science.amount)
	for counter in %Counters.get_children():
		if counter is ResourceCounter:
			counter.reset_presentation()

func _counter(kind: int) -> ResourceCounter:
	for child in %Counters.get_children():
		if child is ResourceCounter and child.resource_kind == kind:
			return child
	return null
