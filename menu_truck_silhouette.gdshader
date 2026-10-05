shader_type canvas_item;
uniform vec4 truck_bounds = vec4(70.0, 180.0, 550.0, 400.0);

// A pointed straight stroke, widest at its origin inside the truck.
float speed_stroke(vec2 pixel, vec2 tip, vec2 base, float width) {
	vec2 axis = base - tip;
	float t = dot(pixel - tip, axis) / dot(axis, axis);
	float distance_to_axis = abs((pixel.x-tip.x)*axis.y - (pixel.y-tip.y)*axis.x) / length(axis);
	return step(0.0,t) * step(t,1.0) * (1.0-smoothstep(width*t, width*t+1.0, distance_to_axis));
}
void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	vec2 local = clamp((pixel-truck_bounds.xy)/truck_bounds.zw,vec2(0.0),vec2(1.0));
	// Pull the top left by 40 px, tapering to a thin edge at bottom/right.
	float pull = pow((1.0-local.x)*(1.0-local.y),0.65);
	vec2 offset = vec2(3.0+37.0*pull);
	float mask = texture(TEXTURE, UV+offset*TEXTURE_PIXEL_SIZE).a;
	vec2 origin = truck_bounds.xy;
	vec2 size = truck_bounds.zw;
	float lines = 0.0;
	lines = max(lines,speed_stroke(pixel,vec2(max(30.0,origin.x-40.0),max(30.0,origin.y-65.0)),origin+size*vec2(.45,.43),7.0));
	lines = max(lines,speed_stroke(pixel,origin+vec2(size.x*.15,-95.0),origin+size*vec2(.57,.42),5.0));
	lines = max(lines,speed_stroke(pixel,vec2(max(30.0,origin.x-30.0),origin.y+size.y*.18),origin+size*vec2(.38,.64),5.0));
	lines = max(lines,speed_stroke(pixel,origin+vec2(size.x*.37,-45.0),origin+size*vec2(.72,.33),3.0));
	COLOR = vec4(0.0,0.0,0.0,max(mask,lines));
}
