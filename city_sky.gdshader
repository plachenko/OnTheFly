shader_type sky;

uniform vec4 zenith_color : source_color = vec4(0.30, 0.51, 0.70, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.72, 0.82, 0.84, 1.0);
uniform vec4 far_city_color : source_color = vec4(0.51, 0.63, 0.68, 1.0);
uniform vec4 near_city_color : source_color = vec4(0.34, 0.47, 0.54, 1.0);
uniform float skyline_height : hint_range(0.03, 0.25) = 0.14;
uniform float skyline_vertical_offset : hint_range(-0.15, 0.1) = -0.045;
uniform vec4 cloud_color : source_color = vec4(0.93, 0.96, 0.97, 1.0);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.48;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.55;
uniform vec4 sun_color : source_color = vec4(1.0, 0.91, 0.69, 1.0);
uniform vec3 sun_direction = vec3(-0.3838, 0.7431, 0.5481);

float skyline_hash(float value) {
	return fract(sin(value * 127.1 + 78.233) * 43758.5453);
}

float cloud_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	vec2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
	float lower = mix(cloud_hash(cell), cloud_hash(cell + vec2(1.0, 0.0)), blend.x);
	float upper = mix(cloud_hash(cell + vec2(0.0, 1.0)), cloud_hash(cell + vec2(1.0, 1.0)), blend.x);
	return mix(lower, upper, blend.y);
}

float cloud_pattern(vec2 point) {
	return cloud_noise(point) * 0.55 + cloud_noise(point * 2.13 + 8.4) * 0.30 + cloud_noise(point * 4.41 - 3.7) * 0.15;
}

float skyline_layer(float angle, float eye_height, float count, float offset, float height_scale) {
	float coordinate = (angle / 6.2831853 + 0.5) * count + offset;
	float building = floor(coordinate);
	float width_position = fract(coordinate);
	float random_height = skyline_hash(building + offset * 13.0);
	float roof = 0.022 + (0.025 + pow(random_height, 2.0) * skyline_height) * height_scale + skyline_vertical_offset;
	float gap = 0.04 + skyline_hash(building + 41.0) * 0.08;
	return step(gap, width_position) * step(width_position, 1.0 - gap) * step(eye_height, roof) * step(-0.18, eye_height);
}

void sky() {
	float elevation = clamp(EYEDIR.y, -1.0, 1.0);
	vec3 color = mix(horizon_color.rgb, zenith_color.rgb, smoothstep(-0.09, 0.78, elevation));
	float haze = 1.0 - smoothstep(-0.10, 0.22, elevation);
	color = mix(color, horizon_color.rgb, haze * 0.25);
	float angle = atan(EYEDIR.x, EYEDIR.z);
	vec2 cloud_coordinates = vec2(angle * 3.2, elevation * 8.0);
	float cloud_shape = cloud_pattern(cloud_coordinates);
	float cloud_mask = smoothstep(0.54 - cloud_coverage * 0.18, 0.68 - cloud_coverage * 0.12, cloud_shape);
	cloud_mask *= smoothstep(0.03, 0.25, elevation) * (1.0 - smoothstep(0.68, 0.95, elevation));
	color = mix(color, cloud_color.rgb, cloud_mask * cloud_opacity);
	float far_buildings = skyline_layer(angle, elevation, 180.0, 7.3, 0.67);
	float near_buildings = skyline_layer(angle, elevation, 126.0, 29.7, 1.0);
	color = mix(color, far_city_color.rgb, far_buildings * 0.72);
	color = mix(color, near_city_color.rgb, near_buildings * 0.82);
	float sun_alignment = max(dot(normalize(EYEDIR), normalize(sun_direction)), 0.0);
	color += sun_color.rgb * pow(sun_alignment, 32.0) * 0.24;
	color = mix(color, sun_color.rgb, smoothstep(0.9989, 0.9995, sun_alignment));
	COLOR = color;
}
