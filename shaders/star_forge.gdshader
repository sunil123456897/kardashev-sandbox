shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 core_color : source_color = vec4(1.0, 0.92, 0.65, 1.0);
uniform vec4 corona_color : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform float instability : hint_range(0.0, 1.0) = 0.15;

varying vec3 v_norm;

float hash3(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(
			mix(hash3(i + vec3(0, 0, 0)), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x),
			f.y
		),
		mix(
			mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x),
			f.y
		),
		f.z
	);
}

void vertex() {
	v_norm = normalize(VERTEX);
	float flare = noise3(v_norm * 4.5 + vec3(TIME * 0.45)) * (0.08 + instability * 0.22);
	VERTEX += v_norm * flare;
}

void fragment() {
	vec3 p = v_norm * 6.5 + vec3(TIME * 0.32, -TIME * 0.24, TIME * 0.18);
	float gran = noise3(p) * 0.6 + noise3(p * 2.3) * 0.4;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.8);
	vec3 col = mix(corona_color.rgb, core_color.rgb, smoothstep(0.25, 0.82, gran));
	col += corona_color.rgb * fresnel * (1.6 + instability * 1.4);
	ALBEDO = col * 2.2;
}
