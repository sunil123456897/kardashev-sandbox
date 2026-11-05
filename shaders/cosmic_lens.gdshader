shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec2 center = vec2(0.5, 0.5);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float radius : hint_range(0.0, 1.0) = 0.4;
uniform float thickness : hint_range(0.01, 0.3) = 0.018;
uniform float force : hint_range(0.0, 0.2) = 0.028;
uniform vec4 shock_color : source_color = vec4(0.25, 0.90, 1.0, 1.0);
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.014;
uniform float aspect_ratio = 1.7777778;

void fragment() {
	if (progress <= 0.001 || progress >= 0.999) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		// Correct aspect ratio for circular wavefront on non-square viewports
		vec2 diff = SCREEN_UV - center;
		diff.x *= aspect_ratio;
		float dist = length(diff);

		float current_radius = radius * progress;
		float ring_dist = abs(dist - current_radius);
		float mask = smoothstep(thickness, 0.0, ring_dist);

		// Quadratic decay as the wave dissipates into deep space
		float decay = (1.0 - progress) * (1.0 - progress);
		mask *= decay;

		vec2 dir = normalize(SCREEN_UV - center);
		vec2 offset = dir * (mask * force);

		// Chromatic dispersion (spectral separation on the shockwave refraction crest)
		float r = texture(screen_texture, SCREEN_UV - offset * (1.0 + chromatic_aberration)).r;
		float g = texture(screen_texture, SCREEN_UV - offset).g;
		float b = texture(screen_texture, SCREEN_UV - offset * (1.0 - chromatic_aberration)).b;
		vec3 refracted = vec3(r, g, b);

		// Additive energy crest illumination
		vec3 rim_glow = shock_color.rgb * mask * 0.32;
		COLOR = vec4(refracted + rim_glow, 1.0);
	}
}
