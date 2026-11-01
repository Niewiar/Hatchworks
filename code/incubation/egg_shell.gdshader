shader_type spatial;
render_mode unshaded, cull_disabled;
uniform int species = 0;
uniform vec3 inner_color : source_color = vec3(0.89,0.83,0.65);
uniform vec3 light_direction = vec3(-0.45,0.75,0.65);
float hash(vec2 p) {
 return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
vec2 hash2(vec2 p) {
 return vec2(hash(p),hash(p+31.7));
}
vec3 pigment(vec2 p) {
 float u = p.x;
 float v = p.y;
 vec3 col = vec3(0.8);
 if (species == 0) {
  float layer = floor(v*2.0);
  vec2 q = vec2(fract(u*5.0+layer*0.46)-0.5,fract(v*2.0));
  float leaf_width = 0.47*pow(max(sin(q.y*3.14159),0.0),0.72);
  float edge = abs(q.x)-leaf_width;
  float leaf = 1.0-smoothstep(-0.015,0.012,edge);
  vec3 base = mix(vec3(0.59,0.66,0.35),vec3(0.78,0.79,0.46),v);
  vec3 green = mix(vec3(0.31,0.47,0.22),vec3(0.51,0.63,0.31),q.y);
  float vein = 1.0-smoothstep(0.006,0.015,abs(q.x));
  float branch = 1.0-smoothstep(0.009,0.023,abs(fract(q.y*5.0-abs(q.x)*2.8)-0.5));
  green = mix(green,vec3(0.67,0.72,0.42),max(vein,branch*0.55));
  col = mix(base,green,leaf);
  col = mix(col,vec3(0.29,0.39,0.19),(1.0-smoothstep(0.006,0.020,abs(edge)))*0.72);
 } else if (species == 1) {
  float line = u*14.0+0.58*sin(v*8.0+sin(u*6.283)*2.0)+0.13*sin(v*23.0+u*13.0);
  float stripe = 0.5+0.5*sin(line*6.283);
  col = mix(vec3(0.37,0.22,0.10),vec3(0.72,0.50,0.25),smoothstep(0.07,0.76,stripe));
  col = mix(col,vec3(0.83,0.64,0.36),pow(stripe,6.0)*0.55);
  for (int i=0;i<3;i++) {
   vec2 knot = vec2(0.19+float(i)*0.32,0.31+float(i%2)*0.31);
   vec2 d = vec2(min(abs(u-knot.x),1.0-abs(u-knot.x))*8.0,(v-knot.y)*5.0);
   float r = length(d);
   float ring = 1.0-smoothstep(0.06,0.13,abs(fract(r*2.8)-0.5));
   col = mix(col,vec3(0.29,0.18,0.09),ring*(1.0-smoothstep(0.32,0.58,r))*0.8);
  }
 } else if (species == 2) {
  vec2 q = vec2(u*8.0,v*5.0);
  vec2 cell = floor(q);vec2 f = fract(q);
  float first = 9.0;float second = 9.0;vec2 chosen = vec2(0.0);
  for(int x=-1;x<=1;x++) {
   for(int y=-1;y<=1;y++) {
    vec2 offset=vec2(float(x),float(y));vec2 jitter=hash2(mod(cell+offset,vec2(8.0,100.0)));
    float d=length(offset+0.2+jitter*0.6-f);
    if(d<first){second=first;first=d;chosen=cell+offset;}else if(d<second){second=d;}
   }
  }
  col=mix(vec3(0.26,0.39,0.48),vec3(0.53,0.64,0.67),hash(mod(chosen,vec2(8.0,100.0))));
  col=mix(vec3(0.16,0.23,0.27),col,smoothstep(0.015,0.07,second-first));
  col+=vec3(0.06,0.07,0.06)*(1.0-smoothstep(0.075,0.12,second-first));
 } else {
  float tier=floor(v*3.0);
  vec2 q=vec2(fract(u*6.0+tier*0.5)-0.5,fract(v*3.0));
  float width=0.47*pow(max(sin(q.y*3.14159),0.0),0.52);
  float edge=abs(q.x)-width;
  float petal=1.0-smoothstep(-0.008,0.014,edge);
  vec3 color_a=vec3(0.92,0.85,0.58);
  vec3 color_b=tier<1.0?vec3(0.56,0.65,0.41):(tier<2.0?vec3(0.67,0.60,0.73):vec3(0.93,0.87,0.68));
  col=mix(color_a,mix(color_b,color_a,q.y*0.7),petal);
  col=mix(col,vec3(0.50,0.49,0.35),(1.0-smoothstep(0.005,0.018,abs(edge)))*0.45);
  col+=vec3(0.06)*(1.0-smoothstep(0.012,0.026,abs(q.x)))*petal;
 }
 col*=0.985+hash(floor(p*vec2(430.0,320.0)))*0.03;
 return mix(col/12.92,pow((col+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),col));
}
void fragment() {
 vec3 interior=OUTPUT_IS_SRGB?mix(inner_color/12.92,pow((inner_color+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),inner_color)):inner_color;
 vec3 base=mix(interior,pigment(UV),smoothstep(0.35,0.8,COLOR.r));
 vec3 world_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 float amount=dot(world_normal,normalize(light_direction));
 vec3 shade=amount<0.12?base*vec3(0.40,0.43,0.47):(amount<0.64?base*0.82:min(base*1.12+vec3(0.015),vec3(1.0)));
 ALBEDO=OUTPUT_IS_SRGB?mix(12.92*shade,1.055*pow(max(shade,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),shade)):shade;
}
