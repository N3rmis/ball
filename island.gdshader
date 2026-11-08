shader_type spatial;

uniform int shade_bands : hint_range(2, 10) = 3;
uniform int colour_bands : hint_range(2, 10) = 3;

uniform vec4 grass_colour;
uniform vec4 dirt_colour;

varying vec3 world_normal;

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	float grass = clamp(dot(normalize(world_normal), vec3(0.0, 1.0, 0.0)) * 1.2 - 0.2, 0.0, 1.0);
	vec4 c = mix(dirt_colour, grass_colour, grass);
	
	vec3 quantized = round(c.rgb * float(colour_bands)) / float(colour_bands);
	quantized.r -= 0.05;
	ALBEDO = quantized;
}

void light() {
	DIFFUSE_LIGHT = vec3(0.0);
	SPECULAR_LIGHT = vec3(0.0);
	
	float NdotL = max(0.0, dot(NORMAL, LIGHT));
	float band = NdotL * float(shade_bands);
	float stepped_diffuse = floor(band) / float(shade_bands);

	// Add slight smoothing at the edges
	float smooth_amount = 0.3; // 0.0 = hard steps, 1.0 = fully smooth
	float fract_part = fract(band);
	stepped_diffuse += (smoothstep(0.0, smooth_amount, fract_part) * smooth_amount) / float(shade_bands);

	stepped_diffuse = max(0.0, stepped_diffuse);
	DIFFUSE_LIGHT = ALBEDO * LIGHT_COLOR * ATTENUATION * stepped_diffuse / 15.0;
}
