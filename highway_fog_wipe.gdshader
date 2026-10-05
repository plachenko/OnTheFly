shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform vec4 fog_color : source_color = vec4(0.80,0.82,0.83,1.0);

void fragment() {
	float eased = progress * progress * (3.0 - 2.0 * progress);
	float center = mix(1.8,-0.8,eased);
	// Narrower at the top: a grey trapezoid sweeps from right to left.
	float half_width = mix(0.48,0.72,UV.y);
	float mask = 1.0 - smoothstep(half_width-0.002,half_width+0.002,abs(UV.x-center));
	COLOR = vec4(fog_color.rgb,fog_color.a*mask);
}
