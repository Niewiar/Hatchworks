shader_type spatial;
render_mode unshaded;
uniform vec3 shadow_color = vec3(0.29, 0.15, 0.047);
uniform vec3 base_color = vec3(0.72, 0.405, 0.12);
uniform vec3 highlight_color = vec3(0.98, 0.70, 0.33);
uniform vec3 light_direction = vec3(-0.45, 0.75, 0.65);
uniform sampler2D sand_texture : source_color, filter_linear_mipmap, repeat_enable;
void fragment() {
 vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
 float light_amount = dot(world_normal, light_direction);
 vec3 tone = light_amount < 0.16 ? shadow_color : (light_amount < 0.64 ? base_color : highlight_color);
 ALBEDO = tone * texture(sand_texture, UV).rgb;
}
