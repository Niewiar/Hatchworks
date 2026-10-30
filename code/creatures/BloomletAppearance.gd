class_name BloomletAppearance
extends Node3D

var _sex := 0

func _ready() -> void:
	apply_sex(_sex)

func apply_sex(value: int) -> void:
	_sex = value
	var male := find_child("MaleBody",true,false) as MeshInstance3D
	var female := find_child("FemaleBody",true,false) as MeshInstance3D
	if male != null:
		male.visible = value != 1
	if female != null:
		female.visible = value == 1
