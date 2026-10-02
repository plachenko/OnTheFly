shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 glow_color : source_color = vec4(0.12, 1.0, 0.46, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.8;
uniform bool parking_ticks = false;

void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV);
	float feather = smoothstep(0.0, 0.20, min(edge.x, edge.y));
	float pulse = 0.92 + 0.08 * sin(TIME * 2.4);
	ALBEDO = glow_color.rgb * glow_strength * pulse;
	ALPHA = feather * 0.58 * glow_color.a;
	if (parking_ticks) {
		float border = max(1.0 - smoothstep(0.025, 0.055, edge.x), 1.0 - smoothstep(0.012, 0.025, edge.y));
		float dash = 1.0 - step(0.72, fract((UV.x * 4.0 + UV.y * 12.0)));
		float hatch = 1.0 - step(0.30, fract(UV.y * 8.0 + UV.x * 1.5));
		float interior = step(0.09, edge.x) * step(0.045, edge.y);
		ALPHA = max(border * dash, hatch * interior * 0.85) * glow_color.a;
	}
}
