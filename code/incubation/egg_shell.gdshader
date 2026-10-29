shader_type spatial;
render_mode cull_back;

float hash(vec2 p) {
    return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

float grain(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}

void fragment() {
    vec2 p = UV*vec2(66.0,43.0);
    vec2 cell = floor(p);
    vec2 f = fract(p);
    float fleck = 0.0;
    for (int y=-1; y<=1; y++) {
        for (int x=-1; x<=1; x++) {
            vec2 offset = vec2(float(x),float(y));
            vec2 id = cell+offset;
            float random = hash(id);
            vec2 center = vec2(hash(id+12.3),hash(id+51.7))*0.6+0.2;
            vec2 delta = (f-offset-center)*vec2(1.0,1.35);
            float radius = mix(0.035,0.15,hash(id+7.9));
            float uneven = 0.82+grain(p*4.0)*0.3;
            float spot = 1.0-smoothstep(radius*0.70,radius*uneven,length(delta));
            fleck = max(fleck,spot*step(0.62,random));
        }
    }
    float soft_variation = grain(UV*vec2(20,14))*0.018;
    vec3 outer = mix(vec3(0.76,0.69,0.50),vec3(0.26,0.18,0.07),fleck*0.72)-soft_variation;
    ALBEDO = mix(vec3(0.81,0.77,0.64),outer,smoothstep(0.35,0.8,COLOR.r));
    ROUGHNESS = 0.8+grain(UV*vec2(220,180))*0.08;
    SPECULAR = 0.22;
}
