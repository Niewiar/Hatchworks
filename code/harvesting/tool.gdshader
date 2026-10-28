shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

void fragment() {
	ALBEDO = COLOR.rgb;
	METALLIC = COLOR.a * 0.55;
	EMISSION = COLOR.rgb * COLOR.a * 0.08;
	ROUGHNESS = mix(0.9,0.48,COLOR.a);
}
