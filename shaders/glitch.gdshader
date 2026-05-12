shader_type canvas_item;

uniform float time_offset : hint_range(0.0, 100.0) = 0.0;

void fragment() {
	float t = TIME + time_offset;
	float block = floor(UV.y * 20.0 + t * 8.0);
	float noise = fract(sin(block * 127.1 + t) * 43758.5453);
	float shift = (noise - 0.5) * 0.08 * step(0.85, fract(t * 3.0 + block * 0.1));

	vec4 col = texture(TEXTURE, UV + vec2(shift, 0.0));
	float r = texture(TEXTURE, UV + vec2(shift + 0.015, 0.0)).r;
	float b = texture(TEXTURE, UV + vec2(shift - 0.015, 0.0)).b;
	COLOR = vec4(r, col.g, b, col.a) * COLOR;
}
