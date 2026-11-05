shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float width = 0.003;
uniform vec3 ink_color : source_color = vec3(0.13,0.14,0.10);
void vertex() { VERTEX += NORMAL*width; }
void fragment() { ALBEDO = ink_color; }
