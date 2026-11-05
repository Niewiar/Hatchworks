@tool
extends HBoxContainer

signal selected(id: String)

var _recipe_id := ""

func _ready() -> void:
	%Edit.pressed.connect(func(): selected.emit(_recipe_id))

func configure(index: ForgeDiscoveryIndex, recipe: Dictionary) -> void:
	_recipe_id = str(recipe.id)
	%Equation.text = ForgeDiscoveryLabels.equation(index, recipe)
