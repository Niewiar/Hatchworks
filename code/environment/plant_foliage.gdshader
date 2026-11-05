shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://code/environment/plant_wind.gdshaderinc"
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool has_texture = false;
uniform bool use_vertex_color = true;
uniform bool leaf_detail = false;
uniform vec4 base_tint : source_color = vec4(1.0);
uniform vec3 light_direction = vec3(-0.45,0.75,0.65);
void vertex() {
    VERTEX += plant_wind(VERTEX,NORMAL,COLOR.a,UV.y,MODEL_MATRIX);
}
void fragment() {
    vec3 pigment = base_tint.rgb;
    if (has_texture) { pigment *= texture(albedo_texture,UV).rgb; }
    if (use_vertex_color) { pigment *= COLOR.rgb; }
    if (leaf_detail) {
        float centerline = 1.0-smoothstep(0.009,0.022,abs(UV.x-0.5));
        float branchline = 1.0-smoothstep(0.012,0.034,abs(fract(UV.y*6.0-abs(UV.x-0.5)*2.2+0.5)-0.5));
        float taper = smoothstep(0.03,0.16,UV.y)*(1.0-smoothstep(0.85,1.0,UV.y));
        pigment *= (0.82+UV.y*0.18) * (1.0 - taper * (centerline*0.28+branchline*0.12));
        float border_distance = min(min(UV.x,1.0-UV.x)*0.8,min(UV.y,1.0-UV.y)*2.5);
        float border = 1.0-smoothstep(0.012,0.028,border_distance);
        pigment = mix(pigment,vec3(0.045,0.06,0.025),border*0.80);
    }
    vec3 facing_normal = FRONT_FACING ? NORMAL : -NORMAL;
    vec3 world_normal = normalize((INV_VIEW_MATRIX*vec4(facing_normal,0.0)).xyz);
    float amount = dot(world_normal,normalize(light_direction));
    vec3 shade = amount < 0.10 ? pigment*vec3(0.48,0.56,0.58) : (amount < 0.64 ? pigment*0.83 : min(pigment*1.10,vec3(1.0)));
    ALBEDO = OUTPUT_IS_SRGB ? mix(12.92*shade,1.055*pow(max(shade,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),shade)) : shade;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
