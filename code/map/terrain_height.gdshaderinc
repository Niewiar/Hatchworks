uniform sampler2D height_map : filter_linear, repeat_disable;
uniform vec2 height_size = vec2(2.0);
uniform vec2 height_world_size = vec2(16.0);
uniform mat4 ground_to_world;
uniform mat4 world_to_ground;

float sample_ground_height(vec2 position_2d) {
	vec2 grid = clamp((position_2d / height_world_size + vec2(0.5)) * (height_size - vec2(1.0)), vec2(0.0), height_size - vec2(1.0));
	ivec2 cell = min(ivec2(floor(grid)), ivec2(height_size) - ivec2(2));
	vec2 f = grid - vec2(cell);
	float first = texelFetch(height_map, cell, 0).r;
	float right = texelFetch(height_map, cell + ivec2(1,0), 0).r;
	float front = texelFetch(height_map, cell + ivec2(0,1), 0).r;
	if (f.x + f.y <= 1.0) {
		return first + (right - first) * f.x + (front - first) * f.y;
	}
	float last = texelFetch(height_map, cell + ivec2(1), 0).r;
	return last + (front - last) * (1.0 - f.x) + (right - last) * (1.0 - f.y);
}

vec3 follow_terrain(vec3 vertex_position, mat4 model_matrix, float lift) {
	vec3 world = (model_matrix * vec4(vertex_position, 1.0)).xyz;
	vec3 ground = (world_to_ground * vec4(world, 1.0)).xyz;
	ground.y = sample_ground_height(ground.xz) + lift;
	return (inverse(model_matrix) * ground_to_world * vec4(ground, 1.0)).xyz;
}
