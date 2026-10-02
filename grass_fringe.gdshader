shader_type spatial;
render_mode cull_disabled;
uniform sampler2D silhouette : filter_linear, repeat_disable;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.x += sin(TIME * 1.8 + world.x * 0.35 + world.z * 0.21) * pow(1.0 - UV.y, 2.0) * 0.04;
}
void fragment() {
	ALBEDO = COLOR.rgb * mix(1.1, 0.7, UV.y);
	ALPHA = texture(silhouette, UV).a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.15);
}
