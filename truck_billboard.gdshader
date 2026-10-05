shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform sampler2D normals : filter_linear_mipmap;
uniform sampler2D previous_atlas : source_color, filter_linear_mipmap;
uniform sampler2D previous_normals : filter_linear_mipmap;
uniform float frame = 0.0;
uniform float previous_frame = 0.0;
uniform float state_mix = 1.0;
uniform float visibility = 0.0;
uniform float animation_strength = 1.0;
varying vec2 picture_uv;
varying flat float heading;
varying flat float elevation;
varying mat3 normal_to_view;
float pixel_noise(vec2 point) { return fract(sin(dot(point,vec2(12.9898,78.233)))*43758.5453); }
void vertex() {
	picture_uv = UV;
	vec3 viewer = transpose(mat3(MODEL_MATRIX))*(INV_VIEW_MATRIX[3].xyz-MODEL_MATRIX[3].xyz);
	heading = mod(atan(viewer.x,viewer.z)*12.0/6.283185+12.0,12.0);
	elevation = clamp(floor(degrees(atan(viewer.y,length(viewer.xz)))/25.0+.5),0.0,2.0);
	normal_to_view = mat3(VIEW_MATRIX)*mat3(MODEL_MATRIX);
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 world = center+INV_VIEW_MATRIX[0].xyz*VERTEX.x+INV_VIEW_MATRIX[1].xyz*VERTEX.y;
	POSITION = PROJECTION_MATRIX*VIEW_MATRIX*vec4(world,1.0);
}
vec4 image_at(sampler2D image, float angle, float index) {
	vec2 local = clamp(picture_uv,vec2(.5/256.0,.5/192.0),vec2(1.0-.5/256.0,1.0-.5/192.0));
	return texture(image,(vec2(mod(angle,12.0),index*3.0+elevation)+local)/vec2(12.0,24.0));
}
vec4 animated_image(sampler2D image,float time) {
	float a=floor(heading); float b=mod(a+1.0,12.0);
	float f=floor(time); float n=mod(f+1.0,8.0);
	vec4 current=mix(mix(image_at(image,a,f),image_at(image,b,f),fract(heading)),mix(image_at(image,a,n),image_at(image,b,n),fract(heading)),fract(time));
	vec4 rest=mix(image_at(image,a,0.0),image_at(image,b,0.0),fract(heading));
	return mix(rest,current,animation_strength);
}
void fragment() {
	if(pixel_noise(FRAGCOORD.xy)>visibility) discard;
	vec4 color=mix(animated_image(previous_atlas,previous_frame),animated_image(atlas,frame),state_mix);
	vec3 normal=mix(animated_image(previous_normals,previous_frame).rgb,animated_image(normals,frame).rgb,state_mix)*2.0-1.0;
	ALBEDO=color.rgb; NORMAL=normalize(normal_to_view*normal);
	ALPHA=color.a; ALPHA_SCISSOR_THRESHOLD=.35;
	ROUGHNESS=.85; SPECULAR=.12;
}
