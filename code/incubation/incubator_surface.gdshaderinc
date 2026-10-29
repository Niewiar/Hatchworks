uniform sampler2D material_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 atlas_offset = vec2(0.0);
uniform int surface_kind : hint_enum("Stone","Wood","Brass","Foliage","Dark") = 0;
uniform float occlusion_strength : hint_range(0.0,1.0) = 0.75;
uniform vec3 reference_tint = vec3(0.32,0.35,0.30);
varying vec3 part_tint;
varying vec3 object_normal;
varying vec2 shape_data;

void vertex() {
    part_tint = COLOR.rgb;
    object_normal = NORMAL;
    shape_data = UV2;
}

void fragment() {
    vec2 padding = vec2(3.0)/vec2(textureSize(material_atlas,0));
    vec2 atlas_uv = atlas_offset+padding+fract(UV)*(vec2(0.5)-2.0*padding);
    float footprint = surface_kind == 0 ? 0.8 : 0.5;
    vec3 paint = textureGrad(material_atlas,atlas_uv,dFdx(UV)*footprint,dFdy(UV)*footprint).rgb;
    vec3 tint = clamp(part_tint/max(reference_tint,vec3(0.001)),vec3(0.65),vec3(1.3));
    paint *= mix(vec3(1.0),tint,0.18);
    float ao = mix(1.0,clamp(shape_data.x,0.0,1.0),occlusion_strength);
    float edge = smoothstep(0.04,0.4,shape_data.y)*smoothstep(0.5,0.96,ao);
    float roughness = 0.9;
    float metallic = 0.0;
    float specular = 0.18;
    if (surface_kind == 0) {
        paint = mix(paint,paint*1.18+vec3(0.008),edge*0.42);
        roughness = 0.93;
    } else if (surface_kind == 1) {
        paint = mix(paint,paint*1.25,edge*0.35);
        roughness = 0.82;
        specular = 0.24;
    } else if (surface_kind == 2) {
        paint *= vec3(0.9,0.88,0.95);
        paint = mix(paint,paint*1.25+vec3(0.025,0.012,0.004),edge*0.55);
        roughness = 0.5;
        metallic = 0.42;
        specular = 0.4;
    } else if (surface_kind == 3) {
        paint = mix(vec3(dot(paint,vec3(0.2126,0.7152,0.0722))),paint,0.92)*vec3(0.8,1.0,0.9);
        float side = 1.0-smoothstep(0.25,0.7,abs(object_normal.y));
        vec3 foliage_side = vec3(0.048,0.075,0.016)*mix(0.8,1.1,dot(paint,vec3(0.2126,0.7152,0.0722)));
        paint = mix(paint,foliage_side,side*0.9);
        roughness = 0.98;
        specular = 0.08;
    } else {
        paint = part_tint*part_tint*0.85;
        roughness = 0.72;
        metallic = 0.1;
    }
    ALBEDO = paint*mix(0.65,1.0,ao);
    ROUGHNESS = roughness;
    METALLIC = metallic;
    SPECULAR = specular;
    AO = ao;
    AO_LIGHT_AFFECT = 0.4;
}
