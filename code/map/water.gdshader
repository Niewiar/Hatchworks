shader_type spatial;
#include "res://code/map/terrain_height.gdshaderinc"
render_mode diffuse_lambert, specular_disabled, cull_disabled, depth_draw_never;

uniform float water_level = -0.35;
uniform vec4 shallow_color : source_color = vec4(0.23, 0.49, 0.43, 1.0);
uniform vec4 deep_color : source_color = vec4(0.08, 0.28, 0.32, 1.0);
uniform vec4 foam_color : source_color = vec4(0.80, 0.87, 0.69, 1.0);
uniform float shore_width : hint_range(0.05, 0.5) = 0.20;
uniform float wave_height : hint_range(0.0, 0.05) = 0.018;

varying vec2 ground_position;
varying float surface_height;

float water_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float water_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(water_hash(cell), water_hash(cell + vec2(1.0, 0.0)), u.x),
		mix(water_hash(cell + vec2(0.0, 1.0)), water_hash(cell + vec2(1.0)), u.x), u.y);
}

float ground_height(vec2 p) {
	return sample_ground_height(p);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 ground = (world_to_ground * vec4(world, 1.0)).xyz;
	ground_position = ground.xz;
	float depth = max(0.0, water_level - ground_height(ground.xz));
	float damping = smoothstep(0.0, 0.28, depth);
	float waves = sin(dot(ground.xz, vec2(0.95, 0.42)) * 1.7 + TIME * 0.65) * 0.65;
	waves += sin(dot(ground.xz, vec2(-0.35, 0.94)) * 2.2 - TIME * 0.48) * 0.35;
	ground.y = water_level + waves * wave_height * damping;
	surface_height = ground.y;
	VERTEX = (inverse(MODEL_MATRIX) * ground_to_world * vec4(ground, 1.0)).xyz;
}

void fragment() {
	vec2 p = ground_position;
	float depth = surface_height - ground_height(p);
	if (depth <= 0.001) { discard; }
	float time = TIME * 0.12;
	float broad = water_noise(p * 0.7 + vec2(time * 0.18, -time * 0.11));
	float fine = water_noise(p * 2.4 + vec2(-time * 0.30, time * 0.21));
	float depth_tint = 1.0 - exp(-depth * 1.25);
	vec3 color = mix(shallow_color.rgb, deep_color.rgb, smoothstep(0.0, 1.0, depth_tint));
	color *= 0.92 + broad * 0.12 + (fine - 0.5) * 0.025;
	vec2 drift = vec2(time * 0.18, time * 0.08);
	vec2 oriented = vec2(dot(p, vec2(0.8944, 0.4472)), dot(p, vec2(-0.4472, 0.8944))) * 1.7 + drift;
	vec2 cell = floor(oriented);
	vec2 random = vec2(water_hash(cell + 17.0), water_hash(cell + 53.0));
	vec2 local = fract(oriented) - mix(vec2(0.22), vec2(0.78), random);
	float curve = sin(local.x * 7.0 + random.y * 6.28) * 0.025;
	float dash = (1.0 - smoothstep(0.09, 0.20, abs(local.x))) * (1.0 - smoothstep(0.012, 0.038, abs(local.y + curve)));
	float active = step(0.60, water_hash(cell + 91.0));
	float shimmer = 0.35 + 0.65 * pow(sin(TIME * 0.8 + random.x * 6.28) * 0.5 + 0.5, 2.0);
	float highlights = dash * active * shimmer * smoothstep(0.04, 0.18, depth) * 0.16;
	float foam_noise = water_noise(p * 5.3 + vec2(time * 0.11, -time * 0.09));
	float foam_edge = shore_width * (0.72 + foam_noise * 0.45);
	float foam = (1.0 - smoothstep(foam_edge * 0.30, foam_edge, depth));
	foam *= smoothstep(0.003, 0.035, depth) * (0.55 + foam_noise * 0.45);
	float inner_ring = 1.0 - smoothstep(0.012, 0.038, abs(depth - shore_width * (0.55 + sin(TIME * 0.75 + broad * 5.0) * 0.12)));
	foam = max(foam, inner_ring * smoothstep(0.35, 0.70, foam_noise) * 0.22);
	vec2 slope = vec2(
		cos(dot(p, vec2(0.95, 0.42)) * 1.7 + TIME * 0.65) * 0.030,
		cos(dot(p, vec2(-0.35, 0.94)) * 2.2 - TIME * 0.48) * 0.025
	);
	slope += vec2(sin(p.x * 9.0 + p.y * 4.0 + TIME * 0.5), cos(p.y * 11.0 - p.x * 3.0 - TIME * 0.4)) * 0.015;
	vec3 world_normal = normalize(mat3(ground_to_world) * vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize(mat3(VIEW_MATRIX) * world_normal);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.5);
	color = mix(color, foam_color.rgb * 0.85, fresnel * 0.18 + highlights);
	color = mix(color, foam_color.rgb, foam * 0.50);
	ALBEDO = color;
	ROUGHNESS = 0.78;
	SPECULAR = 0.0;
	EMISSION = foam_color.rgb * highlights * 0.15;
	ALPHA = smoothstep(0.0, 0.035, depth) * clamp(0.72 + depth_tint * 0.24 + foam * 0.16, 0.0, 0.95);
}
