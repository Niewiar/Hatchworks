shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
#include "res://code/environment/plant_wind.gdshaderinc"
uniform float width = 0.002;
uniform vec3 ink_color : source_color = vec3(0.13,0.14,0.10);
void vertex() {
    VERTEX += plant_wind(VERTEX,NORMAL,COLOR.a,UV.y,MODEL_MATRIX);
    VERTEX += NORMAL*width;
}
void fragment() { ALBEDO = ink_color; }
