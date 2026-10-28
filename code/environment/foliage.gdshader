shader_type spatial;
#include "res://code/map/terrain_height.gdshaderinc"
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform bool follow_ground = false;
uniform float wind_strength = 0.025;

void vertex() {
	vec3 root_world = (MODEL_MATRIX * vec4(0.0,0.0,0.0,1.0)).xyz;
	if (follow_ground) {
		vec3 root_ground = (world_to_ground * vec4(root_world,1.0)).xyz;
		float height = sample_ground_height(root_ground.xz) - root_ground.y;
		VERTEX += (inverse(MODEL_MATRIX) * ground_to_world * vec4(0.0,height,0.0,0.0)).xyz;
	}
	float phase = root_world.x * 1.7 + root_world.z * 1.1;
	float breeze = sin(TIME * 1.35 + phase) + sin(TIME * 2.1 + phase * 0.43) * 0.35;
	VERTEX.xz += vec2(0.8,0.35) * breeze * wind_strength * COLOR.a;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.0;
}
