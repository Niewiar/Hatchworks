class_name BreedingPanel
extends VBoxContainer

var _creature: Creature
var _map: Node3D
var _message := ""

func _ready() -> void:
	%Breed.pressed.connect(_on_action)

func configure(creature: Creature, map: Node3D) -> void:
	_creature = creature
	_map = map
	_message = ""
	refresh()

func refresh() -> void:
	var active: bool = _map.breeding.is_breeding(_creature)
	var status: String = _map.breeding.status(_creature)
	%BreedStatus.text = _message if not _message.is_empty() and status.begins_with(tr("Ready")) else status
	%BreedProgress.visible = active
	%BreedProgress.value = _map.breeding.progress(_creature)*100.0
	%Breed.text = tr("Cancel breeding") if active else (tr("Call a mate") if _creature.sex == Creature.SEX.MALE else tr("Find a calling male"))
	%Breed.disabled = not active and not status.begins_with(tr("Ready"))
	var data := _creature.species_data()
	var habitat := tr("dry ground")
	if data.habitat_ground >= 0:
		habitat = tr("rocky ground") if data.habitat_ground == 4 else (tr("grassy ground") if data.habitat_ground == 0 else tr("their preferred ground"))
	if data.requires_water:
		habitat += tr(" and accessible water")
	%BreedConditions.text = tr("Both need %s and at least %d%% satiety.\nRecovery: %.0f s · Satiety cost: %d%% each.") % [habitat,ceili(maxf(data.breeding_min_satiety,data.breeding_satiety_cost)),data.breeding_cooldown,ceili(data.breeding_satiety_cost)]

func _on_action() -> void:
	_message = ""
	if _map.breeding.is_breeding(_creature):
		_map.breeding.cancel(_creature)
	elif not _map.breeding.start(_creature):
		_message = tr("No well-fed partner is ready nearby.")
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_message = ""
		if is_instance_valid(_creature):
			refresh()
