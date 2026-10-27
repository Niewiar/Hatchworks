class_name FencePostState
extends RefCounted

var id := 0
var position := Vector2.ZERO
var data: FanceData
var health := 0.0
var span_ids: Array[int] = []

func integrity() -> float:
	return clampf(health / maxf(data.post_max_health, 0.001), 0.0, 1.0)
