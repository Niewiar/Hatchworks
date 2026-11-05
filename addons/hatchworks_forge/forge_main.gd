@tool
extends PanelContainer

func _ready() -> void:
	$Content/Sections.set_tab_title(0,"Odkrycia")
	$Content/Sections.set_tab_title(1,"Kreatury")

func persist_draft() -> void:
	if is_node_ready():
		for section in $Content/Sections.get_children():
			if section.has_method("persist_draft"):
				section.persist_draft()
