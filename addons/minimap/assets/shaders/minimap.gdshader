// The minimap's lens: the SubViewport's picture masked to a circle with a soft edge and a ring round it.
// Ported from the Breath of the Wild project's HUD (shaders/minimap.gdshader), where the minimap began.
shader_type canvas_item;

// Radius of the circle, as a share of the rect's width.
uniform float radius : hint_range(0.0, 0.5) = 0.5;
uniform float softness : hint_range(0.0, 0.1) = 0.02;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float border_width : hint_range(0.0, 0.05) = 0.01;

void fragment() {
	float distance = length(UV - vec2(0.5));
	// Main circular mask
	float alpha = 1.0 - smoothstep(radius - softness, radius, distance);
	// The ring just inside the edge
	float border_alpha = 1.0 - smoothstep(radius - border_width - softness, radius - border_width, distance);
	border_alpha *= smoothstep(radius - softness, radius, distance);
	vec4 color = texture(TEXTURE, UV);
	color.a *= alpha;
	COLOR = mix(color, border_color, border_alpha * border_color.a);
}
