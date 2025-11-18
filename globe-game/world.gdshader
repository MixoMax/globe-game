shader_type spatial;


uniform sampler2D gradient_texture;

varying float vHeight;

float random(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
float random(vec3 p) {
    vec3 p3 = fract(vec3(p.xyz) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 random2 (in vec2 st) {
    vec2 vec = vec2(random(st)*2.-1.,random(st+.5)*2.-1.);
    if (abs(vec.x) < 1e-4 && abs(vec.y) < 1e-4) {
        vec.x += 1e-2;
    }
    return normalize(vec);
}
vec3 random3 (in vec3 st) {
    vec3 vec = vec3(random(st)*2.-1.,random(vec3(st.x+.5,st.yz))*2.-1.,random(vec3(st.xy+.5,st.z))*2.-1.);
    if (abs(vec.x) < 1e-4 && abs(vec.y) < 1e-4 && abs(vec.z) < 1e-4) {
        vec.x += 1e-2;
    }
    return normalize(vec);
}

float positive(in float value){
    return (value + 1.)/2.;
}

float noise2D (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    vec2 a = random2(i);
    vec2 b = random2(i + vec2(1.0, 0.0));
    vec2 c = random2(i + vec2(0.0, 1.0));
    vec2 d = random2(i + vec2(1.0, 1.0));
    
    vec2 u = f;
    vec2 v = f - vec2(1.0, 0.0);
    vec2 w = f - vec2(0.0, 1.0);
    vec2 x = f - vec2(1.0, 1.0);

    // Dot products
    float va = dot(a, u);
    float vb = dot(b, v);
    float vc = dot(c, w);
    float vd = dot(d, x);
    
    vec2 fade = f * f * (3.0 - 2.0 * f); // Perlin's fade function
    float x1 = mix(va, vb, fade.x);
    float x2 = mix(vc, vd, fade.x);
    float value = mix(x1, x2, fade.y);
    
    return value;
}

float noise3D (in vec3 st) {
    vec3 i = floor(st);
    vec3 fr = fract(st);

    // Eight corners in 3D of a tile
    vec3 a = random3(i);
    vec3 b = random3(i + vec3(1.0, 0.0, 0.0));
    vec3 c = random3(i + vec3(0.0, 1.0, 0.0));
    vec3 d = random3(i + vec3(1.0, 1.0, 0.0));
	vec3 e = random3(i + vec3(0.0, 0.0, 1.0));
    vec3 f = random3(i + vec3(1.0, 0.0, 1.0));
    vec3 g = random3(i + vec3(0.0, 1.0, 1.0));
    vec3 h = random3(i + vec3(1.0, 1.0, 1.0));
    
    vec3 q = fr;
    vec3 r = fr - vec3(1.0, 0.0, 0.0);
    vec3 s = fr - vec3(0.0, 1.0, 0.0);
    vec3 t = fr - vec3(1.0, 1.0, 0.0);
	vec3 u = fr - vec3(0.0, 0.0, 1.0);
    vec3 v = fr - vec3(1.0, 0.0, 1.0);
    vec3 w = fr - vec3(0.0, 1.0, 1.0);
    vec3 x = fr - vec3(1.0, 1.0, 1.0);

    // Dot products
    float va = dot(a, q);
    float vb = dot(b, r);
    float vc = dot(c, s);
    float vd = dot(d, t);
	float ve = dot(e, u);
    float vf = dot(f, v);
    float vg = dot(g, w);
    float vh = dot(h, x);
    
    vec3 fade = fr * fr * (3.0 - 2.0 * fr); // Perlin's fade function
    float x1 = mix(va, vb, fade.x);
    float x2 = mix(vc, vd, fade.x);
	float y1 = mix(ve, vf, fade.x);
    float y2 = mix(vg, vh, fade.x);
    float x3 = mix(x1, x2, fade.y);
	float y3 = mix(y1, y2, fade.y);
	float value = mix(x3, y3, fade.z);
    
    return value;
}

void vertex() {
	float noiseValue = 0.;
    int amount = 10;
    
    float lacunarity = 2.;
    float persistance = .5;
    float amplitudeAddition = 0.;
    float frequency = 1.;
    float amplitude = 1.;
    for(int i=0;i<amount;i++){
        amplitudeAddition += amplitude;
        noiseValue += amplitude * positive((noise3D(VERTEX.xyz*(frequency))));
        
        frequency *= lacunarity;
        amplitude *= persistance;
    }
    noiseValue /= amplitudeAddition;

	vHeight = (noiseValue);
	VERTEX *= (vHeight) + .5;
}

void fragment() {
	
	// Called for every pixel the material is visible on.
	vec3 color = texture(gradient_texture, vec2(vHeight,0)).xyz;
	ALBEDO = color;
	
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
