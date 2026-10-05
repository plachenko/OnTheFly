shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV);
	float border = max(1.0 - smoothstep(0.025, 0.045, edge.x), 1.0 - smoothstep(0.01, 0.025, edge.y));
	float along = edge.x < edge.y ? UV.y * 12.0 : UV.x * 4.0;
	float dash = 1.0 - step(0.65, fract(along));
	ALBEDO = vec3(1.0, 0.8, 0.04);
	ALPHA = max(0.18, border * dash) * (0.92 + 0.08 * sin(TIME * 2.0));
}
