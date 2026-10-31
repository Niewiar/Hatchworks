class_name HappinessMeter
extends HBoxContainer

const ICONS := [preload("res://assets/ui/happiness_unhappy.svg"),preload("res://assets/ui/happiness_neutral.svg"),preload("res://assets/ui/happiness_happy.svg")]
const STATES := ["Unhappy","Neutral","Happy"]
const COLORS := [Color(0.9,0.45,0.35),Color(0.94,0.74,0.3),Color(0.45,0.78,0.4)]
var _creature: Creature
var _tooltips: TooltipController
var _hovered := false

func _ready() -> void:
	mouse_entered.connect(_show_hint)
	mouse_exited.connect(_hide_hint)

func configure(creature: Creature, tooltips: TooltipController) -> void:
	_hide_hint()
	_creature = creature
	_tooltips = tooltips
	refresh()

func refresh() -> void:
	if not is_instance_valid(_creature):
		return
	var state := _state()
	$Icon.texture = ICONS[state]
	$Scale/Track/Bar.value = _creature.happiness
	$Scale/Track/Bar.modulate = COLORS[state]
	$Value.text = tr("%d%%") % floori(_creature.happiness)
	if _hovered and is_visible_in_tree():
		_show_hint()

func _state() -> int:
	return 0 if _creature.happiness < 40.0 else (1 if _creature.happiness < 70.0 else 2)

func _show_hint() -> void:
	if not is_instance_valid(_creature) or not is_instance_valid(_tooltips):
		return
	_hovered = true
	var factors := _creature.happiness_factors()
	var lines := PackedStringArray([
		tr("Happiness: %d%% · %s") % [floori(_creature.happiness),tr(STATES[_state()])],
		tr("Unhappy: 0–39% · Neutral: 40–69% · Happy: 70–100%"),
		"",
		tr("Current conditions: %d%%") % roundi(factors.target),
		tr("Base comfort: +%.1f pts") % factors.base,
		tr("Satiety: +%.1f pts (%d%%)") % [factors.satiety,floori(_creature.satiety)],
		tr("Company: +%.1f pts (%d companions)") % [factors.company,_creature.companions],
		tr("Crowding: %.1f pts") % factors.crowding,
		tr("Noise: %.1f pts") % factors.noise,
		tr("Unwanted neighbours: %.1f pts") % factors.neighbours,
		"",
		tr("Happiness gradually follows these conditions.")
	])
	_tooltips.show_hint("\n".join(lines),self)

func _hide_hint() -> void:
	_hovered = false
	if is_instance_valid(_tooltips):
		_tooltips.hide_text(self)
