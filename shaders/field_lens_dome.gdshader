shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

uniform vec4 lens_color : source_color = vec4(0.2, 0.95, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.5, 10.0) = 3.2;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	float ndotv = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndotv, 3.2);
	float rings = sin(length(v_local) * 16.0 - TIME * pulse_speed) * 0.5 + 0.5;
	float wave = smoothstep(0.84, 0.99, rings);
	float alpha = clamp(rim * 0.36 + wave * 0.10, 0.01, 0.42);
	ALBEDO = lens_color.rgb * (0.85 + wave * 0.45);
	ALPHA = alpha;
}
