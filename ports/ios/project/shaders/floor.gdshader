shader_type spatial;

uniform sampler2D floor_texture : source_color, filter_linear_mipmap;

void fragment() {
	vec3 floor_color = texture(floor_texture, UV).rgb;
	ALBEDO = floor_color;
	EMISSION = floor_color * 0.04;
	METALLIC = 0.55;
	ROUGHNESS = 0.82;
}
