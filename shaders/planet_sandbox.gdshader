shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D biome_map_tex : filter_linear, repeat_enable;
uniform sampler2D emissive_map_tex : filter_linear, repeat_enable;

uniform vec3 cursor_dir = vec3(0.0, 0.0, 1.0);
uniform float cursor_radius = 0.22;
uniform vec4 cursor_color : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform float cursor_active = 0.0;

uniform vec3 star_world_pos = vec3(-65.0, 8.0, -35.0);
uniform vec3 star_light_color : source_color = vec3(1.0, 0.85, 0.65);

varying vec3 v_local_norm;
varying vec3 v_world_pos;

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

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3(p);
		p *= 2.04;
		a *= 0.5;
	}
	return v;
}

vec2 dir_to_equirect_uv(vec3 d) {
	vec3 n = normalize(d);
	float u = atan(n.z, n.x) / (2.0 * PI) + 0.5;
	float v = asin(clamp(n.y, -1.0, 1.0)) / PI + 0.5;
	return vec2(u, v);
}

vec3 warp_sphere_dir(vec3 n) {
	vec3 w = vec3(
		fbm3(n * 7.5 + vec3(1.7, 3.2, 5.1)) - 0.5,
		fbm3(n * 7.5 + vec3(8.3, 2.8, 1.4)) - 0.5,
		fbm3(n * 7.5 + vec3(4.1, 9.6, 6.2)) - 0.5
	);
	return normalize(n + w * 0.16);
}

void vertex() {
	v_local_norm = normalize(VERTEX);
	vec3 w_dir = warp_sphere_dir(v_local_norm);
	vec2 uv_eq = dir_to_equirect_uv(w_dir);
	vec4 em_data = texture(emissive_map_tex, uv_eq);
	float elev = (em_data.a - 0.45) * 0.45;
	float micro_detail = (fbm3(v_local_norm * 16.0) - 0.5) * 0.14;
	float final_disp = max(-0.06, elev + micro_detail);
	VERTEX += v_local_norm * final_disp;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n_dir = normalize(v_local_norm);
	vec3 w_dir = warp_sphere_dir(n_dir);
	vec2 uv_eq = dir_to_equirect_uv(w_dir);

	vec4 base_sample = texture(biome_map_tex, uv_eq);
	vec4 em_sample = texture(emissive_map_tex, uv_eq);

	float detail = fbm3(n_dir * 26.0);
	float ridge = abs(fbm3(n_dir * 48.0) - 0.5) * 2.0;

	vec3 col = base_sample.rgb * (0.76 + 0.42 * detail);

	// Береговая кромка и террасы рельефа
	float elev_norm = clamp(em_sample.a + (detail - 0.5) * 0.14, 0.0, 1.0);
	if (elev_norm < 0.43) {
		float wave = sin(detail * 20.0 + TIME * 1.6) * 0.5 + 0.5;
		col += vec3(0.02, 0.08, 0.12) * wave;
		ROUGHNESS = 0.25;
		METALLIC = 0.30;
		SPECULAR = 0.60;
	} else {
		col = mix(col, col * 1.32, smoothstep(0.52, 0.85, elev_norm) * ridge);
		ROUGHNESS = 0.82;
		METALLIC = 0.15;
		SPECULAR = 0.20;
	}

	// Деликатная геодезическая техно-паутина и умеренное свечение биомов/городов (без пересвета!)
	float hex_line = smoothstep(0.92, 0.99, abs(sin(n_dir.x * 64.0) * cos(n_dir.y * 64.0) * cos(n_dir.z * 64.0)));
	float pulse = 0.82 + 0.18 * sin(TIME * 2.4 + detail * 6.0);
	vec3 emissive = em_sample.rgb * (0.28 + 0.65 * hex_line) * pulse;

	// Тонкое кольцо прицела Божественной Кисти на поверхности глобуса
	if (cursor_active > 0.5) {
		float ang = acos(clamp(dot(n_dir, normalize(cursor_dir)), -1.0, 1.0));
		float ring_edge = smoothstep(0.016, 0.0, abs(ang - cursor_radius));
		float inner_fill = smoothstep(cursor_radius, 0.0, ang) * 0.08;
		emissive += cursor_color.rgb * (ring_edge * 1.45 + inner_fill);
	}

	ALBEDO = col;
	EMISSION = emissive;
}
