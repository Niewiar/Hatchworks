@tool
extends VBoxContainer

signal edited(entry: Resource, property: String, value: Variant)
signal asset_requested(field: Control, multiple: bool, asset_type: String)
signal draft_changed

var _entry: Resource
var _data: Dictionary
var _syncing := false
var _database: GameDatabase
var _last_display: Variant
var _committing := false

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
			$Editors/Text.editable = not data.get("readonly",false) and not (entry is CreatureSpecies and entry.id == &"tuftling" and data.key == "id")
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
		"enum", "resource", "creature", "discovery", "item":
			$Editors/Choice.show()
			if data.type == "discovery":
				$Editors/Choice.add_item("None")
				$Editors/Choice.set_item_metadata(0,&"")
				for discovery in database.discoveries:
					$Editors/Choice.add_icon_item(discovery.icon,discovery.display_name)
					$Editors/Choice.set_item_metadata($Editors/Choice.item_count-1,discovery.id)
			elif data.type == "item":
				$Editors/Choice.add_item("None")
				$Editors/Choice.set_item_metadata(0,&"")
				for egg in database.eggs:
					$Editors/Choice.add_item(egg.display_name)
					$Editors/Choice.set_item_metadata($Editors/Choice.item_count-1,egg.id)
				for flora in database.flora:
					if not flora.sapling_item.is_empty():
						$Editors/Choice.add_item(flora.display_name+" sapling")
						$Editors/Choice.set_item_metadata($Editors/Choice.item_count-1,flora.sapling_item)
			elif data.type == "creature":
				for creature in database.creatures:
					$Editors/Choice.add_item(creature.display_name)
					$Editors/Choice.set_item_metadata($Editors/Choice.item_count-1,creature.id)
			elif data.type == "resource":
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
		"boolean":
			$Editors/Toggle.show()
			$Editors/Toggle.toggled.connect(func(_value): _submit())
		"words", "aversions":
			$Editors/Paths.show()
			$Editors/Paths/Browse.hide()
			$Editors/Paths/Text.focus_exited.connect(_submit)
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
	for editor in [$Editors/Text,$Editors/Multiline,$Editors/Paths/Text,$Editors/Asset/Path,$Editors/Number.get_line_edit(),$Editors/Vector/Minimum.get_line_edit(),$Editors/Vector/Maximum.get_line_edit()]:
		editor.text_changed.connect(_on_draft_changed)
	entry.changed.connect(sync)
	sync()

func _setup_number(number: SpinBox) -> void:
	number.min_value = _data.min
	number.max_value = _data.max
	number.step = _data.step

func sync(force: bool = false) -> void:
	if not is_instance_valid(_entry):
		return
	if not force and not _committing and has_pending_edit():
		return
	var had_draft := has_pending_edit()
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
		"creature", "discovery", "item":
			for index in $Editors/Choice.item_count:
				if $Editors/Choice.get_item_metadata(index) == value:
					$Editors/Choice.select(index)
		"boolean": $Editors/Toggle.button_pressed = value
		"aversions":
			var lines := PackedStringArray()
			var ids: Array = value.keys()
			ids.sort()
			for id in ids:
				lines.append("%s = %.2f" % [id,value[id]])
			$Editors/Paths/Text.text = "\n".join(lines)
		"words": $Editors/Paths/Text.text = "\n".join(value)
		"meshes":
			var paths := PackedStringArray()
			for mesh: Mesh in value:
				paths.append(mesh.resource_path if mesh != null else "")
			$Editors/Paths/Text.text = "
