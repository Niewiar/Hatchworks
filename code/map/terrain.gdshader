shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D ground_map : hint_default_transparent, filter_linear, repeat_disable;
uniform sampler2D ground_influence : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D nature_map : hint_default_transparent, filter_linear, repeat_disable;
uniform vec2 map_size = vec2(512.0);
uniform vec2 world_size = vec2(16.0);
uniform float water_level = -1000.0;
varying float ground_elevation;

group_uniforms Appearance;
uniform float terrain_seed = 17.0;
uniform float terrain_scale : hint_range(0.5, 3.0, 0.1) = 1.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.65;
uniform float edge_roughness : hint_range(0.0, 6.0) = 2.5;
uniform float transition_width : hint_range(0.0, 24.0, 0.5) = 10.0;
uniform vec4 grass_tint : source_color = vec4(0.36, 0.43, 0.255, 1.0);
uniform vec4 dirt_tint : source_color = vec4(0.47, 0.365, 0.255, 1.0);
uniform vec4 sand_tint : source_color = vec4(0.70, 0.615, 0.435, 1.0);
uniform vec4 rock_tint : source_color = vec4(0.48, 0.465, 0.395, 1.0);
group_uniforms;

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec2 hash22(vec2 p) {
	return vec2(hash12(p), hash12(p + vec2(47.17, 91.73)));
}

float ground_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash12(cell), hash12(cell + vec2(1.0, 0.0)), u.x),
		mix(hash12(cell + vec2(0.0, 1.0)), hash12(cell + vec2(1.0)), u.x),
		u.y
	);
}

vec2 boundary_warp(vec2 p) {
	vec2 broad = vec2(ground_noise(p / 19.0 + 31.0), ground_noise(p / 19.0 + 131.0)) - 0.5;
	vec2 fine = vec2(ground_noise(p / 6.0 + 7.0), ground_noise(p / 6.0 + 91.0)) - 0.5;
	return broad * transition_width * 0.85 * clamp(edge_roughness * 0.4, 0.0, 2.0) + fine * edge_roughness * 2.0;
}

vec4 ground_weights(vec2 uv) {
	return clamp(texture(ground_map,uv) + texture(nature_map,uv) * (1.0-texture(ground_influence,uv).r),vec4(0.0),vec4(1.0));
}

vec4 terrain_weights(vec2 uv, vec2 size, vec2 p) {
	vec4 center = ground_weights(uv);
	if (transition_width < 0.01) {
		return clamp(center, vec4(0.0), vec4(1.0));
	}
	float angle = ground_noise(p / 19.0 + 223.0) * 6.283185;
	vec2 turn = vec2(cos(angle), sin(angle));
	vec4 softened = center * 0.12;
	for (int i = 0; i < 12; i++) {
		float phase = float(i) * 2.399963;
		float radius = sqrt((float(i) + 0.5) / 12.0) * transition_width;
		vec2 disk = vec2(cos(phase), sin(phase)) * radius;
		vec2 offset = vec2(disk.x * turn.x - disk.y * turn.y, disk.x * turn.y + disk.y * turn.x);
		softened += ground_weights(uv + offset / size) * (0.88 / 12.0);
	}
	return clamp(softened, vec4(0.0), vec4(1.0));
}

float transition_score(float weight, vec2 p, float offset) {
	if (weight < 0.0001 || weight > 0.9999) {
		return weight;
	}
	float patches = (ground_noise(p / 4.0 + offset) - 0.5) * 3.2;
	float specks = (ground_noise(p / 1.6 + offset + 91.0) - 0.5) * 0.9;
	float roughness = clamp(edge_roughness * 0.4, 0.0, 2.0);
	return max(weight * 0.1, weight + (patches + specks) * weight * (1.0 - weight) * roughness);
}

float line_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float along = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.001), 0.0, 1.0);
	return length(p - a - ab * along);
}
vec3 ground_cells(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float nearest = 10.0;
	vec2 closest = vec2(0.0);
	vec2 identity = cell;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 delta = offset + 0.12 + hash22(cell + offset) * 0.76 - local;
			float distance_squared = dot(delta, delta);
			if (distance_squared < nearest) {
				nearest = distance_squared;
				closest = delta;
				identity = cell + offset;
			}
		}
	}
	return vec3(sqrt(nearest), hash12(identity + 71.0), dot(closest, vec2(0.55, 0.85)));
}

