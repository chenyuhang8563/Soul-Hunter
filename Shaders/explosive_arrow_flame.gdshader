shader_type canvas_item;

uniform bool flame_enabled = false;
uniform vec4 flame_inner : source_color = vec4(1.0, 0.82, 0.32, 1.0);
uniform vec4 flame_outer : source_color = vec4(1.0, 0.36, 0.05, 1.0);
uniform float flame_speed = 3.2;
uniform float flame_intensity = 1.1;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	if (!flame_enabled) {
		COLOR = base;
	} else {
		vec2 pixel = TEXTURE_PIXEL_SIZE;
		float neighbor_alpha = 0.0;
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + pixel).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - pixel).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);

		float edge_mask = clamp(neighbor_alpha - base.a, 0.0, 1.0);
		float flame_wave = sin((UV.y - TIME * flame_speed) * 24.0 + UV.x * 10.0) * 0.5 + 0.5;
		float flicker = 0.82 + 0.18 * sin(TIME * 19.0 + UV.x * 15.0);
		float flame_mask = edge_mask * flame_wave * flicker;
		float gradient = clamp(1.0 - UV.y, 0.0, 1.0);
		vec3 flame_color = mix(flame_outer.rgb, flame_inner.rgb, gradient);

		vec3 rgb = base.rgb + flame_color * flame_mask * flame_intensity;
		float alpha = max(base.a, flame_mask * 0.8);
		COLOR = vec4(rgb, alpha);
	}
}
