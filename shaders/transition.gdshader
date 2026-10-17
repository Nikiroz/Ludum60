shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float density = 36.0;
uniform float boundary_size : hint_range(0.01, 1.0) = 0.6;
uniform float antialiasing_intensity : hint_range(0.1, 8.0) = 2.0;

float modulus(float a, float b) {
	return a - b * floor(a / b);
}

vec2 axial_round(vec2 fractional_axial) {
	float fractional_q = fractional_axial.x;
	float fractional_r = fractional_axial.y;
	float fractional_s = -fractional_q - fractional_r;

	float whole_q = round(fractional_q);
	float whole_r = round(fractional_r);
	float whole_s = round(fractional_s);

	float q_diff = abs(fractional_q - whole_q);
	float r_diff = abs(fractional_r - whole_r);
	float s_diff = abs(fractional_s - whole_s);

	float q = whole_q;
	float r = whole_r;

	if (q_diff > r_diff && q_diff > s_diff) {
		q = -whole_r - whole_s;
	} else if (r_diff > s_diff) {
		r = -whole_q - whole_s;
	}

	return vec2(q, r);
}

vec2 axial_to_cartesian(vec2 axial, float grid_scale) {
	float x = (sqrt(3.0) * axial.x + sqrt(3.0) * 0.5 * axial.y) / grid_scale;
	float y = (1.5 * axial.y) / grid_scale;
	return vec2(x, y);
}

vec2 cartesian_to_fractional_axial(vec2 cartesian, float grid_scale) {
	float q = ((cartesian.x / sqrt(3.0)) - (cartesian.y / 3.0)) * grid_scale;
	float r = (2.0 * cartesian.y / 3.0) * grid_scale;
	return vec2(q, r);
}

vec2 cartesian_to_whole_axial(vec2 cartesian, float grid_scale) {
	return axial_round(cartesian_to_fractional_axial(cartesian, grid_scale));
}

void fragment() {
	vec2 uv = UV;

	vec2 centered_uv = uv - vec2(0.5);
	centered_uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	centered_uv += vec2(0.5);

	vec2 cell_center_axial = cartesian_to_whole_axial(centered_uv, density);
	vec2 cell_center = axial_to_cartesian(cell_center_axial, density);

	float cell_radius = 1.0 / density;
	float dist_from_cell_center = distance(cell_center, centered_uv);

	float transition_progress = clamp(progress, 0.0, 1.0);
	float reveal = step(0.5, transition_progress);
	float sweep_progress = transition_progress * 2.0 - reveal;
	float screen_half_width = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x * 0.5;
	float boundary_half_width = max(boundary_size * 0.5, cell_radius);
	// Keep the entire transition band and edge cells outside the visible UV range.
	float sweep_margin = boundary_half_width + cell_radius * 2.0;
	float sweep_start = 0.5 + screen_half_width + sweep_margin;
	float sweep_end = 0.5 - screen_half_width - sweep_margin;
	float sweep_x = mix(sweep_start, sweep_end, sweep_progress);

	float cell_progress = 1.0 - smoothstep(
		cell_center.x - boundary_half_width,
		cell_center.x + boundary_half_width,
		sweep_x
	);
	float pixel_scale = 1.0 / SCREEN_PIXEL_SIZE.x;
	float antialiasing_width = antialiasing_intensity / pixel_scale;
	float distance_threshold = mix(-cell_radius, cell_radius * 1.5 + antialiasing_width, cell_progress);

	float proximity = distance_threshold - dist_from_cell_center;
	float mask = smoothstep(0.0, antialiasing_width, proximity);

	// Both the black cover and the transparent reveal sweep from right to left.
	float opacity = mix(mask, 1.0 - mask, reveal);
	COLOR = vec4(0.0, 0.0, 0.0, opacity);
}
