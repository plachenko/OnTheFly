shader_type spatial;
render_mode cull_disabled;
void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz * vec3(1.0,0.0,1.0));
	vec3 up = vec3(0.0,1.0,0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right*scale.x,0.0),vec4(up*scale.y,0.0),vec4(cross(right,up)*scale.z,0.0),MODEL_MATRIX[3]);
}
void fragment() {
	float x = abs(UV.x-.5);
	float y = UV.y;
	bool leaves = (y>.02 && y<.48 && x<(y-.02)*.65) || (y>.22 && y<.7 && x<(y-.22)*.72) || (y>.4 && y<.86 && x<(y-.4)*.95);
	bool trunk = x<.055 && y>.72;
	if (!leaves && !trunk) discard;
	ALBEDO = trunk && !leaves ? vec3(.23,.16,.1) : mix(vec3(.1,.23,.12),vec3(.23,.38,.18),UV.x);
	ROUGHNESS = 1.0;
}
