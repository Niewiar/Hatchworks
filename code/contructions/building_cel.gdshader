shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D cavity_texture : filter_linear_mipmap, repeat_disable;
uniform vec3 light_direction = vec3(-0.45,0.75,0.65);
uniform float cavity_strength = 0.65;
uniform float warmth = 0.0;
vec3 to_linear(vec3 color) {
 return mix(color/12.92,pow((color+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),color));
}
vec3 to_srgb(vec3 color) {
 return mix(color*12.92,1.055*pow(max(color,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),color));
}
void fragment() {
 vec3 paint = texture(albedo_texture,UV).rgb;
 if (OUTPUT_IS_SRGB) {
  paint = to_linear(paint);
 }
 vec3 normal = normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 float amount = dot(normal,normalize(light_direction));
 vec3 band = amount < 0.10 ? vec3(0.48,0.52,0.55) : (amount < 0.64 ? vec3(0.83,0.83,0.80) : vec3(1.08,1.06,1.0));
 float cavity = mix(1.0,texture(cavity_texture,UV).r,cavity_strength);
 vec3 color = paint*band*cavity;
 ALBEDO = OUTPUT_IS_SRGB ? to_srgb(color) : color;
 float warm_mask = smoothstep(1.18,1.65,paint.r/max(paint.g,0.01))*smoothstep(1.15,1.8,paint.g/max(paint.b,0.01));
 EMISSION = paint*vec3(1.0,0.72,0.35)*warmth*warm_mask;
 ROUGHNESS = 1.0;
 SPECULAR = 0.0;
}
