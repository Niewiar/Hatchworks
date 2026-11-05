@tool
extends Window

var _opened := false

func _ready() -> void:
	close_requested.connect(_close_forge)

func open_forge() -> void:
	if not _opened:
		popup_centered()
		_opened = true
	else:
		show()
	grab_focus()

func persist_draft() -> void:
	if is_node_ready():
		%Forge.persist_draft()

func _close_forge() -> void:
	persist_draft()
	hide()
