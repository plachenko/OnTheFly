shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D atlas : source_color, filter_nearest_mipmap;
uniform sampler2D clothing_mask : filter_nearest_mipmap;
uniform vec4 clothing_color : source_color = vec4(1.0);
uniform int animation_row = 0;
uniform int animation_frame = 0;
uniform float fade_alpha = 1.0;
varying flat float view_angle;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 viewer = INV_VIEW_MATRIX[3].xyz - center;
	vec3 forward = normalize(MODEL_MATRIX[2].xyz);
	float angle = atan(viewer.x, viewer.z) - atan(forward.x, forward.z);
	view_angle = mod(floor(angle * 8.0 / 6.283185 + 0.5) + 8.0, 8.0);
	// Camera-local orientation: no patron transform changes or replicated rotation.
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = center + right * VERTEX.x * length(MODEL_MATRIX[0].xyz) + up * VERTEX.y * length(MODEL_MATRIX[1].xyz);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 cell = vec2(float(animation_frame), view_angle * 4.0 + float(animation_row));
	// Half-texel inset prevents adjacent cells bleeding at smaller mip levels.
	vec2 local_uv = clamp(UV, vec2(0.5 / 96.0, 0.5 / 128.0), vec2(1.0 - 0.5 / 96.0, 1.0 - 0.5 / 128.0));
	vec2 atlas_uv = (cell + local_uv) / vec2(12.0, 32.0);
	vec4 texel = texture(atlas, atlas_uv);
	float mask = texture(clothing_mask, atlas_uv).r;
	float shade = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(texel.rgb, clothing_color.rgb * (0.45 + shade * 0.55), mask);
	// Stable screen-door fade retains the inexpensive cutout rendering path.
	float threshold = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	if (fade_alpha < threshold) { discard; }
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
