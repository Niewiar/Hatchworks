@tool
class_name CreatureCelAppearance
extends Node3D

@export_range(0.01, 5.0, 0.001) var walk_distance := 0.2
@export_range(0.01, 5.0, 0.01) var walk_speed := 0.2
@export_range(0.0001, 0.02, 0.0001) var outline_width := 0.0015
@export var work_contact_offset := Vector3.ZERO

const CEL_SHADER = preload("res://code/creatures/creature_cel.gdshader")
const WING_SHADER = preload("res://code/creatures/creature_wing.gdshader")
const OUTLINE_SHADER = preload("res://code/creatures/pebblit_outline.gdshader")

static var _materials: Dictionary[Material, Dictionary] = {}

func _ready() -> void:
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("width", outline_width)
	outline.set_shader_parameter("ink_color", Vector3(0.013, 0.017, 0.014))
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if original == null:
				continue
			if not _materials.has(original):
				_materials[original] = {}
			var variants: Dictionary = _materials[original]
			if not variants.has(outline_width):
				var material := ShaderMaterial.new()
				var name := original.resource_name.to_lower()
				var wing := name.contains("wing_membrane")
				material.shader = WING_SHADER if wing else CEL_SHADER
				material.set_shader_parameter("base_color", original.albedo_color)
				material.set_shader_parameter("use_vertex_color", original.vertex_color_use_as_albedo)
				var texture := original.albedo_texture
				material.set_shader_parameter("use_texture", texture != null)
				if texture != null:
					material.set_shader_parameter("color_texture", texture)
				var accent := name.contains("pupil") or name.contains("glint") or name.contains("mouth") or name.contains("crease") or name.contains("vein")
				material.set_shader_parameter("flat_color", accent)
				if not accent and not wing:
					material.next_pass = outline
				variants[outline_width] = material
			mesh.set_surface_override_material(surface, variants[outline_width])
	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return
	for name in player.get_animation_list():
		player.get_animation(name).loop_mode = Animation.LOOP_NONE if name in [&"Land", &"Work"] else Animation.LOOP_LINEAR
