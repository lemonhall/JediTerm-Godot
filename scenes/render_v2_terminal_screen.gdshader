shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D term_tex;

void fragment() {
	vec4 c = texture(term_tex, UV);
	ALBEDO = c.rgb;
	ALPHA = 1.0;
}

