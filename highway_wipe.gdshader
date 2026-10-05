shader_type canvas_item;
render_mode unshaded;
uniform float progress = 0.0;
uniform bool revealing = false;

void fragment() {
	// Sloping edges form a trapezoid that enters from the right and exits left.
	float eased = progress * progress * (3.0 - 2.0 * progress);
	float skew = (UV.y - 0.5) * 0.20;
	float edge = revealing ? (-0.15 + eased * 1.30 + skew) : (1.15 - eased * 1.30 + skew);
	float mask = revealing ? step(UV.x, edge) : step(edge, UV.x);
	vec3 cream = vec3(1.0, 0.949, 0.843);
	vec3 black = vec3(0.055, 0.06, 0.075);
	vec3 color = cream;
	float stripe = step(0.5, fract((UV.x + UV.y * 0.62) * 14.0));
	color = mix(cream, black, stripe);
	if (UV.y > 0.88) {
		vec2 cell = floor(vec2(UV.x * 32.0, (UV.y - 0.88) * 16.6667));
		color = mix(cream, black, mod(cell.x + cell.y, 2.0));
	}
	COLOR = vec4(color, mask);
}