vec3 add_pebbles(vec3 color, vec2 p, float density) {
	vec2 cell = floor(p / 9.0);
	vec2 local = mod(p, 9.0) - (vec2(2.5) + hash22(cell + 113.0) * 4.0);
	float active = step(hash12(cell + 29.0), density);
	float radius = 0.65 + hash12(cell + 89.0) * 0.95;
	vec2 q = local / vec2(1.0, 0.65);
	float shadow = (1.0 - smoothstep(radius, radius + 0.65, length(q - vec2(0.0, 0.7)))) * active;
	float stone = (1.0 - smoothstep(radius - 0.25, radius + 0.25, length(q))) * active;
	vec3 pebble_color = mix(dirt_tint.rgb, rock_tint.rgb, 0.65) * (1.1 - local.y * 0.12);
	color *= 1.0 - shadow * 0.16 * detail_strength;
	return mix(color, pebble_color, stone * detail_strength);
}

vec3 grass_surface(vec2 p, float macro, float middle) {
	float carpet = ground_noise(p / 5.0 + 61.0);
	float grain = hash12(floor(p));
	vec3 color = grass_tint.rgb * (0.78 + macro * 0.23 + middle * 0.13);
	color *= 1.0 + (carpet - 0.5) * 0.15 * detail_strength;
	color = mix(color, dirt_tint.rgb * 0.82, smoothstep(0.7, 0.9, middle) * 0.16);
	color *= 1.0 + (grain - 0.5) * 0.07 * detail_strength;
	return color;
}
vec4 grass_marks(vec2 p, float middle, float edge) {
	vec2 cell = floor(p / 10.0);
	vec2 local = mod(p, 10.0);
	vec2 random = hash22(cell + 43.0);
	float density = (0.16 + middle * 0.32 + edge * 0.22) * detail_strength;
	float active = step(hash12(cell + 19.0), density);
	vec2 base = vec2(3.0 + random.x * 3.5, 7.5);
	float height = 2.0 + random.y * 3.0;
	float left = line_distance(local, base, base + vec2(-1.4, -height * 0.65));
	float center = line_distance(local, base, base + vec2(0.4, -height));
	float right = line_distance(local, base, base + vec2(2.1, -height * 0.55));
	float blades = (1.0 - smoothstep(0.3, 0.65, min(left, min(center, right)))) * active;
	float foot = (1.0 - smoothstep(0.7, 2.0, length((local - base) / vec2(1.0, 0.45)))) * active;
	return vec4(blades, foot, base - local);
}

vec3 dirt_surface(vec2 p, float macro, float middle) {
	float grain = hash12(floor(p));
	float crumbs = ground_noise(p / 1.8 + 57.0);
	float patches = ground_noise(p / 10.0 + 301.0);
	vec3 color = dirt_tint.rgb * (0.77 + macro * 0.23 + middle * 0.12);
	color *= 1.0 + ((crumbs - 0.5) * 0.24 + (grain - 0.5) * 0.15) * detail_strength;
	color = mix(color, dirt_tint.rgb * 0.67, smoothstep(0.64, 0.85, patches) * 0.25 * detail_strength);
	float fleck = step(0.975, grain);
	color = mix(color, sand_tint.rgb * 0.78, fleck * 0.45 * detail_strength);
	return add_pebbles(color, p, 0.15);
}

vec3 sand_surface(vec2 p, float macro, float middle) {
	float grain = hash12(floor(p) + 83.0);
	float waves = sin(p.x * 0.23 + p.y * 0.08 + ground_noise(p / 24.0) * 6.0);
	vec3 color = sand_tint.rgb * (0.85 + macro * 0.12 + middle * 0.08);
	color *= 1.0 + ((grain - 0.5) * 0.11 + waves * 0.018) * detail_strength;
	color = mix(color, dirt_tint.rgb * 1.08, step(0.984, grain) * 0.35 * detail_strength);
	return add_pebbles(color, p + 47.0, 0.035);
}

