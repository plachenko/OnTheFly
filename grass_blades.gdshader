shader_type spatial;
render_mode cull_disabled;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wind = sin(TIME * 1.8 + world.x * 0.35 + world.z * 0.21);
	VERTEX.x += wind * UV.y * UV.y * 0.075;
	VERTEX.z += cos(TIME * 1.1 + world.z * 0.3) * UV.y * UV.y * 0.04;
}

void fragment() {
	ALBEDO = COLOR.rgb * mix(0.7, 1.15, UV.y);
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.15);
}
