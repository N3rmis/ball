shader_type canvas_item;

uniform sampler2D noise: repeat_enable;
uniform vec4 line_color: source_color;
uniform float line_count: hint_range(0.0, 2.0, 0.05) = 0.5;
uniform float line_density: hint_range(0.0, 1.0) = 0.5;
uniform float line_faloff: hint_range(0.0, 1.0) = 0.25;
uniform float mask_size: hint_range(0.0, 1.0) = 0.1;
uniform float mask_edge: hint_range(0.0, 1.0) = 0.5;
uniform float animation_speed: hint_range(1.0, 20.0) = 0.5;

varying float rot_cos;
varying float rot_sin;

void vertex() {
	float rotation = floor(fract(TIME) * animation_speed);
	rot_cos = cos(rotation);
	rot_sin = sin(rotation);
}

void fragment() {
	if (line_density <= 0.01) {
		discard;
	}

	vec2 dir = UV - vec2(0.5);
	float dist = length(dir);

	// Rotate dir around center using vertex-computed sin/cos
	vec2 rotated_dir = vec2(
		rot_cos * dir.x - rot_sin * dir.y,
		rot_sin * dir.x + rot_cos * dir.y
	);

	float radius = dist * 2.0;
	float angle = atan(rotated_dir.y, rotated_dir.x) * (0.5 / PI);
	vec2 polar_uv = mod(vec2(radius * 0.01, angle * line_count), 1.0);

	// Use textureLod to prevent derivative explosion and seam stalls at the atan wrap
	vec3 lines = textureLod(noise, polar_uv, 0.0).rgb;

	float span = max(mask_edge - mask_size, 0.0001);
	float mask = clamp((dist - mask_size) / span, 0.0, 1.0);
	float threshold = 1.0 - (mask * line_density);

	float falloff = max(line_faloff, 0.0001);
	float result = smoothstep(threshold, threshold + falloff, lines.r);

	if (result <= 0.002) {
		discard;
	}

	COLOR.rgb = line_color.rgb;
	COLOR.a = min(line_color.a, result);
}
