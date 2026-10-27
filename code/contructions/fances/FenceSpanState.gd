class_name FenceSpanState
extends RefCounted

var id := 0
var start_post_id := 0
var end_post_id := 0
var data: FanceData
var health := 0.0

func integrity() -> float:
	return clampf(health / maxf(data.max_health, 0.001), 0.0, 1.0)
