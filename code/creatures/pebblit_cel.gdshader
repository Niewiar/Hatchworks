shader_type spatial;
render_mode unshaded;
uniform vec3 shadow_color = vec3(0.027, 0.033, 0.040);
uniform vec3 base_color = vec3(0.095, 0.113, 0.126);
uniform vec3 highlight_color = vec3(0.223, 0.243, 0.223);
uniform vec3 light_direction = vec3(-0.45, 0.75, 0.65);
vec3 linear_to_srgb(vec3 value) {
 return mix(12.92 * value, 1.055 * pow(max(value, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), value));
}
void fragment() {
 vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
 float light_amount = dot(world_normal, light_direction);
 vec3 tone = light_amount < 0.16 ? shadow_color : (light_amount < 0.64 ? base_color : highlight_color);
 ALBEDO = OUTPUT_IS_SRGB ? linear_to_srgb(tone) : tone;
}
