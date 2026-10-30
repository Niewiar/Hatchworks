@tool
class_name DatabaseEntry
extends Resource

@export var id: StringName
@export var display_name := "New entry":
	get:
		return display_name if Engine.is_editor_hint() else tr(display_name)
@export_multiline var description := "":
	get:
		return description if Engine.is_editor_hint() else tr(description)
