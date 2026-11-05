class_name CreatureDropMarker
extends MeshInstance3D

var _water: WaterController
var _marker_material: ShaderMaterial

func initialize(terrain: TerrainController, water: WaterController) -> void:
	_water = water
	_marker_material = material_override as ShaderMaterial
	terrain.bind_height_material(_marker_material)
	extra_cull_margin = maxf(absf(terrain.minimum_height),absf(terrain.maximum_height))+absf(terrain.global_position.y)+absf(water.global_position.y)+0.1
	_marker_material.set_shader_parameter("water_level",water.global_position.y)

func present(point: Vector3, radius: float) -> void:
	var diameter := maxf(radius,0.1)*2.5
	global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(diameter,1.0,diameter)),Vector3(point.x,0.0,point.z))
	_marker_material.set_shader_parameter("water_level",_water.global_position.y)
	show()
