shader_type spatial;
render_mode unshaded;
uniform vec3 shadow_color = vec3(0.055, 0.095, 0.18);
uniform vec3 base_color = vec3(0.13, 0.26, 0.40);
uniform vec3 highlight_color = vec3(0.29, 0.47, 0.60);
uniform vec3 light_direction = vec3(-0.45, 0.75, 0.65);
void fragment() {
 vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
 float light_amount = dot(world_normal, light_direction);
 ALBEDO = light_amount < 0.16 ? shadow_color : (light_amount < 0.64 ? base_color : highlight_color);
}