vec3 rock_surface(vec2 p, float macro, float middle) {
	float grain = hash12(floor(p));
	float crumbs = ground_noise(p / 1.8 + 57.0);
	float mineral = ground_noise(p / 5.0 + 61.0);
	vec3 substrate = mix(dirt_tint.rgb, rock_tint.rgb, 0.72);
	vec3 color = substrate * (0.78 + macro * 0.23 + middle * 0.13);
	color *= 1.0 + ((mineral - 0.5) * 0.14 + (crumbs - 0.5) * 0.18 + (grain - 0.5) * 0.11) * detail_strength;
	vec3 grit = ground_cells(p / 4.2 + 53.0);
	float radius = 0.16 + grit.y * 0.2;
	float chip = 1.0 - smoothstep(radius - 0.05, radius + 0.06, grit.x);
	vec3 chip_color = rock_tint.rgb * (0.86 + grit.y * 0.2 + grit.z * 0.1);
	color = mix(color, chip_color, chip * detail_strength * 0.7);
	return mix(color, dirt_tint.rgb * 0.8, step(0.985, grain) * 0.22 * detail_strength);
}

void vertex() {
	UV = VERTEX.xz / world_size + vec2(0.5);
	ground_elevation = VERTEX.y;
}

void fragment() {
	vec2 size = max(map_size, vec2(1.0));
	vec2 pixel = clamp(floor(UV * size), vec2(0.0), size - vec2(1.0));
	vec2 p = pixel / max(terrain_scale, 0.1) + vec2(terrain_seed * 13.71, terrain_seed * 7.13);
	vec2 warp = boundary_warp(p);
	vec2 mask_uv = (pixel + vec2(0.5) + warp) / size;
	vec4 weights = terrain_weights(mask_uv, size, p);
	weights.g = 0.0;
	float grass = max(1.0 - dot(weights, vec4(1.0)), 0.0);
	float highest = max(grass, max(max(weights.r, weights.g), max(weights.b, weights.a)));
	float edge = 1.0 - smoothstep(0.55, 0.97, highest);
	vec4 scores = vec4(transition_score(weights.r, p, 13.0), transition_score(weights.g, p, 29.0), transition_score(weights.b, p, 73.0), transition_score(weights.a, p, 107.0));
	float grass_score = transition_score(grass, p, 0.0);
	float macro = ground_noise(p / 145.0) * 0.65 + ground_noise(p / 57.0 + 47.0) * 0.35;
	float middle = ground_noise(p / 21.0 + 19.0);
	vec4 coverage = scores * scores;
	float grass_coverage = grass_score * grass_score;
	float total = max(grass_coverage + dot(coverage, vec4(1.0)), 0.0001);
	coverage /= total;
	grass_coverage /= total;
	vec3 color = vec3(0.0);
	if (grass_coverage > 0.0) { color += grass_surface(p, macro, middle) * grass_coverage; }
	if (coverage.r > 0.0) { color += dirt_surface(p, macro, middle) * coverage.r; }
	if (coverage.b > 0.0) { color += sand_surface(p, macro, middle) * coverage.b; }
	if (coverage.a > 0.0) { color += rock_surface(p, macro, middle) * coverage.a; }
	if (grass_coverage > 0.0001) {
		vec4 marks = grass_marks(p, middle, edge);
		if (marks.x > 0.0 || marks.y > 0.0) {
			float root_grass = 1.0;
			if (grass_coverage < 0.9999) {
				vec2 root_warp = boundary_warp(p + marks.zw);
				vec2 root_uv = (pixel + vec2(0.5) + marks.zw * terrain_scale + root_warp) / size;
				root_grass = clamp(1.0 - dot(ground_weights(root_uv), vec4(1.0)), 0.0, 1.0);
			}
			float leaf_shade = hash12(floor(p / 10.0) + 43.0);
			vec3 leaf = grass_tint.rgb * mix(0.8, 1.36, leaf_shade);
			color *= 1.0 - marks.y * root_grass * 0.2;
			color = mix(color, leaf, marks.x * root_grass);
		}
	}
	color = mix(color,dirt_tint.rgb*(0.78+macro*0.18),weights.r*0.7);
	float wet_shore = 1.0 - smoothstep(0.0, 0.22, ground_elevation - water_level);
	color *= 1.0 - wet_shore * 0.20;
	ALBEDO = clamp(color, vec3(0.0), vec3(1.0));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
