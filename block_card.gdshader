shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D atlas : source_color, filter_linear;
uniform float opacity = 1.0;
uniform vec3 scene_tint = vec3(1.0);
varying flat vec2 frame;
void vertex() {
    vec3 center = MODEL_MATRIX[3].xyz;
    vec3 viewer = INV_VIEW_MATRIX[3].xyz - center;
    float heading = mod(atan(viewer.x, viewer.z) * 8.0 / 6.283185 + 8.0, 8.0);
    float elevation = clamp(atan(viewer.y, length(viewer.xz)) / 0.436332, 0.0, 2.0);
    frame = vec2(heading, elevation);
    vec3 world = center + INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y;
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
vec4 sample_frame(vec2 cell, vec2 local_uv) {
    vec4 texel = texture(atlas, (cell + local_uv) / vec2(8.0, 3.0));
    return vec4(texel.rgb * texel.a, texel.a);
}
void fragment() {
    vec2 local_uv = clamp(UV, vec2(0.5 / 192.0), vec2(1.0 - 0.5 / 192.0));
    vec2 base = floor(frame);
    vec2 next = vec2(mod(base.x + 1.0, 8.0), min(base.y + 1.0, 2.0));
    vec2 blend = fract(frame);
    vec4 lower = mix(sample_frame(base, local_uv), sample_frame(vec2(next.x, base.y), local_uv), blend.x);
    vec4 upper = mix(sample_frame(vec2(base.x, next.y), local_uv), sample_frame(next, local_uv), blend.x);
    vec4 texel = mix(lower, upper, blend.y);
    ALBEDO = texel.rgb / max(texel.a, 0.0001) * scene_tint;
    ALPHA = texel.a * opacity;
}
