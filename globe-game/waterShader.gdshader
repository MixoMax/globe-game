shader_type spatial;
render_mode blend_mix;

uniform vec3 color;
uniform float height;

void vertex() {
	VERTEX *= height;
	// Called for every vertex the material is visible on.
}

void fragment() {
	
	ALBEDO = color;
	ALPHA = .9;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
