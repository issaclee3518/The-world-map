shader_type canvas_item;

varying vec2 world_pos;

uniform vec4 shallow_color : source_color = vec4(0.40, 0.74, 0.88, 1.0);
uniform vec4 mid_color     : source_color = vec4(0.18, 0.55, 0.78, 1.0);
uniform vec4 deep_color    : source_color = vec4(0.05, 0.22, 0.43, 1.0);
uniform vec4 trench_color  : source_color = vec4(0.02, 0.10, 0.22, 1.0);

uniform float world_scale = 0.0014; // pattern scale in world units
uniform float bands = 6.0;          // bathymetry-like quantization
uniform float contrast = 1.25;
uniform float swirl = 0.65;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = mat2(vec2(1.6, -1.2), vec2(1.2, 1.6)) * p;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = world_pos * world_scale;

	// Add a subtle swirl to mimic currents.
	float n1 = fbm(p);
	float n2 = fbm(p + vec2(11.3, -7.7));
	p += swirl * vec2(n1 - 0.5, n2 - 0.5);

	float n = fbm(p * 1.15);
	n = pow(clamp(n, 0.0, 1.0), contrast);

	// Quantize into bathymetry-like bands.
	float q = floor(n * bands) / max(bands - 1.0, 1.0);

	// Color ramp with a hint of trench depth.
	vec4 c = mix(shallow_color, mid_color, smoothstep(0.10, 0.45, q));
	c = mix(c, deep_color, smoothstep(0.40, 0.80, q));
	c = mix(c, trench_color, smoothstep(0.78, 1.00, q));

	COLOR = c;
}

