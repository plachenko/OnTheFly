shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D paint : source_color;
uniform bool textured = false;
uniform bool vertex_color = false;
uniform float metallic_value = 0.0;
uniform float roughness_value = .8;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float sprite_visibility = 0.0;
void fragment() {
	float noise=fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453);
	if(noise<sprite_visibility) discard;
	vec4 color=tint*(textured?texture(paint,UV):vec4(1.0))*(vertex_color?COLOR:vec4(1.0));
	ALBEDO=color.rgb; METALLIC=metallic_value; ROUGHNESS=roughness_value; EMISSION=emission_color;
}
