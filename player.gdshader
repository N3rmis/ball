shader_type spatial;

varying vec3 pos;
uniform int shade_bands : hint_range(2, 10) = 3;

uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float rim_smoothness : hint_range(0.0, 0.1) = 0.01;

void vertex() {
	pos = (VERTEX + 1.0) / 2.0;
}

void fragment() {
	ALBEDO = vec3(0.0, clamp(pos.x / 2.0 + 0.5, 0.5, 1.0), clamp((pos.z + pos.x) / 4.0 + 0.75, 0.75, 1.0)) / 3.0;
	float NdotV = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = 1.0 - NdotV;
	float smoothness = max(rim_smoothness, 0.001);
	rim = smoothstep(
		rim_threshold - smoothness,
		rim_threshold + smoothness,
		rim
	);
	ALBEDO = (1.0 - rim) * ALBEDO + (vec3(0.5) + ALBEDO * 0.5);
}

void light() {
	vec3 norm = normalize(NORMAL);
	float NdotL = max(0.0, dot(norm, LIGHT));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * (NdotL / 50.0);
	
	float NdotV = clamp(dot(norm, normalize(VIEW)), 0.0, 1.0);
	float rim = 1.0 - NdotV;
	float smoothness = max(rim_smoothness, 0.001);
	rim = smoothstep(
		rim_threshold - smoothness,
		rim_threshold + smoothness,
		rim
	);
	DIFFUSE_LIGHT += rim_color.rgb * rim * ATTENUATION;
}
