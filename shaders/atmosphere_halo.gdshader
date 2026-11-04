shader_type spatial;
render_mode blend_add, depth_draw_never, cull_front, unshaded;

uniform vec4 atmosphere_color : source_color = vec4(0.18, 0.68, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 1.35;

void fragment() {
	float ndotv = clamp(dot(-NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - ndotv, 2.6) * smoothstep(0.0, 0.35, ndotv);
	ALBEDO = atmosphere_color.rgb * intensity;
	ALPHA = clamp(rim * 0.85, 0.0, 1.0);
}
