class_name TraderPanel
extends MarginContainer

@export var map_manager: MapManager
@export var tooltip_controller: TooltipController

var _source: int = ResourceInventory.KIND.FIBER
var _target: int = ResourceInventory.KIND.WOOD
var _offer: Dictionary = {}
var _updating := false
var _last_exchange := ""

func _ready() -> void:
	hide()
	map_manager.mode_changed.connect(_mode_changed)
	map_manager.inventory.changed.connect(_inventory_changed)
	map_manager.science.changed.connect(_science_changed)
	map_manager.trader.exchanged.connect(_exchanged)
	%Source.item_selected.connect(_source_selected)
	%Target.item_selected.connect(_target_selected)
	%Quantity.value_changed.connect(_quantity_changed)
	%All.pressed.connect(_select_all)
	%Exchange.pressed.connect(_exchange)
	%Close.pressed.connect(map_manager.set_mode.bind(MapManager.MODE.NONE))
	for button: Button in [%All,%Exchange,%Close]:
		button.mouse_entered.connect(_button_hint.bind(button))
		button.mouse_exited.connect(tooltip_controller.hide_text.bind(button))
	_fill_choices()

func _mode_changed(mode: MapManager.MODE) -> void:
	visible = mode == MapManager.MODE.TRADER
	if visible:
		_last_exchange = ""
		_fill_choices()
		_refresh()
	else:
		tooltip_controller.hide_tooltip()

func _fill_choices() -> void:
	_updating = true
	%Source.clear()
	%Target.clear()
	for data: ResourceDefinition in map_manager.trader.resources():
		var title := tr(data.display_name)+(tr(" (m²)") if data.kind in ResourceInventory.GROUND_TYPES else "")
		%Source.add_item(title,data.kind)
		%Target.add_item(title,data.kind)
	%Source.add_item(tr("Science"),TraderController.SCIENCE)
	%Source.select(%Source.get_item_index(_source))
	%Target.select(%Target.get_item_index(_target))
	_updating = false

func _source_selected(index: int) -> void:
	_source = %Source.get_item_id(index)
	if _source == _target:
		_choose_other_target()
	_sync_quantity_step()
	_last_exchange = ""
	_refresh()

func _target_selected(index: int) -> void:
	_target = %Target.get_item_id(index)
	if _target == _source:
		_choose_other_source()
	_last_exchange = ""
	_refresh()

func _choose_other_target() -> void:
	for index in %Target.item_count:
		if %Target.get_item_id(index) != _source:
			_target = %Target.get_item_id(index)
			%Target.select(index)
			return

func _choose_other_source() -> void:
	for index in %Source.item_count:
		if %Source.get_item_id(index) != _target:
			_source = %Source.get_item_id(index)
			%Source.select(index)
			_sync_quantity_step()
			return

func _sync_quantity_step() -> void:
	_updating = true
	%Quantity.step = map_manager.trader.quantity_step(_source)
	%Quantity.value = maxf(%Quantity.step,snappedf(%Quantity.value,%Quantity.step))
	_updating = false

func _quantity_changed(_value: float) -> void:
	if not _updating:
		_last_exchange = ""
		_refresh()

func _select_all() -> void:
	var step := map_manager.trader.quantity_step(_source)
	%Quantity.value = floorf(map_manager.trader.available(_source)/step+0.000000001)*step
	_refresh()

func _exchange() -> void:
	_refresh()
	if _offer.valid:
		map_manager.trader.exchange(_source,_target,%Quantity.value,%Exchange.get_global_rect().get_center())

func _refresh() -> void:
	if not visible or _updating:
		return
	_offer = map_manager.trader.quote(_source,_target,%Quantity.value)
	%SourceIcon.texture = _icon(_source)
	%TargetIcon.texture = _icon(_target)
	%SourceBefore.text = tr("Available: %s") % _quantity(_source,_offer.source_before)
	%SourceAfter.text = tr("After exchange: %s") % _quantity(_source,maxf(0.0,_offer.source_after))
	%TargetBefore.text = tr("Available: %s") % _quantity(_target,_offer.target_before)
	%TargetAfter.text = tr("After exchange: %s") % _quantity(_target,_offer.target_after)
	%Received.text = _quantity(_target,_offer.received)
	%All.disabled = map_manager.trader.available(_source) < map_manager.trader.quantity_step(_source)
	%Exchange.disabled = not _offer.valid
	%Status.text = _last_exchange if not _last_exchange.is_empty() else tr(_offer.reason)
	%Status.modulate = Color(0.36,0.46,0.28) if _offer.valid or not _last_exchange.is_empty() else Color(0.62,0.25,0.17)

func _quantity(kind: int, value: float) -> String:
	return "%.2f m²" % value if kind in ResourceInventory.GROUND_TYPES else str(floori(value+0.000001))

func _icon(kind: int) -> Texture2D:
	if kind == TraderController.SCIENCE:
		return preload("res://assets/ui/illustrated/discoveries.svg")
	var data := map_manager.inventory.definition(kind)
	return data.icon if data != null else null

func _inventory_changed(_kind: int, _amount: float) -> void:
	_refresh()

func _science_changed(_amount: int) -> void:
	_refresh()

func _exchanged(source: int, target: int, given: float, received: float) -> void:
	var source_name := tr("Science") if source == TraderController.SCIENCE else map_manager.inventory.resource_name(source)
	_last_exchange = tr("Exchanged %s %s for %s %s.") % [_quantity(source,given),source_name,_quantity(target,received),map_manager.inventory.resource_name(target)]
	_refresh()

func _button_hint(button: Button) -> void:
	tooltip_controller.show_text(tr(str(button.get_meta("tooltip_title",button.text))),button)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_last_exchange = ""
		_fill_choices()
		_refresh()
