class_name FenceGeometry
extends RefCounted

static var _box_arrays: Array = []
static var _material: StandardMaterial3D
static var _highlight_material: StandardMaterial3D

class Builder:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func box(center: Vector3, size: Vector3, color: Color, orientation: Basis = Basis.IDENTITY) -> void:
		var source := FenceGeometry.unit_box()
		var source_vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
		var source_indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
		var base := vertices.size()
		for index in source_vertices.size():
			vertices.append(center + orientation * (source_vertices[index] * size))
			normals.append((orientation * source_normals[index]).normalized())
			colors.append(color)
		for index in source_indices:
			indices.append(base + index)

	func drape(start: Vector2, end: Vector2, first_height: float, last_height: float) -> void:
		var gradient := (end-start) * ((last_height-first_height)/maxf(start.distance_squared_to(end),0.001))
		for index in vertices.size():
			var vertex := vertices[index]
			vertex.y += first_height + (Vector2(vertex.x,vertex.z)-start).dot(gradient)
			vertices[index] = vertex
			var normal := normals[index]
			normals[index] = Vector3(normal.x-gradient.x*normal.y,normal.y,normal.z-gradient.y*normal.y).normalized()

	func finish(pixels_per_unit: float) -> ArrayMesh:
		for index in vertices.size():
			vertices[index] /= pixels_per_unit
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var result := ArrayMesh.new()
		if not vertices.is_empty():
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return result

static func unit_box() -> Array:
	if _box_arrays.is_empty():
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		_box_arrays = box.get_mesh_arrays()
	return _box_arrays

static func material(highlighted: bool = false) -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.93
		_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if not highlighted:
		return _material
	if _highlight_material == null:
		_highlight_material = _material.duplicate() as StandardMaterial3D
		_highlight_material.albedo_color = Color(1.2, 1.12, 0.86)
	return _highlight_material

static func build_post(data: FanceData, integrity: float, seed_value: int, pixels_per_unit: float) -> ArrayMesh:
	var builder := Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var width := data.post_width
	var depth := data.thickness * 1.15
	if data.material_kind == FanceData.MaterialKind.STONE:
		var rows := maxi(2, roundi(data.height / 11.0))
		var row_height := data.height / rows
		builder.box(Vector3(0, data.height * 0.5, 0), Vector3(width - 0.6, data.height, depth - 0.6), data.body_color.darkened(0.25))
		for row in rows:
			builder.box(Vector3(0, row * row_height + (row_height - 1) * 0.5, 0), Vector3(width, row_height - 1, depth), data.body_color.lightened(rng.randf_range(-0.06, 0.08)))
		builder.box(Vector3(0, data.height + 2, 0), Vector3(width + 4, 4, depth + 3), data.highlight_color)
	else:
		builder.box(Vector3(0, data.height * 0.5, 0), Vector3(width, data.height, depth), data.body_color)
		builder.box(Vector3(0, data.height + 1.5, 0), Vector3(width + 3, 3, depth + 2), data.highlight_color)
		for grain in range(3):
			var x := rng.randf_range(-width * 0.3, width * 0.3)
			builder.box(Vector3(x, data.height * 0.48, depth * 0.5 + 0.15), Vector3(0.55, data.height * rng.randf_range(0.45, 0.7), 0.3), data.outline_color.lightened(0.13))
		for level in [data.height * 0.35, data.height * 0.73]:
			builder.box(Vector3(0, level + 1, depth * 0.5 + 0.3), Vector3(1.6, 1.6, 0.6), data.outline_color)
	if integrity < 0.65:
		builder.box(Vector3(-1, data.height * 0.5, depth * 0.5 + 0.35), Vector3(0.8, data.height * 0.4, 0.4), data.outline_color.darkened(0.2), Basis(Vector3.FORWARD, 0.12))
	return builder.finish(pixels_per_unit)

static func build_span(data: FanceData, start: Vector2, end: Vector2, integrity: float, seed_value: int, pixels_per_unit: float, start_height: float = 0.0, end_height: float = 0.0) -> ArrayMesh:
	var builder := Builder.new()
	var length := start.distance_to(end)
	if length < 0.5:
		return builder.finish(pixels_per_unit)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var direction := Vector3(end.x - start.x, 0, end.y - start.y) / length
	var normal := Vector3(-direction.z, 0, direction.x)
	var orientation := Basis(direction, Vector3.UP, normal)
	var inset := minf(data.post_width * 0.35, length * 0.2)
	var first := Vector3(start.x, 0, start.y) + direction * inset
	var distance := length - inset * 2
	if data.material_kind == FanceData.MaterialKind.STONE:
		builder.box(first + direction * distance * 0.5 + Vector3.UP * (data.height - 1) * 0.5, Vector3(distance, data.height - 1, data.thickness - 0.6), data.body_color.darkened(0.3), orientation)
		var rows := maxi(2, roundi(data.height / 10.0))
		var row_height := data.height / rows
		for row in rows:
			var brick_width := 22.0
			var cursor := -brick_width * 0.5 if row % 2 else 0.0
			while cursor < distance:
				var left := maxf(0, cursor + 0.7)
				var right := minf(distance, cursor + brick_width - 0.7)
				if right - left > 1:
					var center := first + direction * ((left + right) * 0.5) + Vector3.UP * (row * row_height + (row_height - 1) * 0.5)
					builder.box(center, Vector3(right - left, row_height - 1, data.thickness), data.body_color.lightened(rng.randf_range(-0.08, 0.1)), orientation)
				cursor += brick_width
		if integrity < 0.7:
			builder.box(first + direction * distance * 0.55 + Vector3.UP * data.height * 0.6 + normal * (data.thickness * 0.5 + 0.2), Vector3(1, data.height * 0.65, 0.4), data.outline_color, orientation)
	else:
		for rail in range(2):
			if integrity < 0.35 and rail == 1:
				continue
			var elevation := data.height * (0.35 if rail == 0 else 0.73)
			var center := first + direction * distance * 0.5 + Vector3.UP * (elevation + 3.5)
			builder.box(center, Vector3(distance, 7, data.thickness), data.body_color, orientation)
			for grain in range(2):
				var offset := rng.randf_range(-0.08, 0.08) * distance
				var grain_center := center + direction * offset + normal * (data.thickness * 0.5 + 0.15) + Vector3.UP * (-1.5 + grain * 2.5)
				builder.box(grain_center, Vector3(distance * rng.randf_range(0.6, 0.82), 0.55, 0.3), data.highlight_color.darkened(grain * 0.14), orientation)
			if integrity < 0.65:
				builder.box(center + normal * (data.thickness * 0.5 + 0.3), Vector3(1, 7.5, 0.5), data.outline_color, orientation)
	builder.drape(start,end,start_height,end_height)
	return builder.finish(pixels_per_unit)
