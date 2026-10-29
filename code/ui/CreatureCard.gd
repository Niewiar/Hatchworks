class_name CreatureCard
extends VBoxContainer

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
	for pair in [[$Requirements/Water,"water"],[$Requirements/Soil,"soil"]]:
		var control := pair[0] as Control
		control.mouse_entered.connect(_show_icon_term.bind(control,pair[1]))
		control.mouse_exited.connect(func(): _tooltips.hide_text(control))

func configure(data: CreatureSpecies, sex: int, database: GameDatabase, tooltips: TooltipController) -> void:
	_species = data
	_sex = sex
	_database = database
	_tooltips = tooltips
	$Name.text = data.display_name
	$Sex/Text.text = "Male" if sex == Creature.SEX.MALE else "Female"
	$Sex/Icon.texture = load("res://assets/ui/male.png" if sex == Creature.SEX.MALE else "res://assets/ui/female.png")
	$Description.text = database.rich_description(data.description)
	var food: ResourceDefinition
	for resource in database.resources:
		if resource.kind == data.food_resource:
			food = resource
	$Food/Icon.texture = food.icon if food != null else null
	$Food/Name.text = food.display_name if food != null else "Food"

func _show_sex() -> void:
	_tooltips.show_hint("Sex of this individual: "+("male" if _sex == Creature.SEX.MALE else "female"),$Sex)

func _show_term(meta: Variant) -> void:
	_show_icon_term($Description,str(meta))

func _show_icon_term(control: Control, key: String) -> void:
	var term := _database.term(key)
	if term != null:
		_tooltips.show_hint(term.display_name+"\n"+term.description,control)

func _show_food() -> void:
	for resource in _database.resources:
		if resource.kind == _species.food_resource:
			var term := _database.term(str(resource.id))
			_tooltips.show_hint(resource.display_name+"\n"+(term.description if term != null else resource.description),$Food/Icon)
