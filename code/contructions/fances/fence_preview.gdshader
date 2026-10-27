shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

uniform bool valid = true;

void fragment() {
	if (mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 3.0) < 1.0) {
		discard;
	}
	ALBEDO = valid ? vec3(0.15, 0.7, 0.22) : vec3(0.9, 0.05, 0.03);
}
