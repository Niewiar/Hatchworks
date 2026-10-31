shader_type spatial;
render_mode unshaded, cull_back, depth_prepass_alpha;

uniform vec4 base_color : source_color = vec4(0.95, 0.9, 0.75, 0.8);
uniform sampler2D color_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform bool use_vertex_color = false;
uniform bool flat_color = false;
uniform vec3 light_direction = vec3(-0.45, 0.75, 0.65);

void fragment() {
    vec4 surface = base_color;
    if (use_texture) {
        surface *= texture(color_texture, UV);
    }
    if (use_vertex_color) {
        surface *= COLOR;
    }
    vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    float amount = abs(dot(world_normal, normalize(light_direction)));
    vec3 shade = amount < 0.2 ? surface.rgb * 0.72 : (amount < 0.65 ? surface.rgb * 0.9 : min(surface.rgb * 1.06, vec3(1.0)));
    ALBEDO = flat_color ? surface.rgb : shade;
    ALPHA = surface.a;
}
