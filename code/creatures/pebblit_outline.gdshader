shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float width = 0.006;
uniform vec3 ink_color = vec3(0.008, 0.013, 0.025);
void vertex() {
 VERTEX += NORMAL * width;
}
void fragment() {
 ALBEDO = ink_color;
}
