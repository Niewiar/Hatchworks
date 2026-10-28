@tool
extends VBoxContainer

signal edited(entry: Resource, property: String, value: Variant)
signal asset_requested(field: Control, multiple: bool, asset_type: String)

var _entry: Resource
var _data: Dictionary
var _syncing := false
var _database: GameDatabase

func configure(entry: Resource, data: Dictionary, database: GameDatabase) -> void:
	_entry = entry
	_data = data
	_database = database
	$Label.text = data.label
	for child in $Editors.get_children():
		child.hide()
	match data.type:
		"text":
			$Editors/Text.show()
			$Editors/Text.editable = not (entry is CreatureSpecies and entry.id == &"mossling" and data.key == "id")
			$Editors/Text.text_submitted.connect(func(_text): _submit())
			$Editors/Text.focus_exited.connect(_submit)
		"multiline":
			$Editors/Multiline.show()
			$Editors/Multiline.focus_exited.connect(_submit)
		"number":
			$Editors/Number.show()
			_setup_number($Editors/Number)
			$Editors/Number.editable = not (entry is ResourceDefinition and data.key == "kind" and entry.kind in ResourceInventory.KIND.values())
			$Editors/Number.value_changed.connect(func(_value): _submit())
		"enum", "resource":
			$Editors/Choice.show()
			if data.type == "resource":
				for resource in database.resources:
					$Editors/Choice.add_item(resource.display_name,resource.kind)
			else:
				for index in data.choices.size():
					$Editors/Choice.add_item(data.choices[index],index)
			$Editors/Choice.item_selected.connect(func(_index): _submit())
		"vector":
			$Editors/Vector.show()
			for number in [$Editors/Vector/Minimum,$Editors/Vector/Maximum]:
				_setup_number(number)
				number.value_changed.connect(func(_value): _submit())
		"color":
			$Editors/Color.show()
			$Editors/Color.color_changed.connect(func(_value): _submit())
		"meshes":
			$Editors/Paths.show()
			$Editors/Paths/Text.focus_exited.connect(_submit)
			$Editors/Paths/Browse.pressed.connect(func(): asset_requested.emit(self,true,"Mesh"))
		_:
			$Editors/Asset.show()
			$Editors/Asset/Path.text_submitted.connect(func(_text): _submit())
			$Editors/Asset/Path.focus_exited.connect(_submit)
			$Editors/Asset/Browse.pressed.connect(func(): asset_requested.emit(self,false,data.type))
			$Editors/Asset/Clear.pressed.connect(func(): edited.emit(_entry,_data.key,null))
	entry.changed.connect(sync)
	sync()

func _setup_number(number: SpinBox) -> void:
	number.min_value = _data.min
	number.max_value = _data.max
	number.step = _data.step

func sync() -> void:
	if not is_instance_valid(_entry):
		return
	_syncing = true
	var value: Variant = _entry.get(_data.key)
	match _data.type:
		"text": $Editors/Text.text = str(value)
		"multiline": $Editors/Multiline.text = value
		"number": $Editors/Number.value = value
		"vector":
			$Editors/Vector/Minimum.value = value.x
			$Editors/Vector/Maximum.value = value.y
		"color": $Editors/Color.color = value
		"enum", "resource": $Editors/Choice.select($Editors/Choice.get_item_index(value))
		"meshes":
			var paths := PackedStringArray()
			for mesh: Mesh in value:
				paths.append(mesh.resource_path if mesh != null else "")
			$Editors/Paths/Text.text = "
".join(paths)
		_:
			$Editors/Asset/Path.text = value.resource_path if value != null else ""
	_syncing = false

func accept_paths(paths: PackedStringArray) -> void:
	if _data.type == "meshes":
		var values := PackedStringArray()
		for mesh: Mesh in _entry.get(_data.key):
			values.append(mesh.resource_path)
		for path in paths:
			if not values.has(path):
				values.append(path)
		$Editors/Paths/Text.text = "
".join(values)
	else:
		$Editors/Asset/Path.text = paths[0]
	_submit()

func _submit() -> void:
	if _syncing:
		return
	var value: Variant
	match _data.type:
		"text": value = StringName($Editors/Text.text.strip_edges()) if _data.key == "id" else $Editors/Text.text
		"multiline": value = $Editors/Multiline.text
		"number": value = int($Editors/Number.value) if typeof(_entry.get(_data.key)) == TYPE_INT else $Editors/Number.value
		"vector": value = Vector2($Editors/Vector/Minimum.value,$Editors/Vector/Maximum.value)
		"color": value = $Editors/Color.color
		"enum", "resource": value = $Editors/Choice.get_selected_id()
		"meshes":
			var meshes: Array[Mesh] = []
			for path in $Editors/Paths/Text.text.split("
",false):
				var asset := _load_asset(path.strip_edges(),"Mesh") as Mesh
				if asset == null:
					$Label.text = _data.label+" · invalid mesh path"
					return
				meshes.append(asset)
			value = meshes
		_:
			var path: String = $Editors/Asset/Path.text.strip_edges()
			value = _load_asset(path,_data.type)
			if not path.is_empty() and value == null:
				$Label.text = _data.label+" · invalid asset path or type"
				return
	$Label.text = _data.label
	if _entry.get(_data.key) != value:
		edited.emit(_entry,_data.key,value)

func _load_asset(path: String, type: String) -> Resource:
	if not path.begins_with("res://") or not ResourceLoader.exists(path):
		return null
	var asset := load(path)
	return asset if asset != null and asset.is_class(type) else null
