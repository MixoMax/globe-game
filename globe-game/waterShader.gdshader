shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

uniform sampler2D map_texture;
uniform vec3 color : source_color = vec3(0.0, 0.4, 0.8);
uniform float water_level = 0.0;
uniform float height_scale = 5.0;
uniform float wave_speed = 2.0;
uniform float wave_global_scale = 0.5;

void vertex() {
	vec4 map_data = texture(map_texture, UV);
	float dist_to_shore = map_data.g; // Green channel has distance
	
	// Calculate wave
	// Use world position for consistent waves across chunks if possible, but VERTEX is local.
	// For a sphere, local vertex is fine as long as chunks align.
	float wave = sin(VERTEX.x * 10.0 + TIME * wave_speed) * 0.5;
	wave += cos(VERTEX.z * 8.0 + TIME * wave_speed * 0.8) * 0.5;
	wave += sin(VERTEX.x * 20.0 - TIME * wave_speed * 1.2) * 0.2;
	
	// Amplitude increases with distance from shore
	// dist_to_shore is roughly 0.0 to 1.0
	float amplitude = smoothstep(0.0, 0.1, dist_to_shore); 
	
	float final_wave_height = wave * amplitude * wave_global_scale;
	
	// Base position: water_level
	// We displace along the normal
	float displacement = water_level * height_scale + final_wave_height;
	
	VERTEX += NORMAL * displacement;
}

void fragment() {
	ALBEDO = color;
	ALPHA = 0.9;
	ROUGHNESS = 0.1;
	METALLIC = 0.1;
	SPECULAR = 0.5;
	
	// Foam at shore
	float dist = texture(map_texture, UV).g;
	if (dist < 0.01) {
		ALBEDO = mix(vec3(1.0), color, dist / 0.01);
	}
}
