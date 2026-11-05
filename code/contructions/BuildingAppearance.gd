class_name BuildingAppearance
extends RefCounted

const SURFACE = preload("res://code/contructions/building_cel.gdshader")
const OUTLINE = preload("res://code/contructions/building_outline.gdshader")

static func configure(root: Node3D) -> Array[ShaderMaterial]:
	var result: Array[ShaderMaterial] = []
	var ink := ShaderMaterial.new()
	ink.shader = OUTLINE
	ink.set_shader_parameter("width", 0.003)
	var materials: Dictionary[Material, ShaderMaterial] = {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.material_override != null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if original == null:
				continue
			if not materials.has(original):
				var paint := ShaderMaterial.new()
				paint.shader = SURFACE
				paint.next_pass = ink
				var texture := original.albedo_texture
				if texture == null:
					var image := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
					image.fill(original.albedo_color)
					texture = ImageTexture.create_from_image(image)
				paint.set_shader_parameter("albedo_texture", texture)
				paint.set_shader_parameter("cavity_strength", 0.0)
				materials[original] = paint
				result.append(paint)
			mesh.set_surface_override_material(surface, materials[original])
	return result
