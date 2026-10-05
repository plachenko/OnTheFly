shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D paint_texture : source_color;
uniform vec4 paint_color : source_color = vec4(1.0);
uniform bool has_texture = false;
uniform bool vertex_color = false;
uniform bool normal_pass = false;
void fragment() {
	vec4 paint = paint_color;
	if (has_texture) { paint *= texture(paint_texture,UV); }
	if (vertex_color) { paint *= COLOR; }
	vec3 world_normal = normalize(mat3(INV_VIEW_MATRIX)*NORMAL);
	ALBEDO = normal_pass ? world_normal*0.5+0.5 : paint.rgb;
	ALPHA = paint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
}
