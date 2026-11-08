shader_type spatial;

uniform int shade_bands : hint_range(2, 10) = 3;
uniform sampler2D trackTypes : source_color, filter_nearest;

varying flat vec2 uv2;

void vertex() {
	uv2 = UV2;
}

void fragment() {
	vec4 tex_color = textureLod(trackTypes, vec2(mod(UV.x, 0.5), mod(UV.y, 0.5)) + uv2, 0.0);
	ALBEDO = tex_color.rgb;
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
