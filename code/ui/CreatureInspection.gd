class_name CreatureInspection
extends VBoxContainer

signal close_requested

const GOOD := Color(0.28,0.42,0.22)
const CAUTION := Color(0.69,0.36,0.20)
const MUTED := Color(0.47,0.41,0.31)
const TERRAIN_ROW = preload("res://scenes/ui/creature_terrain_row.tscn")
const TERRAIN_NAMES := {TerrainController.GROUND_TYPE.GRASS:"Grass",TerrainController.GROUND_TYPE.SOIL:"Soil",TerrainController.GROUND_TYPE.SAND:"Sand",TerrainController.GROUND_TYPE.ROCK:"Rocky ground"}
const TERRAIN_ICONS := {TerrainController.GROUND_TYPE.GRASS:preload("res://assets/ui/illustrated/grass.svg"),TerrainController.GROUND_TYPE.SOIL:preload("res://assets/ui/illustrated/gather_ground.svg"),TerrainController.GROUND_TYPE.SAND:preload("res://assets/ui/illustrated/sand.svg"),TerrainController.GROUND_TYPE.ROCK:preload("res://assets/ui/illustrated/rock.svg")}
const SEX_ICONS := [preload("res://assets/ui/illustrated/male.svg"),preload("res://assets/ui/illustrated/female.svg")]

var _creature: Creature
var _map: MapManager
var _tooltips: TooltipController
var _food: ResourceDefinition
var _unwanted := PackedStringArray()
var _hovered: Control
var _terrain_status: Dictionary = {}
var _terrain_rows: Dictionary[int,Control] = {}

func _ready() -> void:
	%Close.pressed.connect(func(): close_requested.emit())
	for control in [%Close,%Sex,%Activity,%Space,%Company,%Noise,%Neighbours,%Terrain,%Satiety]:
		control.mouse_entered.connect(_show_hint.bind(control))
		control.mouse_exited.connect(_hide_hint.bind(control))

func configure(creature: Creature, map: MapManager, tooltips: TooltipController) -> void:
	_hovered = null
	_creature = creature
	_map = map
	_tooltips = tooltips
	_terrain_status = {}
	_food = map.inventory.definition(creature.species_data().food_resource)
	%Happiness.configure(creature,tooltips)
	%Breeding.configure(creature,map)
	refresh()

func refresh() -> void:
	if not is_instance_valid(_creature) or _creature.is_queued_for_deletion():
		return
	var species := _creature.species_data()
	%Name.text = species.display_name
	%Sex.texture = SEX_ICONS[_creature.sex]
	var activity := _creature.activity_presentation()
	%ActivityName.text = activity.label
	var icon_path := "res://assets/ui/illustrated/"+str(activity.icon)
	%ActivityIcon.texture = load(icon_path+".png") if ResourceLoader.exists(icon_path+".png") else load(icon_path+".svg")
	%Happiness.refresh()
	%SatietyBar.value = _creature.satiety
	%SatietyValue.text = tr("%d%%") % ceili(_creature.satiety)
	%FoodIcon.texture = _food.icon if _food != null else null
	var room := _creature.space_per_creature >= species.preferred_area
	var actual_area := ("≥ "+_area(species.preferred_area)) if _creature.space_per_creature > species.preferred_area else _area(_creature.space_per_creature)
	_set_factor(%Space,tr("%s / %s m²") % [actual_area,_area(species.preferred_area)],1 if room else -1)
	_set_factor(%Company,tr("×%d") % _creature.companions if _creature.companions > 0 else tr("Alone"),1 if _creature.companions > 0 else 0)
	var quiet := _creature.noise_stress < 0.01
	_set_factor(%Noise,tr("At ease") if quiet else tr("Disturbed"),1 if quiet else -1)
	_refresh_neighbours()
	var settling := _unwanted.is_empty() and _creature.species_stress > 0.01
	var neighbours := ", ".join(_unwanted) if not _unwanted.is_empty() else (tr("Settling down") if settling else tr("At ease"))
	_set_factor(%Neighbours,neighbours,-1 if not _unwanted.is_empty() else (0 if settling else 1))
	_refresh_terrain()
	%Breeding.refresh()
	if is_instance_valid(_hovered) and _hovered.is_visible_in_tree():
		_show_hint(_hovered)

