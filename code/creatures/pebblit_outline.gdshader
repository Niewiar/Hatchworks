shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float width = 0.006;
uniform vec3 ink_color = vec3(0.008, 0.013, 0.025);
void vertex() {
 VERTEX += NORMAL * width;
}
void fragment() {
 ALBEDO = OUTPUT_IS_SRGB ? mix(12.92 * ink_color, 1.055 * pow(max(ink_color, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), ink_color)) : ink_color;
}
