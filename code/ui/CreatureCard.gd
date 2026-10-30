class_name CreatureCard
extends VBoxContainer

@export var compact := false

var _database: GameDatabase
var _tooltips: TooltipController
var _species: CreatureSpecies
var _sex := 0

func _ready() -> void:
	$Description.meta_hover_started.connect(_show_term)
	$Description.meta_hover_ended.connect(func(_meta): _tooltips.hide_text($Description))
	$Sex.mouse_entered.connect(_show_sex)
	$Food/Icon.mouse_entered.connect(_show_food)
	$Food/Icon.mouse_exited.connect(func(): _tooltips.hide_text($Food/Icon))
	$Sex.mouse_exited.connect(func(): _tooltips.hide_text($Sex))
	$CompactTraits/Sex.mouse_entered.connect(_show_compact_sex)
	$CompactTraits/Food.mouse_entered.connect(_show_compact_food)
	for control in [$CompactTraits/Sex,$CompactTraits/Food]:
		control.mouse_exited.connect(_tooltips_hide.bind(control))
	for pair in [[$Requirements/Water,"water"],[$Requirements/Soil,"soil"],[$CompactTraits/Water,"water"],[$CompactTraits/Soil,"soil"]]:
		var control := pair[0] as Control
		control.mouse_entered.connect(_show_icon_term.bind(control,pair[1]))
		control.mouse_exited.connect(func(): _tooltips.hide_text(control))

func configure(data: CreatureSpecies, sex: int, database: GameDatabase, tooltips: TooltipController) -> void:
	_species = data
	_sex = sex
	_database = database
	_tooltips = tooltips
	$CompactTraits.visible = compact
	for control in [$Sex,$Description,$RequirementLabel,$Requirements,$FoodLabel,$Food]:
		control.visible = not compact
	$Name.text = data.display_name
	$Sex/Text.text = tr("Male") if sex == Creature.SEX.MALE else tr("Female")
	$Sex/Icon.texture = load("res://assets/ui/male.png" if sex == Creature.SEX.MALE else "res://assets/ui/female.png")
	$Description.text = database.rich_description(data.description)
	$Requirements/Water.visible = data.requires_water
	$Requirements/WaterText.visible = data.requires_water
	var ground_id := _habitat_id()
	var ground := database.discovery(ground_id)
	$Requirements/Soil.texture = ground.icon if ground != null else load("res://assets/ui/gather_ground.png")
	$Requirements/SoilText.text = tr("Soil / rock") if data.production == CreatureSpecies.PRODUCTION.QUARRY else (tr("Grass") if ground_id == &"grass" else tr("Dry soil"))
	var food: ResourceDefinition
	for resource in database.resources:
		if resource.kind == data.food_resource:
			food = resource
	$Food/Icon.texture = food.icon if food != null else null
	$Food/Name.text = food.display_name if food != null else tr("Food")
	$CompactTraits/Sex.texture = $Sex/Icon.texture
	$CompactTraits/Water.visible = data.requires_water
	$CompactTraits/Water.texture = $Requirements/Water.texture
	$CompactTraits/Soil.texture = $Requirements/Soil.texture
	$CompactTraits/Food.texture = $Food/Icon.texture

func _show_sex() -> void:
	_tooltips.show_hint(tr("Male") if _sex == Creature.SEX.MALE else tr("Female"),$Sex)

func _show_term(meta: Variant) -> void:
	_show_icon_term($Description,str(meta))

func _show_icon_term(control: Control, key: String) -> void:
	if control in [$Requirements/Soil,$CompactTraits/Soil]:
		key = str(_habitat_id())
	var term := _database.term(key)
	if term != null:
		_tooltips.show_hint(term.display_name+"\n"+term.description,control)

func _show_food() -> void:
	for resource in _database.resources:
		if resource.kind == _species.food_resource:
			var term := _database.term(str(resource.id))
			_tooltips.show_hint(resource.display_name+"\n"+(term.description if term != null else resource.description),$Food/Icon)

func _habitat_id() -> StringName:
	if _species == null or _species.production == CreatureSpecies.PRODUCTION.NONE:
		return &"soil"
	return &"rock" if _species.production == CreatureSpecies.PRODUCTION.QUARRY else &"grass"

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		if _species != null:
			configure(_species,_sex,_database,_tooltips)

func _tooltips_hide(control: Control) -> void:
	if _tooltips != null:
		_tooltips.hide_text(control)

func _show_compact_sex() -> void:
	_tooltips.show_hint(tr("Male") if _sex == Creature.SEX.MALE else tr("Female"),$CompactTraits/Sex)

func _show_compact_food() -> void:
	for resource in _database.resources:
		if resource.kind == _species.food_resource:
			var term := _database.term(str(resource.id))
			_tooltips.show_hint(resource.display_name+"\n"+(term.description if term != null else resource.description),$CompactTraits/Food)
