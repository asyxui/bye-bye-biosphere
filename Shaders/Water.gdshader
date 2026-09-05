shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.1, 0.32, 0.5, 0.6);
uniform vec4 water_color_deep : source_color = vec4(0.05, 0.15, 0.3, 0.85);
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float wave_speed = 0.15;
uniform float wave_scale = 8.0;
uniform float wave_strength = 0.2;
uniform float fresnel_power = 3.0;

varying float is_top_face;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void vertex() {
	is_top_face = step(0.5, NORMAL.y);
}

void fragment() {
	if (is_top_face < 0.5) {
		discard;
	}

	// Two scrolling noise layers perturb the normal to fake a moving surface, without displacing geometry.
	vec2 uv1 = UV * wave_scale + vec2(TIME * wave_speed, TIME * wave_speed * 0.6);
	vec2 uv2 = UV * wave_scale * 1.7 - vec2(TIME * wave_speed * 0.7, TIME * wave_speed * 0.4);

	float n1 = value_noise(uv1);
	float n2 = value_noise(uv2);

	vec3 normal_perturb = normalize(vec3((n1 - n2) * wave_strength, (n1 + n2 - 1.0) * wave_strength, 1.0));
	NORMAL_MAP = normal_perturb * 0.5 + 0.5;

	// Fresnel makes shallow grazing angles brighter/more opaque, like a real water surface, instead of refraction.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);

	ALBEDO = mix(water_color.rgb, water_color_deep.rgb, 0.3);
	ALPHA = mix(water_color.a, 1.0, fresnel);
	ROUGHNESS = roughness;
	METALLIC = 0.1;
	SPECULAR = 0.6;
}
