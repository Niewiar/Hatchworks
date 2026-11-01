shader_type spatial;
#include "res://code/map/terrain_height.gdshaderinc"
render_mode unshaded, cull_disabled;

uniform bool follow_ground = false;
uniform float wind_strength = 0.025;
uniform vec3 light_direction = vec3(-0.45, 0.75, 0.65);

void vertex() {
	vec3 root_world = (MODEL_MATRIX * vec4(0.0,0.0,0.0,1.0)).xyz;
	if (follow_ground) {
		vec3 root_ground = (world_to_ground * vec4(root_world,1.0)).xyz;
		float height = sample_ground_height(root_ground.xz) - root_ground.y;
		VERTEX += (inverse(MODEL_MATRIX) * ground_to_world * vec4(0.0,height,0.0,0.0)).xyz;
	}
	float phase = root_world.x * 1.7 + root_world.z * 1.1;
	float breeze = sin(TIME * 1.12 + phase) + sin(TIME * 1.73 + phase * 0.43) * 0.28;
	VERTEX.xz += vec2(0.8,0.35) * breeze * wind_strength * COLOR.a;
}

void fragment() {
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float amount = dot(world_normal, normalize(light_direction));
	vec3 shade = amount < 0.10 ? COLOR.rgb * vec3(0.48,0.56,0.58) : (amount < 0.64 ? COLOR.rgb * 0.83 : min(COLOR.rgb * 1.10,vec3(1.0)));
	ALBEDO = OUTPUT_IS_SRGB ? mix(12.92 * shade, 1.055 * pow(max(shade,vec3(0.0)),vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308),shade)) : shade;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
