shader_type canvas_item;
render_mode blend_mix;

// Шейдер слоя сущностей в стиле WorldBox v0.51.2 (MultiMeshInstance2D):
// INSTANCE_CUSTOM.x = фаза ветра (>0 для деревьев) или фаза шага (<0 для юнитов)
// INSTANCE_CUSTOM.y = интенсивность тряски и белой вспышки при рубке/ударе (0..1)
// INSTANCE_CUSTOM.z = фаза пружинящего появления из земли scale.y (0..1)
// INSTANCE_CUSTOM.w = индекс спрайта в горизонтальном пиксель-арт атласе (0..atlas_cols-1)

uniform float atlas_cols : hint_range(1.0, 32.0, 1.0) = 8.0;
uniform float sway_strength : hint_range(0.0, 6.0) = 2.0;

varying vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;

	// 1. Пружинящее появление построек и деревьев из земли (Elastic Scale.Y + Squash & Stretch)
	float t = clamp(INSTANCE_CUSTOM.z, 0.05, 1.0);
	if (t < 0.995) {
		float spring_y = t + sin(t * 9.424778) * exp(-t * 3.2) * 0.36;
		float spring_x = 1.0 + (1.0 - spring_y) * 0.25;
		// Нижний край квада (UV.y = 1.0, VERTEX.y > 0) остаётся прибитым к земле
		VERTEX.x *= spring_x;
		float base_y = 10.0;
		VERTEX.y = base_y + (VERTEX.y - base_y) * max(0.08, spring_y);
	}

	// 2. Покачивание крон деревьев на ветру или подпрыгивание человечков при ходьбе
	if (INSTANCE_CUSTOM.x > 0.001) {
		float crown_weight = clamp(1.0 - UV.y, 0.0, 1.0);
		VERTEX.x += sin(TIME * 2.6 + INSTANCE_CUSTOM.x) * sway_strength * crown_weight;
	} else if (INSTANCE_CUSTOM.x < -0.001) {
		float walk_phase = -INSTANCE_CUSTOM.x;
		VERTEX.y -= abs(sin(walk_phase)) * 2.4;
	}

	// 3. Тряска при рубке дерева / добыче руды / уроне зданию
	if (INSTANCE_CUSTOM.y > 0.005) {
		float shake_w = clamp(1.15 - UV.y * 0.6, 0.3, 1.0);
		VERTEX.x += sin(TIME * 52.0 + INSTANCE_CUSTOM.x * 5.0) * 3.4 * INSTANCE_CUSTOM.y * shake_w;
	}
}

void fragment() {
	float col_idx = floor(clamp(v_custom.w, 0.0, atlas_cols - 1.0) + 0.5);
	vec2 atlas_uv = vec2((UV.x + col_idx) / max(1.0, atlas_cols), UV.y);
	vec4 tex = texture(TEXTURE, atlas_uv);
	if (tex.a < 0.05) {
		discard;
	}
	vec3 rgb = tex.rgb * COLOR.rgb;
	// Белая вспышка удара (Hit Flash как в WorldBox)
	if (v_custom.y > 0.01) {
		rgb = mix(rgb, vec3(1.0, 0.98, 0.92), clamp(v_custom.y * 0.65, 0.0, 0.82));
	}
	COLOR = vec4(rgb, tex.a * COLOR.a);
}
