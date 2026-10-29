class_name Region
extends RefCounted

var id: int
var area := 0.0
var touches_map_edge := false
var terrain_coverage := PackedFloat32Array([100.0, 0.0, 0.0, 0.0, 0.0])
var cell_count := 0
var water_area := 0.0
var water_coverage: float:
	get:
		return water_area / area * 100.0 if area > 0.0 else 0.0

var center := Vector3.ZERO
