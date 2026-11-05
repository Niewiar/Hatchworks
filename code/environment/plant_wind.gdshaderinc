uniform float wind_strength = 0.06;
uniform bool wind_enabled = true;
uniform float flutter_strength = 0.0;
vec3 plant_wind(vec3 local_vertex, vec3 local_normal, float weight, float tip_uv, mat4 model) {
    float mask = clamp(weight,0.0,1.0);
    vec3 origin = model[3].xyz;
    float phase = dot(origin.xz,vec2(0.73,0.48));
    float gust = 0.72 + 0.28 * sin(TIME * 1.0471975512 - phase * 0.38);
    float breeze = sin(TIME * 1.0471975512 + phase) + 0.32 * sin(TIME * 2.0943951024 + phase * 0.63);
    float growth_scale = min(1.0,length(model[1].xyz));
    vec3 world_bend = vec3(0.85,0.0,0.36) * breeze * gust * wind_strength * mask * mask * growth_scale;
    float flutter = sin(TIME * 5.235987756 + local_vertex.x * 16.0 + local_vertex.z * 11.0) * flutter_strength * mask * mask * smoothstep(0.0,0.55,tip_uv);
    return wind_enabled ? inverse(mat3(model)) * world_bend + local_normal * flutter : vec3(0.0);
}
