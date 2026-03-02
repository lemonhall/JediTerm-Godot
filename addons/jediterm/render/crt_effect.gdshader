shader_type canvas_item;

// CRT-ish post process for 2D UI.
// Recommended usage: apply this material to a SubViewportContainer that displays the terminal SubViewport.

uniform float curvature : hint_range(0.0, 0.4) = 0.09;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.28;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.38;
uniform float noise_strength : hint_range(0.0, 0.2) = 0.03;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.22;

uniform float brightness : hint_range(0.0, 3.0) = 1.10;
uniform float contrast : hint_range(0.0, 3.0) = 1.10;
uniform float gamma : hint_range(0.5, 3.0) = 1.00;

uniform bool monochrome = true;
uniform vec3 phosphor_tint = vec3(0.18, 1.0, 0.18);

uniform float flicker_strength : hint_range(0.0, 0.2) = 0.03;

float _hash(vec2 p) {
	// Small, cheap hash (deterministic).
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 _warp_uv(vec2 uv) {
	vec2 c = uv * 2.0 - 1.0;
	float r2 = dot(c, c);
	c *= (1.0 + curvature * r2);
	return c * 0.5 + 0.5;
}

vec3 _apply_monochrome(vec3 rgb) {
	if (!monochrome) {
		return rgb;
	}
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	return luma * phosphor_tint;
}

vec3 _tex_rgb_clamped(vec2 uv) {
	vec2 cuv = clamp(uv, vec2(0.0), vec2(1.0));
	return texture(TEXTURE, cuv).rgb;
}

void fragment() {
	vec2 uv = _warp_uv(UV);
	bool oob = (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0);
	vec3 col = vec3(0.0);
	if (!oob) {
		vec4 src = texture(TEXTURE, uv);
		col = _apply_monochrome(src.rgb);

		// Glow: tiny blur (4 taps) mixed in.
		vec2 px = TEXTURE_PIXEL_SIZE;
		vec3 blur = vec3(0.0);
		blur += _tex_rgb_clamped(uv + vec2(px.x, 0.0));
		blur += _tex_rgb_clamped(uv + vec2(-px.x, 0.0));
		blur += _tex_rgb_clamped(uv + vec2(0.0, px.y));
		blur += _tex_rgb_clamped(uv + vec2(0.0, -px.y));
		blur *= 0.25;
		blur = _apply_monochrome(blur);

		// Avoid bright "bands" near the edges from glow sampling/clamping.
		float edge_min = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
		float edge_fade = smoothstep(0.0, 0.02, edge_min);
		col = mix(col, blur, glow_strength * edge_fade);

		// Scanlines (based on source texture vertical resolution).
		float tex_h = 1.0 / max(px.y, 1e-6);
		float scan = 0.5 + 0.5 * sin((uv.y * tex_h) * 3.14159265);
		float scan_mul = mix(1.0 - scanline_strength, 1.0, scan);
		col *= scan_mul;

		// Vignette (use warped coords to feel more "tube-like").
		vec2 c = (uv * 2.0 - 1.0);
		float d = length(c);
		float vig = smoothstep(1.2, 0.25, d);
		col *= mix(vec3(1.0), vec3(vig), vignette_strength);

		// Flicker.
		float flicker = 1.0 + (sin(TIME * 50.0) * flicker_strength);
		col *= flicker;

		// Noise.
		vec2 tex_sz = vec2(1.0) / max(TEXTURE_PIXEL_SIZE, vec2(1e-6));
		float n = _hash(uv * tex_sz + vec2(TIME * 120.0, TIME * 37.0));
		col += (n - 0.5) * noise_strength;

		// Contrast/brightness/gamma.
		col = (col - 0.5) * contrast + 0.5;
		col *= brightness;
		col = pow(max(col, vec3(0.0)), vec3(1.0 / max(gamma, 1e-6)));
	}

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
