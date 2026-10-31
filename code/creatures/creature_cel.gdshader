shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.4, 0.5, 0.2, 1.0);
uniform sampler2D color_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform bool use_vertex_color = false;
uniform bool flat_color = false;
uniform vec3 light_direction = vec3(-0.45, 0.75, 0.65);

void fragment() {
	vec3 color = base_color.rgb;
	if (use_texture) {
		color *= texture(color_texture, UV).rgb;
	}
	if (use_vertex_color) {
		color *= COLOR.rgb;
	}
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float amount = dot(world_normal, normalize(light_direction));
	vec3 shade = amount < 0.12 ? color * vec3(0.40, 0.43, 0.47) : (amount < 0.64 ? color * 0.82 : min(color * 1.12 + vec3(0.015), vec3(1.0)));
	ALBEDO = flat_color ? color : shade;
}
