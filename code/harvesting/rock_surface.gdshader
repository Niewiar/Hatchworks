shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 light_direction = vec3(-0.45,0.75,0.65);
void fragment() {
    vec3 pigment = texture(albedo_texture,UV).rgb;
    vec3 world_normal = normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
    float amount = dot(world_normal,normalize(light_direction));
    vec3 shade = amount < 0.10 ? pigment*vec3(0.48,0.56,0.58) : (amount < 0.64 ? pigment*0.83 : min(pigment*1.10,vec3(1.0)));
    ALBEDO = OUTPUT_IS_SRGB ? mix(12.92*shade,1.055*pow(max(shade,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),shade)) : shade;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
