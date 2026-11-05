shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D region_map : filter_nearest, repeat_disable;
uniform sampler2D noise_map : filter_linear, repeat_disable;
uniform vec2 world_size = vec2(16.0);
uniform float water_level = -1000.0;
uniform int view_mode = 0;
uniform int highlighted_region = 0;

float region_at(vec2 uv) {
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) { return 0.0; }
	vec3 value = texture(region_map, uv).rgb;
	return round(value.r * 255.0) + round(value.g * 255.0) * 256.0 + round(value.b * 255.0) * 65536.0;
}

vec3 region_color(float id) {
	float hue = fract(id * 0.61803398875);
	vec3 wave = abs(fract(vec3(hue) + vec3(0.0, 0.666666667, 0.333333333)) * 6.0 - 3.0);
	return 0.92 * mix(vec3(1.0), clamp(wave - 1.0, 0.0, 1.0), 0.53);
}

void vertex() {
	UV = VERTEX.xz / world_size + vec2(0.5);
	VERTEX.y = max(VERTEX.y, water_level + 0.015) + 0.035;
}

void fragment() {
	if (view_mode == 1) {
		float level = clamp(texture(noise_map, UV).r, 0.0, 1.0);
		if (level < 0.008) { discard; }
		vec3 color = mix(vec3(0.35, 0.72, 0.43), vec3(1.0, 0.86, 0.27), smoothstep(0.0, 0.3, level));
		color = mix(color, vec3(1.0, 0.43, 0.13), smoothstep(0.3, 0.65, level));
		color = mix(color, vec3(0.84, 0.12, 0.12), smoothstep(0.65, 1.0, level));
		ALBEDO = color;
		ALPHA = smoothstep(0.0, 0.1, level) * 0.68;
	} else if (view_mode == 2) {
		float id = region_at(UV);
		if (id < 0.5) { discard; }
		vec2 step_uv = vec2(0.065) / world_size;
		bool border = region_at(UV + vec2(step_uv.x, 0.0)) != id || region_at(UV - vec2(step_uv.x, 0.0)) != id;
		border = border || region_at(UV + vec2(0.0, step_uv.y)) != id || region_at(UV - vec2(0.0, step_uv.y)) != id;
		bool highlighted = int(id) == highlighted_region;
		ALBEDO = border ? vec3(0.14, 0.12, 0.1) : region_color(id);
		ALPHA = border ? 0.95 : (highlighted ? 0.57 : 0.36);
	} else {
		discard;
	}
}
