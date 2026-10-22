shader_type particles;
render_mode disable_force, disable_velocity;

// Use with GPUParticles2D Local Coords enabled.
uniform vec2 swarm_radius = vec2(100.0, 50.0);
// Relative concentration: 2.0 doubles density by halving the flight area.
uniform float density : hint_range(0.1, 10.0, 0.1) = 1.0;
uniform float flight_speed : hint_range(0.0, 10.0, 0.1) = 0.4;
uniform float glide_strength : hint_range(0.0, 0.12, 0.01) = 0.04;
uniform vec2 scale_range = vec2(0.7, 1.0);
uniform float tilt_strength : hint_range(0.0, 1.5, 0.05) = 0.35;
uniform float animation_fps : hint_range(0.0, 120.0, 1.0) = 12.0;
uniform float glide_ratio : hint_range(0.0, 0.9, 0.05) = 0.35;
uniform int glide_frame : hint_range(0, 63, 1) = 2;
// Match CanvasItemMaterial's horizontal frames times vertical frames.
uniform int animation_frames : hint_range(1, 64, 1) = 6;
uniform vec4 tint : source_color = vec4(1.0);

float random_value(float seed) {
	return fract(sin(seed * 127.1 + 311.7) * 43758.5453);
}

vec2 orbit_center(float seed) {
	float angle = random_value(seed + 7.0) * TAU;
	float radius = sqrt(random_value(seed + 19.0)) * 0.15;
	return vec2(cos(angle), sin(angle)) * radius;
}

vec2 flight_position(float seed, float time) {
	// Spread starting positions over the entire orbit, with a different radius and center.
	float phase = time + random_value(seed + 11.0) * TAU;
	float lane = mix(0.18, 0.65, sqrt(random_value(seed + 31.0)));
	vec2 position = vec2(cos(phase), sin(phase)) * lane + orbit_center(seed);
	position += vec2(sin(phase * 0.8 + seed), sin(phase * 1.3 + seed)) * glide_strength;
	return position * max(swarm_radius, vec2(0.0)) / sqrt(max(density, 0.1));
}

vec2 flight_direction(float seed, float time) {
	float phase = time + random_value(seed + 11.0) * TAU;
	float lane = mix(0.18, 0.65, sqrt(random_value(seed + 31.0)));
	vec2 direction = vec2(-sin(phase), cos(phase)) * lane;
	direction += vec2(0.8 * cos(phase * 0.8 + seed), 1.3 * cos(phase * 1.3 + seed)) * glide_strength;
	return direction * max(swarm_radius, vec2(0.0));
}

void process() {
	float seed = float(INDEX) + float(RANDOM_SEED % 65521u);
	float travel_sign = random_value(seed + 83.0) < 0.5 ? -1.0 : 1.0;
	float time = TIME * flight_speed * mix(0.7, 1.3, random_value(seed + 97.0)) * travel_sign;
	vec2 position = flight_position(seed, time);
	vec2 direction = flight_direction(seed, time) * travel_sign;
	vec2 next_direction = flight_direction(seed, time + 0.15 * travel_sign) * travel_sign;
	float turn = atan(direction.x * next_direction.y - direction.y * next_direction.x, dot(direction, next_direction));
	// Point along the flight path and bank gently into turns instead of wobbling.
	float angle = 0.0;
	if (dot(direction, direction) > 0.0001) {
		angle = atan(direction.y, direction.x) + PI * 0.5 + turn * tilt_strength;
	}
	float size = mix(min(scale_range.x, scale_range.y), max(scale_range.x, scale_range.y), random_value(seed + 43.0));
	size = max(size, 0.01);
	TRANSFORM = mat4(1.0);
	TRANSFORM[0].xy = vec2(cos(angle), sin(angle)) * size;
	TRANSFORM[1].xy = vec2(-sin(angle), cos(angle)) * size;
	TRANSFORM[3].xy = position;
	COLOR = tint;
	// Alternate three full wing beats with a short glide, meeting at the same pose.
	// CanvasItemMaterial reads CUSTOM.z as a normalized spritesheet frame.
	float frames = float(max(animation_frames, 1));
	float animation_rate = animation_fps * mix(0.85, 1.15, random_value(seed + 59.0));
	float flap_ratio = max(1.0 - glide_ratio, 0.1);
	float cycle = fract(TIME * animation_rate * flap_ratio / (frames * 3.0) + random_value(seed + 71.0));
	float flap_progress = min(cycle / flap_ratio, 1.0);
	float glide_pose = (float(clamp(glide_frame, 0, max(animation_frames - 1, 0))) + 0.5) / frames;
	CUSTOM.z = fract(flap_progress * 3.0 + glide_pose);
}
