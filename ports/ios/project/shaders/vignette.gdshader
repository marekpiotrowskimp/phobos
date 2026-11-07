shader_type canvas_item;

uniform float amount = 0.18;
uniform float danger = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = distance(uv, vec2(0.5));
	float v = smoothstep(0.32, 0.8, d);
	float pulse = 0.75 + 0.25 * sin(TIME * 4.0);
	vec3 col = vec3(0.6, 0.05, 0.08) * danger * pulse;
	COLOR = vec4(col, amount * (1.0 + danger * 0.8) * v);
}
