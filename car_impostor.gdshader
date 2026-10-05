shader_type spatial;
render_mode cull_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform sampler2D normal_atlas : source_color, filter_linear_mipmap;
varying flat vec2 frame_cell;
varying mat3 model_to_view;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 viewer = INV_VIEW_MATRIX[3].xyz - center;
	vec3 forward = normalize(MODEL_MATRIX[2].xyz);
	float angle = atan(viewer.x,viewer.z)-atan(forward.x,forward.z);
	float heading = mod(floor(angle*16.0/6.283185+0.5)+16.0,16.0);
	float pitch = atan(viewer.y,length(viewer.xz));
	float elevation = clamp(floor(pitch/0.349066+0.5),0.0,3.0);
	frame_cell = vec2(heading,elevation);
	model_to_view = mat3(VIEW_MATRIX)*mat3(MODEL_MATRIX);
	vec3 world = center + INV_VIEW_MATRIX[0].xyz*VERTEX.x*length(MODEL_MATRIX[0].xyz) + INV_VIEW_MATRIX[1].xyz*VERTEX.y*length(MODEL_MATRIX[1].xyz);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world,1.0);
}

void fragment() {
	vec2 local_uv = clamp(UV,vec2(0.5/256.0,0.5/192.0),vec2(1.0-0.5/256.0,1.0-0.5/192.0));
	vec2 atlas_uv = (frame_cell+local_uv)/vec2(16.0,4.0);
	vec4 texel = texture(atlas,atlas_uv);
	ALBEDO = texel.rgb;
	NORMAL = normalize(model_to_view*(texture(normal_atlas,atlas_uv).rgb*2.0-1.0));
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
}
