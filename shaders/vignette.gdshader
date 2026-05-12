shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float d = dot(uv, uv) * 2.0;
	float vignette = 1.0 - smoothstep(0.3, 1.0, d);
	COLOR = vec4(0.0, 0.0, 0.0, (1.0 - vignette) * strength);
}
