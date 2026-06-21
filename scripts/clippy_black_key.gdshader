shader_type canvas_item;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (color.r < 0.15 && color.g < 0.15 && color.b < 0.15) {
		discard;
	}
	COLOR = color;
}
