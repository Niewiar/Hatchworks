shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float width = 0.003;
uniform vec4 ink_color : source_color = vec4(0.12,0.105,0.08,1.0);
void vertex() {
 VERTEX += NORMAL*width;
}
void fragment() {
 ALBEDO = ink_color.rgb;
}
