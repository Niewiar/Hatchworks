shader_type spatial;
#include "res://code/map/terrain_height.gdshaderinc"
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform float water_level = -0.35;
uniform vec4 marker_color : source_color = vec4(0.66, 0.91, 0.39, 0.97);
uniform vec4 shadow_color : source_color = vec4(0.07, 0.10, 0.06, 0.92);

void vertex() {
	vec3 ground_vertex = follow_terrain(VERTEX, MODEL_MATRIX, 0.035);
	vec3 world = (MODEL_MATRIX * vec4(ground_vertex, 1.0)).xyz;
	world.y = max(world.y, water_level + 0.035);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}

void fragment() {
	vec2 point = (UV - vec2(0.5)) * 2.0;
	float radius = length(point);
	float pixel = max(fwidth(radius), 0.001);
	float edge = abs(radius - 0.8);
	float ring = 1.0 - smoothstep(0.025, 0.025 + pixel, edge);
	float ring_shadow = 1.0 - smoothstep(0.065, 0.065 + pixel, edge);
	ALBEDO = mix(shadow_color.rgb, marker_color.rgb, ring);
	ALPHA = max(ring * marker_color.a, ring_shadow * shadow_color.a);
}
