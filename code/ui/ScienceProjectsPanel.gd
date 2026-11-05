class_name ScienceProjectsPanel
extends MarginContainer

@export var map_manager: MapManager
@export var tooltip_controller: TooltipController

const CARD = preload("res://scenes/ui/science_project_card.tscn")
const COST = preload("res://scenes/ui/science_project_cost.tscn")

var _message := ""

func _ready() -> void:
	hide()
	map_manager.mode_changed.connect(_mode_changed)
	map_manager.science_projects.changed.connect(_refresh)
	map_manager.science_projects.countdown_changed.connect(_countdown_changed)
	map_manager.science_projects.completed.connect(_completed)
	map_manager.inventory.changed.connect(_inventory_changed)
	map_manager.science.changed.connect(_science_changed)
	%Close.pressed.connect(map_manager.set_mode.bind(MapManager.MODE.NONE))
	%Close.mouse_entered.connect(_button_hint.bind(%Close))
	%Close.mouse_exited.connect(tooltip_controller.hide_text.bind(%Close))

func _mode_changed(mode: MapManager.MODE) -> void:
	visible = mode == MapManager.MODE.SCIENCE_PROJECTS
	if visible:
		_message = ""
		_refresh()
	else:
		tooltip_controller.hide_tooltip()

func _refresh() -> void:
	if not visible:
		return
	tooltip_controller.hide_tooltip()
	for child in %Projects.get_children():
		%Projects.remove_child(child)
		child.queue_free()
	var offers := map_manager.science_projects.offers()
	for offer: Dictionary in offers:
		var card := CARD.instantiate() as PanelContainer
		card.set_meta("offer_id",int(offer.id))
		%Projects.add_child(card)
		card.get_node("Margin/Content/Title").text = tr(offer.title)
		card.get_node("Margin/Content/Description").text = tr(offer.description)
		card.get_node("Margin/Content/Reward/Value").text = tr("+%d Science") % int(offer.reward)
		for kind: int in offer.costs:
			var row := COST.instantiate() as HBoxContainer
			row.set_meta("kind",kind)
			row.set_meta("required",int(offer.costs[kind]))
			card.get_node("Margin/Content/Costs").add_child(row)
			var data := map_manager.inventory.definition(kind)
			row.get_node("Icon").texture = data.icon if data != null else null
			row.get_node("Name").text = tr(map_manager.inventory.resource_name(kind))
		var button := card.get_node("Margin/Content/Complete") as Button
		button.pressed.connect(_complete.bind(int(offer.id),button))
		button.mouse_entered.connect(_project_hint.bind(int(offer.id),button))
		button.mouse_exited.connect(tooltip_controller.hide_text.bind(button))
	for index in ScienceProjectsController.MAX_OFFERS-offers.size():
		var card := CARD.instantiate() as PanelContainer
		%Projects.add_child(card)
		card.get_node("Margin/Content").hide()
		card.get_node("Margin/Pending").show()
	_refresh_values()
	_refresh_footer()

func _refresh_values() -> void:
	if not visible:
		return
	%ScienceBalance.text = tr("Science: %d") % map_manager.science.amount
	for card: Control in %Projects.get_children():
		if not card.has_meta("offer_id"):
			continue
		var offer := map_manager.science_projects.quote(int(card.get_meta("offer_id")))
		for row: Control in card.get_node("Margin/Content/Costs").get_children():
			var kind := int(row.get_meta("kind"))
			var required := int(row.get_meta("required"))
			var amount := row.get_node("Amount") as Label
			amount.text = _quantity(kind,required)
			amount.modulate = Color(0.36,0.46,0.28) if map_manager.inventory.can_afford(kind,required) else Color(0.62,0.25,0.17)
		card.get_node("Margin/Content/Complete").disabled = not offer.valid

func _refresh_footer() -> void:
	var count := map_manager.science_projects.offers().size()
	%ProjectCount.text = tr("Available projects: %d / %d") % [count,ScienceProjectsController.MAX_OFFERS]
	if count >= ScienceProjectsController.MAX_OFFERS:
		%NextProject.text = tr("All projects available")
	elif count == 0 and map_manager.science_projects.seconds_remaining() <= 0:
		%NextProject.text = tr("Discover resources to unlock projects.")
	else:
		var seconds := map_manager.science_projects.seconds_remaining()
		%NextProject.text = tr("Next project in %s") % ("%d:%02d" % [seconds/60,seconds%60])
	%Status.text = _message
	%Status.visible = not _message.is_empty()

func _complete(id: int, button: Button) -> void:
	if not map_manager.science_projects.complete(id,button.get_global_rect().get_center()):
		_message = tr(map_manager.science_projects.quote(id).reason)
		_refresh_values()
		_refresh_footer()

func _completed(title: String, points: int) -> void:
	_message = tr("Completed %s. Earned %d Science.") % [tr(title),points]
	if visible:
		_refresh_values()
		_refresh_footer()

func _countdown_changed(_seconds: int) -> void:
	if visible:
		_refresh_footer()

func _inventory_changed(_kind: int, _amount: float) -> void:
	_refresh_values()

func _science_changed(_amount: int) -> void:
	_refresh_values()

func _quantity(kind: int, value: float) -> String:
	return "%.2f m²" % value if kind in ResourceInventory.GROUND_TYPES else str(floori(value+0.000001))

func _project_hint(id: int, button: Button) -> void:
	var offer := map_manager.science_projects.quote(id)
	tooltip_controller.show_text(tr("Give the listed materials and receive Science.") if offer.valid else tr(offer.reason),button)

func _button_hint(button: Button) -> void:
	tooltip_controller.show_text(tr(str(button.get_meta("tooltip_title",button.text))),button)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_message = ""
		_refresh()