".join(paths)
		_:
			$Editors/Asset/Path.text = value.resource_path if value != null else ""
	if _data.type == "number":
		_last_display = $Editors/Number.value
	elif _data.type == "vector":
		_last_display = [$Editors/Vector/Minimum.value,$Editors/Vector/Maximum.value]
	else:
		_last_display = _display_value()
	_syncing = false
	if had_draft:
		draft_changed.emit()

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
		"text": value = StringName($Editors/Text.text.strip_edges()) if typeof(_entry.get(_data.key)) == TYPE_STRING_NAME else $Editors/Text.text
		"multiline": value = $Editors/Multiline.text
		"number":
			var raw: String = $Editors/Number.get_line_edit().text.strip_edges()
			if not raw.is_valid_float() or not is_finite(raw.to_float()) or raw.to_float() < _data.min or raw.to_float() > _data.max:
				$Label.text = _data.label+" · enter a number within the allowed range"
				return
			if typeof(_entry.get(_data.key)) == TYPE_INT and raw.to_float() != floorf(raw.to_float()):
				$Label.text = _data.label+" · enter a whole number"
				return
			value = int(raw.to_float()) if typeof(_entry.get(_data.key)) == TYPE_INT else raw.to_float()
		"vector":
			var a: String = $Editors/Vector/Minimum.get_line_edit().text.strip_edges()
			var b: String = $Editors/Vector/Maximum.get_line_edit().text.strip_edges()
			if not a.is_valid_float() or not b.is_valid_float() or not is_finite(a.to_float()) or not is_finite(b.to_float()) or a.to_float() < _data.min or a.to_float() > _data.max or b.to_float() < _data.min or b.to_float() > _data.max:
				$Label.text = _data.label+" · enter numbers within the allowed range"
				return
			value = Vector2(a.to_float(),b.to_float())
		"color": value = $Editors/Color.color
		"enum", "resource": value = $Editors/Choice.get_selected_id()
		"creature", "discovery", "item": value = StringName($Editors/Choice.get_item_metadata($Editors/Choice.selected))
		"boolean": value = $Editors/Toggle.button_pressed
		"aversions":
			var weights: Dictionary[StringName,float] = {}
			for line: String in $Editors/Paths/Text.text.split("\n",false):
				var parts: PackedStringArray = line.split("=",true,1)
				if parts.size() != 2 or not parts[1].strip_edges().is_valid_float():
					$Label.text = _data.label+" · use species_id = weight"
					return
				var id := StringName(parts[0].strip_edges())
				var weight := float(parts[1])
				if _database.creature(id) == null or id == _entry.id or weights.has(id) or not is_finite(weight) or weight < 0.0 or weight > 1.0:
					$Label.text = _data.label+" · choose another species and a unique weight from 0 to 1"
					return
				weights[id] = weight
			value = weights
		"words": value = $Editors/Paths/Text.text.replace(",","\n").split("\n",false)
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
	_committing = true
	if _entry.get(_data.key) != value:
		edited.emit(_entry,_data.key,value)
	sync(true)
	_committing = false

func _load_asset(path: String, type: String) -> Resource:
	if not path.begins_with("res://") or not ResourceLoader.exists(path):
		return null
	var asset := load(path)
	return asset if asset != null and asset.is_class(type) else null

func has_pending_edit() -> bool:
	return _last_display != null and _display_value() != _last_display

func commit_edit() -> bool:
	_submit()
	return not has_pending_edit()

func _on_draft_changed(_value: Variant = null) -> void:
	if not _syncing:
		draft_changed.emit()

func _display_value() -> Variant:
	match _data.get("type",""):
		"text": return $Editors/Text.text
		"multiline": return $Editors/Multiline.text
		"words","aversions","meshes": return $Editors/Paths/Text.text
		"number": return _number_display($Editors/Number)
		"vector": return [_number_display($Editors/Vector/Minimum),_number_display($Editors/Vector/Maximum)]
		"enum","resource","creature","discovery","item","boolean": return null
	return $Editors/Asset/Path.text

func _number_display(number: SpinBox) -> Variant:
	if not number.get_line_edit().has_focus():
		return number.value
	var raw := number.get_line_edit().text.strip_edges()
	return raw.to_float() if raw.is_valid_float() and is_finite(raw.to_float()) else raw
