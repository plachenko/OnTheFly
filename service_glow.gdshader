shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 glow_color : source_color = vec4(0.12, 1.0, 0.46, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.8;

void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV);
	float feather = smoothstep(0.0, 0.20, min(edge.x, edge.y));
	float pulse = 0.92 + 0.08 * sin(TIME * 2.4);
	ALBEDO = glow_color.rgb * glow_strength * pulse;
	ALPHA = feather * 0.58 * glow_color.a;
}
