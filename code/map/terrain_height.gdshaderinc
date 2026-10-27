uniform sampler2D height_map : filter_linear, repeat_disable;
uniform vec2 height_size = vec2(2.0);
uniform vec2 height_world_size = vec2(16.0);
uniform mat4 ground_to_world;
uniform mat4 world_to_ground;

vec3 follow_terrain(vec3 vertex_position, mat4 model_matrix, float lift) {
	vec3 world = (model_matrix * vec4(vertex_position, 1.0)).xyz;
	vec3 ground = (world_to_ground * vec4(world, 1.0)).xyz;
	vec2 uv = ground.xz / height_world_size + vec2(0.5);
	vec2 sample_uv = (uv * (height_size - vec2(1.0)) + vec2(0.5)) / height_size;
	ground.y = textureLod(height_map, sample_uv, 0.0).r + lift;
	return (inverse(model_matrix) * ground_to_world * vec4(ground, 1.0)).xyz;
}