func _refresh_terrain() -> void:
	var status := _map.landscape.terrain_status(_creature)
	if status.ready:
		_terrain_status = status
	%TerrainPending.visible = not status.ready
	var kinds: Array[int] = []
	for requirement: Dictionary in _terrain_status.get("requirements",[]):
		var kind: int = requirement.kind
		kinds.append(kind)
		if not _terrain_rows.has(kind):
			var row := TERRAIN_ROW.instantiate() as Control
			%TerrainRows.add_child(row)
			_terrain_rows[kind] = row
		var row: Control = _terrain_rows[kind]
		row.get_node("Header/Icon").texture = TERRAIN_ICONS[kind]
		row.get_node("Header/Name").text = tr(TERRAIN_NAMES[kind])
		row.get_node("Header/Share").text = tr("%s%% / min. %s%%") % [_area(requirement.coverage),_area(requirement.minimum)]
		row.get_node("Progress/Bar").value = requirement.fulfillment*100.0
		var percent := 100 if requirement.met else mini(99,floori(requirement.fulfillment*100.0))
		row.get_node("Progress/Fulfillment").text = tr("%d%% fulfilled") % percent
		row.get_node("Progress/Fulfillment").modulate = GOOD if requirement.met else CAUTION
	for kind: int in _terrain_rows.keys():
		if not kinds.has(kind):
			var row: Control = _terrain_rows[kind]
			%TerrainRows.remove_child(row)
			row.queue_free()
			_terrain_rows.erase(kind)
	%Terrain.visible = not kinds.is_empty() or not status.ready

func _terrain_hint() -> String:
	if _terrain_status.is_empty():
		return tr("Updating the region's ground coverage.")
	var lines := PackedStringArray()
	for requirement: Dictionary in _terrain_status.requirements:
		lines.append(tr("%s: %s%% of dry land; regional minimum %s%%.") % [tr(TERRAIN_NAMES[int(requirement.kind)]),_area(requirement.coverage),_area(requirement.minimum)])
	lines.append(tr("The highest minimum requested by a resident sets the shared regional goal."))
	lines.append(tr("A shortage lowers happiness proportionally, by up to %s points.") % _area(_creature.species_data().terrain_happiness_penalty))
	if _terrain_status.dry_area <= 0.000001:
		lines.append(tr("This region has no dry land."))
	return "\n".join(lines)

func _set_factor(row: Control, value: String, state: int) -> void:
	row.get_node("Value").text = value
	row.get_node("State").text = "✓" if state > 0 else ("!" if state < 0 else "—")
	row.get_node("State").modulate = GOOD if state > 0 else (CAUTION if state < 0 else MUTED)

func _area(value: float) -> String:
	return String.num(value,1).trim_suffix(".0")

func _refresh_neighbours() -> void:
	_unwanted.clear()
	var sample := _map.wellbeing.sample(_creature)
	for id in sample.get("unwanted_species",PackedStringArray()):
		var other := _map.database.creature(StringName(id))
		var label := other.display_name if other != null and _map.discoveries.knows(StringName(id)) else "???"
		if not _unwanted.has(label):
			_unwanted.append(label)
	_unwanted.sort()

func _show_hint(control: Control) -> void:
	if not is_instance_valid(_creature) or not is_instance_valid(_tooltips):
		return
	_hovered = control
	var message := ""
	match control.name:
		&"Close":
			_tooltips.show_text(tr("Close focus - Esc / RMB"),control)
			return
		&"Sex":
			message = tr("Male") if _creature.sex == Creature.SEX.MALE else tr("Female")
		&"Activity":
			message = _creature.activity_presentation().description
		&"Space":
			message = tr("Room to roam: %s m² each.") % _area(_creature.space_per_creature)+"\n"
			message += tr("There is enough room to roam.") if _creature.space_per_creature >= _creature.species_data().preferred_area else tr("This region is crowded. Expand it or move some creatures elsewhere.")
		&"Company":
			message = tr("Company nearby makes it happier.") if _creature.companions > 0 else tr("Another of its kind nearby would help it feel at home.")
		&"Noise":
			message = tr("Noise is not bothering it.") if _creature.noise_stress < 0.01 else tr("Too much noise nearby. Move it to a quieter spot.")
		&"Neighbours":
			if not _unwanted.is_empty():
				message = ", ".join(_unwanted)+"\n"+tr("Unwanted neighbours share this region. Give them separate homes.")
			elif _creature.species_stress > 0.01:
				message = tr("It is settling down after an unwanted neighbour left.")
			else:
				message = tr("No unwanted neighbours share this region.")
		&"Terrain":
			message = _terrain_hint()
		&"Satiety":
			message = (_food.display_name+"\n" if _food != null else "")+tr("A stocked feeder keeps it well fed.")
	_tooltips.show_hint(message,control)

func _hide_hint(control: Control) -> void:
	if _hovered == control:
		_hovered = null
	if is_instance_valid(_tooltips):
		_tooltips.hide_text(control)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()
