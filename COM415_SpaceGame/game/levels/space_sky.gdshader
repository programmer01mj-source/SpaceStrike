// Procedural deep-space sky: dark gradient, soft coloured nebulae and a star field.
shader_type sky;

uniform vec3 base_color : source_color = vec3(0.008, 0.01, 0.03);
uniform vec3 nebula_color_a : source_color = vec3(0.32, 0.07, 0.55);
uniform vec3 nebula_color_b : source_color = vec3(0.04, 0.28, 0.65);
uniform float star_density : hint_range(0.9, 0.999) = 0.992;

float hash31(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		value += amplitude * value_noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 col = base_color;
	float cloud_a = fbm(dir * 2.4 + vec3(3.0));
	float cloud_b = fbm(dir * 3.2 - vec3(7.0));
	col += nebula_color_a * smoothstep(0.38, 0.8, cloud_a) * 0.6;
	col += nebula_color_b * smoothstep(0.42, 0.85, cloud_b) * 0.5;

	vec3 star_space = dir * 150.0;
	vec3 cell = floor(star_space);
	float h = hash31(cell);
	vec3 local = fract(star_space) - 0.5;
	float star = step(star_density, h) * smoothstep(0.4, 0.0, length(local));
	col += vec3(star) * (0.6 + 1.2 * hash31(cell + vec3(11.0)));

	COLOR = col;
}
