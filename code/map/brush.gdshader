shader_type canvas_item;
render_mode unshaded;

uniform float brush_radius = 18.0;
uniform float brush_hardness = 0.7;
uniform float brush_diameter = 44.0;
uniform float fill_opacity : hint_range(0.0, 1.0) = 0.08;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.8);

vec4 over(vec4 background, vec4 foreground) {
	float alpha = foreground.a + background.a * (1.0 - foreground.a);
	vec3 rgb = foreground.rgb * foreground.a + background.rgb * background.a * (1.0 - foreground.a);
	return vec4(rgb / max(alpha, 0.0001), alpha);
}

void fragment() {
	float distance_from_center = length((UV - vec2(0.5)) * brush_diameter);
	// Derivatives keep the outline thin at different camera zooms and sprite scales.
	float pixel_width = max(fwidth(distance_from_center), 0.0001);
	float edge_distance = abs(distance_from_center - brush_radius) / pixel_width;
	float outline = 1.0 - smoothstep(0.35, 1.0, edge_distance);
	float shadow = 1.0 - smoothstep(1.25, 2.25, edge_distance);
	float falloff = 1.0 - smoothstep(brush_radius * brush_hardness, brush_radius, distance_from_center);
	vec4 color = vec4(outline_color.rgb, fill_opacity * falloff);
	color = over(color, vec4(shadow_color.rgb, shadow_color.a * shadow));
	COLOR = over(color, vec4(outline_color.rgb, outline_color.a * outline));
}
