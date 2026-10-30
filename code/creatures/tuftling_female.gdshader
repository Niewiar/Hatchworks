shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float normal_strength = 0.75;
uniform float roughness_factor = 1.0;
uniform float specular_amount = 0.5;

void fragment() {
	vec3 coat = texture(albedo_texture, UV).rgb;
	float plant_mask = smoothstep(0.0, 0.08, coat.g - coat.r) * smoothstep(0.02, 0.12, coat.g - coat.b);
	vec3 amber = vec3(coat.g * 1.05, coat.r * 0.65 + coat.g * 0.15, coat.b * 0.6);
	ALBEDO = mix(coat, amber, plant_mask) * albedo_color.rgb;
	METALLIC = 0.0;
	ROUGHNESS = texture(roughness_texture, UV).g * roughness_factor;
	SPECULAR = specular_amount;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
