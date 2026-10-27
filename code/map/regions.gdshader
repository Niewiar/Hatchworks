shader_type spatial;
#include "res://code/map/terrain_height.gdshaderinc"
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D region_map : filter_nearest, repeat_disable;
uniform vec2 world_size = vec2(16.0);
uniform vec2 grid_size = vec2(64.0);
uniform int hovered_region = 0;

vec3 region_color(float id) {
	float h = fract(id * 0.61803398875 + 0.13);
	vec3 p = abs(fract(vec3(h) + vec3(0.0, 0.666667, 0.333333)) * 6.0 - 3.0);
	return mix(vec3(0.42), clamp(p - 1.0, 0.0, 1.0), 0.58);
}

float region_id(vec2 uv) {
	return floor(texture(region_map, uv).r + 0.5);
}

void vertex() {
	UV = VERTEX.xz / world_size + vec2(0.5);
	VERTEX = follow_terrain(VERTEX, MODEL_MATRIX, 0.025);
}

void fragment() {
	float id = region_id(UV);
	if (id < 0.5) { discard; }
	vec2 cell = fract(UV * grid_size);
	vec2 pixel = max(fwidth(UV * grid_size), vec2(0.0001));
	vec2 step_uv = vec2(1.0) / grid_size;
	float distance_px = 1000.0;
	if (region_id(UV - vec2(step_uv.x, 0.0)) != id) { distance_px = min(distance_px, cell.x / pixel.x); }
	if (region_id(UV + vec2(step_uv.x, 0.0)) != id) { distance_px = min(distance_px, (1.0 - cell.x) / pixel.x); }
	if (region_id(UV - vec2(0.0, step_uv.y)) != id) { distance_px = min(distance_px, cell.y / pixel.y); }
	if (region_id(UV + vec2(0.0, step_uv.y)) != id) { distance_px = min(distance_px, (1.0 - cell.y) / pixel.y); }
	float selected = float(int(id) == hovered_region);
	float rim = 1.0 - smoothstep(0.65, 1.8 + selected * 0.6, distance_px);
	float glow = exp(-distance_px * 0.4) * 0.10;
	float pulse = 0.94 + 0.06 * sin(TIME * 2.0);
	vec3 color = region_color(id);
	ALBEDO = mix(color, vec3(0.90, 0.98, 0.79), rim * selected * 0.55);
	ALPHA = clamp(0.07 + selected * 0.11 + rim * (0.52 + selected * 0.16) * pulse + glow, 0.0, 0.9);
}
