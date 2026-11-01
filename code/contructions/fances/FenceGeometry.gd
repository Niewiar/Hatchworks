class_name FenceGeometry
extends RefCounted

static var _material: Material
static var _highlight_material: Material

class Builder:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
		var normal := (b-a).cross(c-a).normalized()
		var base := vertices.size()
		vertices.append_array(PackedVector3Array([a,b,c]))
		normals.append_array(PackedVector3Array([normal,normal,normal]))
		var linear := color.srgb_to_linear()
		colors.append_array(PackedColorArray([linear,linear,linear]))
		indices.append_array(PackedInt32Array([base,base+2,base+1]))

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
		triangle(a,b,c,color)
		triangle(a,c,d,color)

	func tube(points: Array[Vector3], radii: Array[Vector2], color: Color, sides: int = 8) -> void:
		var rings: Array[PackedVector3Array] = []
		for index in points.size():
			var tangent := (points[mini(index+1,points.size()-1)]-points[maxi(index-1,0)]).normalized()
			var axis := Vector3.UP if absf(tangent.y)<0.95 else Vector3.RIGHT
			var u := tangent.cross(axis).normalized()
			var v := tangent.cross(u).normalized()
			var ring := PackedVector3Array()
			for side in sides:
				var angle := TAU*side/sides
				ring.append(points[index]+u*cos(angle)*radii[index].x+v*sin(angle)*radii[index].y)
			rings.append(ring)
		for index in range(rings.size()-1):
			for side in sides:
				var next := (side+1)%sides
				quad(rings[index][side],rings[index][next],rings[index+1][next],rings[index+1][side],color.lightened(0.045*sin(side*2.1)))
		for side in sides:
			var next := (side+1)%sides
			triangle(points[0],rings[0][next],rings[0][side],color.lightened(0.12))
			triangle(points[-1],rings[-1][side],rings[-1][next],color.lightened(0.12))

	func cord(points: Array[Vector3], radius: float, color: Color, sides: int = 5) -> void:
		var radii: Array[Vector2] = []
		for point in points:
			radii.append(Vector2.ONE*radius)
		tube(points,radii,color,sides)

	func leaf(center: Vector3, width: float, height: float, color: Color) -> void:
		for index in range(7):
			var a := float(index)/7
			var b := float(index+1)/7
			var left_a := center+Vector3(-width*sin(a*PI),height*a,0)
			var left_b := center+Vector3(-width*sin(b*PI),height*b,0)
			var ridge_a := center+Vector3(0,height*a,0.12*sin(a*PI))
			var ridge_b := center+Vector3(0,height*b,0.12*sin(b*PI))
			quad(left_a,ridge_a,ridge_b,left_b,color)
			quad(ridge_a,center+Vector3(width*sin(a*PI),height*a,0),center+Vector3(width*sin(b*PI),height*b,0),ridge_b,color.lightened(0.18))

	func drape(start: Vector2, end: Vector2, first_height: float, last_height: float) -> void:
		var gradient := (end-start)*((last_height-first_height)/maxf(start.distance_squared_to(end),0.001))
		for index in vertices.size():
			var vertex := vertices[index]
			vertex.y += first_height+(Vector2(vertex.x,vertex.z)-start).dot(gradient)
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
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		return result

static func material(highlighted: bool = false) -> Material:
	if _material == null:
		_material = load("res://resources/constructions/folklore_material.tres") as Material
	if not highlighted:
		return _material
	if _highlight_material == null:
		_highlight_material = _material.duplicate() as ShaderMaterial
		(_highlight_material as ShaderMaterial).set_shader_parameter("light_direction",Vector3(-0.25,0.95,0.35))
	return _highlight_material

