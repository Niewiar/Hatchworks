class_name GroundPicker3D
extends RefCounted

static func from_screen(camera: Camera3D, screen_position: Vector2, surface: Node3D) -> Variant:
	if camera == null or surface == null:
		return null
	var plane := Plane(surface.global_basis.y.normalized(), surface.global_position)
	return plane.intersects_ray(camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))
