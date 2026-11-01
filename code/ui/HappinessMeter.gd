class_name HappinessMeter
extends HBoxContainer

const ICONS := [preload("res://assets/ui/illustrated/happiness_unhappy.svg"),preload("res://assets/ui/illustrated/happiness_neutral.svg"),preload("res://assets/ui/illustrated/happiness_happy.svg")]
const STATES := ["Unhappy","Neutral","Happy"]
const COLORS := [Color(0.73,0.43,0.30),Color(0.82,0.65,0.32),Color(0.51,0.62,0.31)]
var _creature: Creature
var _tooltips: TooltipController
var _hovered := false
var _fill: StyleBoxFlat

func _ready() -> void:
	_fill = $Scale/Track/Bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	$Scale/Track/Bar.add_theme_stylebox_override("fill",_fill)
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
	var state := _creature.mood()
	$Icon.texture = ICONS[state]
	$Scale/Track/Bar.value = _creature.happiness
	_fill.bg_color = COLORS[state]
	$Value.text = tr("%d%%") % floori(_creature.happiness)
	if _hovered and is_visible_in_tree():
		_show_hint()

func _show_hint() -> void:
	if not is_instance_valid(_creature) or not is_instance_valid(_tooltips):
		return
	_hovered = true
	var factors := _creature.happiness_factors()
	var species := _creature.species_data()
	var unhappy := String.num(species.unhappy_threshold,2)
	var happy := String.num(species.happy_threshold,2)
	var lines := PackedStringArray([
		tr("Happiness: %d%% · %s") % [floori(_creature.happiness),tr(STATES[_creature.mood()])],
		tr("Unhappy: below %s%% · Neutral: %s%% to below %s%% · Happy: from %s%%") % [unhappy,unhappy,happy,happy],
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
