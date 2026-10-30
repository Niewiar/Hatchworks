shader_type spatial;
render_mode cull_back;

uniform sampler2D shell_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 inner_color : source_color = vec3(0.86,0.89,0.72);

float hash(vec2 p) {
    return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

void fragment() {
    vec3 pigment = texture(shell_texture,UV).rgb;
    float outer = smoothstep(0.35,0.8,COLOR.r);
    ALBEDO = mix(inner_color,pigment,outer);
    ROUGHNESS = 0.82+hash(floor(UV*vec2(900.0,600.0)))*0.06;
    SPECULAR = 0.22;
}
