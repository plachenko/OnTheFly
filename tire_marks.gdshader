shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float clock = 0.0;
varying float opacity;
void vertex() { opacity = INSTANCE_CUSTOM.y * (1.0 - smoothstep(12.0, 20.0, clock - INSTANCE_CUSTOM.x)); }
void fragment() { ALBEDO = vec3(0.035); ALPHA = opacity * 0.65; }
