shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

varying vec3 v_dir;

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
	v_dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(v_dir);
	vec3 bg = vec3(0.008, 0.013, 0.024);

	// Мягкая галактическая туманность
	float neb1 = noise3(d * 2.4 + vec3(0.3, 1.1, 2.2));
	float neb2 = noise3(d * 4.8 - vec3(1.4, 0.7, 0.5));
	float band = exp(-abs(d.y * 2.2 - 0.2 * d.x) * 2.6);
	bg += vec3(0.03, 0.09, 0.19) * smoothstep(0.35, 0.85, neb1) * band;
	bg += vec3(0.10, 0.03, 0.15) * smoothstep(0.45, 0.90, neb2) * band * 0.75;

	// Круглые точечные звёзды (проверка расстояния до центра 3D-ячейки)
	vec3 scaled = d * 160.0;
	vec3 cell = floor(scaled);
	vec3 local_p = fract(scaled) - vec3(0.5);
	float h = hash3(cell);
	if (h > 0.965) {
		float dist_c = length(local_p);
		float spark = smoothstep(0.24, 0.02, dist_c) * ((h - 0.965) / 0.035);
		vec3 s_col = mix(vec3(0.65, 0.84, 1.0), vec3(1.0, 0.90, 0.72), fract(h * 137.0));
		bg += s_col * spark * 1.15;
	}

	ALBEDO = bg;
}
