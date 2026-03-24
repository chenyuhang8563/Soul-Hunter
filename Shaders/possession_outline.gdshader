shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 outline_color : source_color = vec4(0.84, 0.34, 1.0, 0.9);
uniform vec4 glow_color : source_color = vec4(0.56, 0.16, 0.95, 0.8);
uniform float thickness = 1.0;
uniform float ripple_speed = 0.85;
uniform float ripple_scale = 10.0;
uniform float ripple_strength = 0.14;
uniform float edge_softness = 1.05;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE * thickness;

	float alpha_center = base.a;
	float alpha_neighbors = 0.0;
	alpha_neighbors = max(alpha_neighbors, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	alpha_neighbors = max(alpha_neighbors, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	alpha_neighbors = max(alpha_neighbors, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	alpha_neighbors = max(alpha_neighbors, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
	alpha_neighbors = max(alpha_neighbors, texture(TEXTURE, UV + vec2(px.x, px.y)).a);
	alpha_neighbors = max(alpha_neighbors, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
	alpha_neighbors = max(alpha_neighbors, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
	alpha_neighbors = max(alpha_neighbors, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);

	float border = clamp(alpha_neighbors - alpha_center, 0.0, 1.0);
	float wave = sin((UV.y + TIME * ripple_speed) * ripple_scale + sin((UV.x - TIME * 0.35) * ripple_scale * 0.4) * 1.4);
	wave = wave * 0.5 + 0.5;
	float flame = border * (0.92 + ripple_strength * (wave * 2.0 - 1.0));
	flame = smoothstep(0.05, 1.0, clamp(pow(flame, edge_softness), 0.0, 1.0));

	vec3 flame_color = mix(glow_color.rgb, outline_color.rgb, wave);
	vec3 rgb = mix(base.rgb, flame_color, flame * outline_color.a);
	float out_alpha = max(alpha_center, flame * outline_color.a);

	COLOR = vec4(rgb, out_alpha);
}
