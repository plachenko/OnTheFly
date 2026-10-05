shader_type canvas_item;
render_mode unshaded;

uniform vec2 panel_size = vec2(1280.0, 800.0);
uniform float pattern_entry = 0.0;
uniform float dark_entry = 0.0;
// Highway travel shows only the two animated edge bands over the live fog.
uniform bool patterns_only = false;
uniform float run_started = 0.0;
uniform float smoothing_at = -1.0;
uniform float smoothing_x = 0.12;
uniform float finish_travel_seconds = 1.5;
uniform float steering_offset = 0.0;
uniform float steering_heading = 0.0;
uniform bool controlled_tracks = false;

float route_y(float x) {
	float growth = smoothstep(0.12,0.8,x);
	return 0.74 + growth*(0.035*sin(x*23.0)+0.018*sin(x*47.0));
}
float thin_line(float distance, float width) { return 1.0-smoothstep(width,width+0.0015,distance); }


void fragment() {
	vec2 p = UV * panel_size;
	float w = panel_size.x;
	float h = panel_size.y;
	vec3 cream = vec3(1.0, 0.94902, 0.84314);
	vec3 dark = vec3(0.07843, 0.08627, 0.11373);
	vec3 skyline = vec3(0.16078, 0.16863, 0.19608);
	vec3 color = cream;
	// One repeating stripe column and two alternating checker columns.
	// TIME is advanced by the renderer; no script redraw or frame timer is needed.
	float tile = max(24.0, h * 0.045);
	float stripe_height = tile * 2.0;
	float stripe_y = -stripe_height * (1.0 - pattern_entry);
	if (p.y >= stripe_y && p.y < stripe_y + stripe_height) {
		float column = fract((p.x + p.y - stripe_y + TIME * 90.0) / 96.0);
		if (column < 0.5) color = vec3(0.86667, 0.26667, 0.20784);
	}
	float offset = h * 0.5 * (1.0 - dark_entry);
	if (p.y >= h * 0.5 + offset) color = dark;
	if (!patterns_only && UV.y > 0.57 && UV.y < 0.91) {
		float elapsed = mod(TIME-run_started+3600.0,3600.0);
		float x = 0.12+0.70*(1.0-exp(-elapsed/6.0));
		float spin = -1.0;
		if (smoothing_at >= 0.0) {
			float travel = max(0.0,elapsed-smoothing_at);
			x = mix(smoothing_x,0.88,clamp(travel/finish_travel_seconds,0.0,1.0));
			spin = travel-finish_travel_seconds;
		}
		float y = route_y(x)+steering_offset;
		float road = route_y(UV.x);
		float tracks = thin_line(abs(abs(UV.y-road)-0.012),0.002);
		tracks *= step(0.12,UV.x)*step(UV.x,x)*(controlled_tracks ? 0.0 : 1.0);
		color = mix(color,vec3(0.24,0.19,0.16),tracks);
		float heading = atan((route_y(x+0.001)-route_y(x-0.001))*h,0.002*w)+steering_heading;
		if (spin >= 0.0) {
			float theta = spin*4.5;
			vec2 hub = vec2(0.88*w,route_y(0.88)*h-30.0);
			vec2 point = p-hub;
			float radial = length(point);
			float tire_rings = max(thin_line(abs(radial-23.0)/h,0.002),thin_line(abs(radial-37.0)/h,0.002));
			float arc = mod(atan(point.y,point.x)+1.570796+6.283185,6.283185);
			tire_rings *= step(arc,min(theta,6.283185));
			color = mix(color,vec3(0.24,0.19,0.16),tire_rings);
			x = (hub.x+sin(theta)*30.0)/w;
			y = (hub.y+cos(theta)*30.0)/h+steering_offset;
			heading = -theta+steering_heading;
			// Flat expanding puffs: analytic vector silhouettes, no particle nodes.
			for (int i=0;i<7;i++) {
				float age = fract(spin*0.65+float(i)/7.0);
				float birth_angle = (spin-age/0.65)*4.5;
				vec2 puff = hub+vec2(sin(birth_angle),cos(birth_angle))*(30.0+age*25.0)+vec2(age*15.0,-age*16.0);
				float cloud = 1.0-smoothstep(8.0+age*10.0,10.0+age*10.0,length(p-puff));
				color = mix(color,vec3(0.68,0.67,0.62),cloud*(1.0-age)*0.55*step(0.05,spin));
			}
		}
		vec2 local = p-vec2(x*w,y*h);
		local = mat2(vec2(cos(heading),-sin(heading)),vec2(sin(heading),cos(heading)))*local;
		bool body = abs(local.x)<18.0 && abs(local.y)<10.0;
		bool wheels = abs(abs(local.x)-11.0)<3.0 && abs(abs(local.y)-11.0)<3.0;
		if (wheels) color = vec3(0.12,0.12,0.14);
		if (body) color = vec3(1.0,0.89412,0.62745);
		if (body && local.x>9.0 && abs(local.y)<8.0) color = vec3(0.65,0.45,0.30);
	}
	float checker_y = h - tile * 2.0 * pattern_entry;
	if (p.y >= checker_y && p.y < checker_y + 2.0 * tile) {
		float column = floor((p.x - TIME * 90.0) / tile);
		float row = floor((p.y - checker_y) / tile);
		color = mod(column + row, 2.0) < 1.0 ? skyline : cream;
	}
	float alpha = 1.0;
	if (patterns_only) {
		bool stripes = p.y >= stripe_y && p.y < stripe_y + stripe_height;
		bool checkers = p.y >= checker_y && p.y < checker_y + 2.0 * tile;
		alpha = (stripes || checkers) ? 1.0 : 0.0;
	}
	COLOR = vec4(color, alpha) * COLOR;
}
