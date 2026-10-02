shader_type particles;
render_mode disable_force, disable_velocity;
uniform sampler2D positions : filter_nearest, repeat_disable;

void start() {
	vec4 point = texelFetch(positions, ivec2(int(INDEX), 0), 0);
	float angle = point.a * TAU;
	float scale = mix(0.65, 1.35, fract(point.a * 17.0));
	TRANSFORM = mat4(vec4(cos(angle) * scale, 0.0, -sin(angle) * scale, 0.0),
		vec4(0.0, scale, 0.0, 0.0), vec4(sin(angle) * scale, 0.0, cos(angle) * scale, 0.0), vec4(point.xyz, 1.0));
	COLOR = vec4(mix(vec3(0.16, 0.31, 0.08), vec3(0.39, 0.57, 0.15), fract(point.a * 31.0)), 1.0);
	VELOCITY = vec3(0.0);
}

void process() {}
