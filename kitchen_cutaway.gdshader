shader_type spatial;
render_mode cull_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float sprite_visibility = 0.0;
uniform float metallic_value = 0.0;
uniform float roughness_value = 0.8;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float clear_radius = 0.36;
uniform float feather = 0.045;
uniform vec2 opening_center = vec2(0.5);
uniform mat4 world_to_truck;
varying vec3 truck_position;

void vertex() {
	truck_position = (world_to_truck * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Same screen-space circle and feather as camera_clip_mask.gdshader.
	vec2 centered = SCREEN_UV - opening_center;
	centered.x *= VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	float radius = clear_radius * strength;
	float opening = 1.0 - smoothstep(max(0.0, radius - feather), radius + feather, length(centered));
	float noise = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898,78.233))) * 43758.5453);
	if (noise < sprite_visibility) discard;
	if (strength > 0.001 && truck_position.y > 2.2 && opening * strength > noise) discard;
	ALBEDO = tint.rgb;
	METALLIC = metallic_value;
	ROUGHNESS = roughness_value;
}
