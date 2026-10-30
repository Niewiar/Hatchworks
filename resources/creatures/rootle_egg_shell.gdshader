shader_type spatial;
render_mode cull_back;

uniform vec3 inner_color : source_color = vec3(0.84,0.73,0.55);

float hash(vec2 p) {
    return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

void fragment() {
    vec2 p = vec2(UV.x,1.0-UV.y);
    float grain = sin(p.x*180.0+sin(p.y*37.0)*0.8)*0.5+0.5;
    float fibers = smoothstep(0.79,0.98,grain)*0.13;
    vec3 body = mix(vec3(0.56,0.32,0.14),vec3(0.86,0.66,0.34),0.45+0.18*sin(p.x*24.0)+0.12*sin(p.y*19.0))-fibers;
    vec2 cells = p*vec2(25.0,12.0);
    cells.x += mod(floor(cells.y),2.0)*0.5;
    vec2 local = fract(cells)-0.5;
    float scale_edge = smoothstep(0.32,0.46,length(local*vec2(0.90,1.2)));
    vec3 cap = mix(vec3(0.43,0.29,0.15),vec3(0.65,0.49,0.25),hash(floor(cells)))-scale_edge*0.12;
    float cap_mask = smoothstep(0.70,0.72,p.y);
    vec2 leaf = vec2(fract(p.x*7.0)-0.5,fract(p.y*4.0)-0.5);
    float stamp = (1.0-smoothstep(0.12,0.15,length(leaf*vec2(1.7,1.0))))*(1.0-cap_mask);
    vec3 pigment = mix(body,vec3(0.52,0.55,0.24),stamp*0.7);
    pigment = mix(pigment,cap,cap_mask);
    float outer = smoothstep(0.35,0.8,COLOR.r);
    ALBEDO = mix(inner_color,pigment,outer);
    ROUGHNESS = 0.86;
    SPECULAR = 0.22;
}
