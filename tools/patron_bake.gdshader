shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool mask_pass = false;
varying float world_height;
void vertex() { world_height = (MODEL_MATRIX * vec4(VERTEX,1.0)).y; }
void fragment() {
 vec4 texel = texture(albedo_texture,UV) * tint;
 bool skin = texel.r > texel.g * 1.12 && texel.g > texel.b * 1.12;
 float mask = (!skin && world_height > 0.35 && world_height < 1.45) ? 1.0 : 0.0;
 ALBEDO = mask_pass ? vec3(mask) : texel.rgb;
 ALPHA = texel.a;
 ALPHA_SCISSOR_THRESHOLD = 0.5;
}
