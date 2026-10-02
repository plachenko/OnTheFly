shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 window_color : source_color = vec4(1.0, 0.76, 0.38, 1.0);
uniform float emission_strength = 2.5;
varying float vertical_face;
varying float window_lit;
varying float streamer;
varying float rgb_phase;

void vertex() {
	vertical_face = abs(NORMAL.y) < 0.25 ? 1.0 : 0.0;
	window_lit = COLOR.r;
	streamer = COLOR.g;
	rgb_phase = COLOR.b;
}

void fragment() {
	vec4 texel = texture(albedo_texture, UV);
	ALBEDO = texel.rgb * tint.rgb;
	ROUGHNESS = 0.95;
	// The palette's blue glass is distinct from the grey walls and roof.
	float glass = texel.b > 0.3 && texel.b > texel.g * 1.15 && texel.g > texel.r * 1.15 ? 1.0 : 0.0;
	// Rare gaming rooms cycle slowly through magenta, cyan, and green.
	vec3 rgb = 0.5 + 0.5 * cos(vec3(0.0, 2.094, 4.189) + TIME * 0.35 + rgb_phase * 6.283);
	rgb = pow(rgb, vec3(1.5));
	EMISSION = mix(window_color.rgb, rgb * 1.25, streamer) * emission_strength * glass * vertical_face * window_lit;
}
