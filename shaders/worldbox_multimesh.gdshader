shader_type canvas_item;
render_mode blend_mix;

// Шейдер слоя сущностей в стиле WorldBox v0.51.2 (MultiMeshInstance2D) + 2D PBR Normal & Specular:
// INSTANCE_CUSTOM.x = фаза ветра (>0 для деревьев) или фаза шага (<0 для юнитов)
// INSTANCE_CUSTOM.y = интенсивность тряски и белой вспышки при рубке/ударе (0..1)
// INSTANCE_CUSTOM.z = фаза пружинящего появления из земли scale.y (0..1)
// INSTANCE_CUSTOM.w = индекс спрайта в горизонтальном пиксель-арт атласе (0..atlas_cols-1)

uniform float atlas_cols : hint_range(1.0, 32.0, 1.0) = 8.0;
uniform float sway_strength : hint_range(0.0, 6.0) = 2.0;
uniform bool use_pbr_maps = false;
uniform sampler2D normal_atlas : filter_nearest;
uniform sampler2D spec_atlas : filter_nearest;

varying vec4 v_custom;
varying vec4 v_color;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_color = COLOR;
	vec2 raw_uv = UV;
	float col_idx = floor(clamp(INSTANCE_CUSTOM.w, 0.0, atlas_cols - 1.0) + 0.5);
	UV = vec2((clamp(raw_uv.x, 0.004, 0.996) + col_idx) / max(1.0, atlas_cols), clamp(raw_uv.y, 0.004, 0.996));

	// 1. Пружинящее появление построек и деревьев из земли (Elastic Scale.Y + Squash & Stretch)
	float t = clamp(INSTANCE_CUSTOM.z, 0.05, 1.0);
	if (t < 0.995) {
		float spring_y = t + sin(t * 9.424778) * exp(-t * 3.2) * 0.36;
		float spring_x = 1.0 + (1.0 - spring_y) * 0.25;
		// Нижний край квада (raw_uv.y = 1.0, VERTEX.y > 0) остаётся прибитым к земле
		VERTEX.x *= spring_x;
		float base_y = 10.0;
		VERTEX.y = base_y + (VERTEX.y - base_y) * max(0.08, spring_y);
	}

	// 2. Покачивание крон деревьев на ветру или подпрыгивание человечков при ходьбе
	if (INSTANCE_CUSTOM.x > 0.001) {
		float crown_weight = clamp(1.0 - raw_uv.y, 0.0, 1.0);
		VERTEX.x += sin(TIME * 2.6 + INSTANCE_CUSTOM.x) * sway_strength * crown_weight;
	} else if (INSTANCE_CUSTOM.x < -0.001) {
		float walk_phase = -INSTANCE_CUSTOM.x;
		VERTEX.y -= abs(sin(walk_phase)) * 2.4;
	}

	// 3. Тряска при рубке дерева / добыче руды / уроне зданию
	if (INSTANCE_CUSTOM.y > 0.005) {
		float shake_w = clamp(1.15 - raw_uv.y * 0.6, 0.3, 1.0);
		VERTEX.x += sin(TIME * 52.0 + INSTANCE_CUSTOM.x * 5.0) * 3.4 * INSTANCE_CUSTOM.y * shake_w;
	}
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.05) {
		discard;
	}
	vec3 rgb = tex.rgb * v_color.rgb;

	if (use_pbr_maps) {
		vec3 n_map = texture(normal_atlas, UV).rgb;
		float spec_mask = texture(spec_atlas, UV).r;
		NORMAL_MAP = n_map;
		NORMAL_MAP_DEPTH = 1.35;

		// Мягкий орбитальный солнечный блик по 2D карте нормалей и карте металла/спекуляра
		vec3 N = normalize(vec3(n_map.r * 2.0 - 1.0, -(n_map.g * 2.0 - 1.0), max(0.15, n_map.b * 2.0 - 1.0)));
		float sun_ang = TIME * 0.45;
		vec3 L_sun = normalize(vec3(cos(sun_ang) * 0.55, -0.45, 0.70));
		vec3 V = vec3(0.0, 0.0, 1.0);
		vec3 H = normalize(L_sun + V);
		float ndotl = clamp(dot(N, L_sun), 0.0, 1.0);
		float spec_sun = pow(clamp(dot(N, H), 0.0, 1.0), 14.0) * spec_mask;
		rgb = rgb * (0.90 + 0.22 * ndotl) + vec3(1.0, 0.96, 0.86) * spec_sun * 0.38;
	}

	// Белая вспышка удара (Hit Flash как в WorldBox)
	if (v_custom.y > 0.01) {
		rgb = mix(rgb, vec3(1.0, 0.98, 0.92), clamp(v_custom.y * 0.65, 0.0, 0.82));
	}
	COLOR = vec4(rgb, tex.a * v_color.a);
}

void light() {
	float ndotl = max(0.0, dot(NORMAL, LIGHT_DIRECTION));
	float spec_mask = use_pbr_maps ? texture(spec_atlas, UV).r : 0.25;
	vec3 V = vec3(0.0, 0.0, 1.0);
	vec3 H = normalize(LIGHT_DIRECTION + V);
	float spec = pow(max(0.0, dot(NORMAL, H)), 18.0) * spec_mask * 1.15;
	vec3 lit = (COLOR.rgb * ndotl * 0.42 + LIGHT_COLOR.rgb * spec) * LIGHT_COLOR.rgb * LIGHT_ENERGY;
	LIGHT = vec4(lit, LIGHT_COLOR.a * COLOR.a);
}
