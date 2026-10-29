shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float progress : hint_range(0.0,1.0) = 0.0;
void fragment() {
    if (progress < COLOR.r) { discard; }
    ALBEDO = vec3(0.055,0.031,0.009);
}
