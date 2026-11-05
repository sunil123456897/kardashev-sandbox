shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 corona_color : source_color = vec4(1.0, 0.65, 0.15, 1.0);
uniform vec4 absorption_color : source_color = vec4(0.2, 0.85, 1.0, 1.0);
uniform vec4 core_glow_color : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform float pulse_speed : hint_range(0.1, 10.0) = 2.4;
uniform float absorption_intensity : hint_range(0.0, 3.0) = 1.0;
uniform float stage_progress : hint_range(0.0, 1.0) = 0.5;
uniform int active_segments : hint_range(0, 60) = 12;
uniform float inner_radius : hint_range(0.0, 1.0) = 0.22;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.46;
uniform float lattice_frequency : hint_range(4.0, 64.0) = 24.0;
uniform float pixel_grid : hint_range(32.0, 320.0) = 160.0;

void fragment() {
	vec2 q_uv = (floor(UV * pixel_grid) + vec2(0.5)) / pixel_grid;
	vec2 pos = q_uv - vec2(0.5);
	float dist = length(pos);
	float angle = atan(pos.y, pos.x);

	// 1. Radial boundary mask (zero out before 0.48 so 640x640 ColorRect never clips square edges)
	float edge_guard = 1.0 - smoothstep(0.44, 0.48, dist);
	float radial = smoothstep(outer_radius, inner_radius, dist) * edge_guard;
	float core_fade = smoothstep(0.08, inner_radius * 0.9, dist);

	// 2. Harmonic corona turbulence
	float t = TIME * pulse_speed;
	float wave1 = sin(angle * 7.0 + t) * cos(dist * 28.0 - t * 1.5);
	float wave2 = sin(angle * 13.0 - t * 0.8) * 0.5;
	float corona_flux = clamp(0.5 + 0.35 * (wave1 + wave2), 0.0, 1.0);

	// 3. Dyson Megastructure Segment Quantization & Inward Energy Conduits
	float seg_count = max(4.0, float(active_segments));
	float seg_uv = (angle + 3.14159265) / (2.0 * 3.14159265) * seg_count;
	float seg_grid = abs(fract(seg_uv) - 0.5) * 2.0;
	float seg_lines = smoothstep(0.85, 0.98, seg_grid);

	// Inward energy absorption waves (moving from outer radius toward star center)
	float inward_flow = sin(dist * lattice_frequency + t * 3.2) * 0.5 + 0.5;
	float absorption_grid = seg_lines * inward_flow * absorption_intensity;

	// 4. Color blending: corona base + absorbed quantum flux
	vec3 col = corona_color.rgb * (0.8 + 0.4 * corona_flux);
	vec3 absorb_col = mix(absorption_color.rgb, core_glow_color.rgb, inward_flow);
	col = mix(col, absorb_col, clamp(stage_progress * 0.65 + absorption_grid * 0.5, 0.0, 1.0));

	// Inner core glow enhancement
	float core_intensity = smoothstep(inner_radius * 1.2, 0.0, dist);
	col += core_glow_color.rgb * core_intensity * 0.45;

	float alpha = clamp(radial * core_fade * (0.35 + 0.35 * corona_flux + absorption_grid * 0.4), 0.0, 1.0);
	COLOR = vec4(col * 1.4, alpha);
}
