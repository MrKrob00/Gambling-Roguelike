shader_type canvas_item;
// Darkens the edges of the screen and can flash a colour on top: red when the house wins, gold when you do.

uniform float darkness : hint_range(0.0, 1.0) = 0.55;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(0.8, 0.05, 0.05, 1.0);

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float v = smoothstep(0.25, 0.85, length(uv * vec2(1.0, 1.15)));
	vec3 col = mix(vec3(0.0), flash_color.rgb, flash * 0.55);
	COLOR = vec4(col, clamp(v * darkness + flash * 0.25 * v, 0.0, 1.0));
}