static func build_post(data: FanceData, integrity: float, seed_value: int, pixels_per_unit: float) -> ArrayMesh:
	var builder := Builder.new()
	var phase := float(posmod(seed_value,100))*0.13
	var width := data.post_width*0.5
	var depth := data.thickness*0.63
	var height := data.height*(0.85 if integrity<0.35 else 1.0)
	var points: Array[Vector3] = []
	var radii: Array[Vector2] = []
	for index in range(9):
		var t := float(index)/8
		points.append(Vector3(sin(t*2.6+phase)*0.9,height*t,sin(t*3.7+phase)*0.7))
		radii.append(Vector2(depth*(1.0-0.12*t),width*(1.0-0.08*t+0.06*sin(t*6.0))))
	builder.tube(points,radii,data.body_color,8)
	var cap := points[-1]
	builder.tube([cap-Vector3(0,0.8,0),cap+Vector3(0,1.1,0),cap+Vector3(0,2.3,0)],[Vector2(depth+0.8,width+0.8),Vector2(depth+0.7,width+0.7),Vector2(depth-0.8,width-0.6)],data.highlight_color,8)
	for side in [-1,1]:
		for line in range(3):
			var grain: Array[Vector3] = []
			for index in range(9):
				var t := float(index)/8
				var p := points[index]
				grain.append(p+Vector3(width*(-0.5+line*0.5)+0.35*sin(t*10.0+line),0,side*(depth*(1.0-0.12*t)+0.12)))
			builder.cord(grain,0.13,data.outline_color.lightened(0.12),4)
	for elevation in [data.height*0.35,data.height*0.73]:
		if integrity<0.35 and elevation>data.height*0.6:
			continue
		for wrap in range(3):
			var rope: Array[Vector3] = []
			for segment in range(25):
				var angle := TAU*segment/24
				rope.append(Vector3((width+0.6)*cos(angle),elevation+1.2+wrap*0.65+sin(angle)*0.3,(depth+0.8)*sin(angle)))
			builder.cord(rope,0.36,Color(0.66,0.51,0.29))
	builder.leaf(Vector3(0,height*0.79,depth+0.18),width*0.38,height*0.13,data.outline_color.lightened(0.13))
	if integrity<0.65:
		builder.cord([Vector3(-1,height*0.28,depth+0.2),Vector3(0.7,height*0.46,depth+0.3),Vector3(-0.3,height*0.60,depth+0.3)],0.28,data.outline_color,4)
	return builder.finish(pixels_per_unit)

static func build_span(data: FanceData, start: Vector2, end: Vector2, integrity: float, seed_value: int, pixels_per_unit: float, start_height: float = 0.0, end_height: float = 0.0) -> ArrayMesh:
	var builder := Builder.new()
	var length := start.distance_to(end)
	if length<0.5:
		return builder.finish(pixels_per_unit)
	var direction := Vector3(end.x-start.x,0,end.y-start.y)/length
	var normal := Vector3(-direction.z,0,direction.x)
	var inset := minf(data.post_width*0.35,length*0.2)
	var first := Vector3(start.x,0,start.y)+direction*inset
	var distance := length-inset*2
	var phase := float(posmod(seed_value,100))*0.17
	for rail in range(2):
		if integrity<0.35 and rail==1:
			continue
		var elevation := data.height*(0.35 if rail==0 else 0.73)+3.5
		var points: Array[Vector3] = []
		var radii: Array[Vector2] = []
		for index in range(13):
			var t := float(index)/12
			points.append(first+direction*(distance*t)+Vector3.UP*(elevation+sin(t*PI)*1.1+sin(t*4.0+phase)*0.35)+normal*sin(t*PI)*0.6)
			radii.append(Vector2(data.thickness*0.5,3.6+0.3*sin(t*5.0+phase)))
		builder.tube(points,radii,data.body_color.lightened(0.035*rail),8)
		for side in [-1,1]:
			for line in range(3):
				var grain: Array[Vector3] = []
				for index in range(13):
					var t := float(index)/12
					grain.append(points[index]+normal*(side*(data.thickness*0.5+0.1))+Vector3.UP*(-1.8+line*1.6+sin(t*8.0+line)*0.25))
				builder.cord(grain,0.12,data.outline_color.lightened(0.19),4)
		if integrity<0.65:
			var middle := first+direction*(distance*0.48)+Vector3.UP*elevation+normal*(data.thickness*0.5+0.22)
			builder.cord([middle-Vector3.UP*3.4,middle+direction*0.8,middle-direction*0.6+Vector3.UP*3.5],0.30,data.outline_color,4)
	builder.drape(start,end,start_height,end_height)
	return builder.finish(pixels_per_unit)
