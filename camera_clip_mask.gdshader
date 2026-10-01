shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float clear_radius : hint_range(0.1, 0.5) = 0.28;
uniform float feather : hint_range(0.01, 0.2) = 0.045;

void fragment() {
	vec2 centered = SCREEN_UV - vec2(0.5);
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float edge = smoothstep(clear_radius - feather, clear_radius + feather, length(centered));
	COLOR = vec4(0.015, 0.02, 0.025, edge * strength);
}
