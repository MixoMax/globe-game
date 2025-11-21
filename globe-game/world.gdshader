shader_type spatial;

uniform sampler2D map_texture;
uniform float water_level = 0.0;
uniform float height_scale = 1.0;

varying float vHeight;

void vertex() {
	float h = texture(map_texture, UV).r;
	vHeight = h;
	
	// Displace along normal based on height relative to water level
	// We want the coastline to be exactly at the original mesh surface (or slightly adjusted)
	// If h = water_level, displacement should be 0? 
	// Or maybe we want the whole sphere to be rough.
	
	float displacement = h * height_scale;
	VERTEX += NORMAL * displacement;
}

void fragment() {
	vec3 sand_color = vec3(0.76, 0.7, 0.5);
	vec3 grass_color = vec3(0.13, 0.55, 0.13);
	vec3 rock_color = vec3(0.4, 0.4, 0.4);
	vec3 snow_color = vec3(0.9, 0.9, 0.9);
	vec3 seabed_color = vec3(0.05, 0.05, 0.2);

	vec3 color = seabed_color;
	
	float h = vHeight;
	
	// Adjust these thresholds based on your noise range (-1 to 1 usually) and water_level
	float shore_line = water_level + 0.02;
	float grass_line = water_level + 0.15;
	float rock_line = water_level + 0.5;
	float snow_line = water_level + 0.7;

	if (h > water_level) color = mix(seabed_color, sand_color, smoothstep(water_level, shore_line, h));
	if (h > shore_line) color = mix(color, grass_color, smoothstep(shore_line, grass_line, h));
	if (h > rock_line) color = mix(color, rock_color, smoothstep(rock_line, rock_line + 0.1, h));
	if (h > snow_line) color = mix(color, snow_color, smoothstep(snow_line, snow_line + 0.1, h));

	ALBEDO = color;
	ROUGHNESS = 0.8;
}
