#version 420

uniform mat4 m_pvm;
uniform mat3 m_normal;
uniform mat4 m_view;
uniform vec4 l_dir;
uniform float timer;

in vec4 position;
in vec2 texCoord0;

const float PI = 3.14159265358979323846;

const mat2 myt = mat2(.12121212, .13131313, -.13131313, .12121212);
const vec2 mys = vec2(1e4, 1e6);

out Data {
	vec3 normal;
	vec3 l_dir;
	vec4 cor;
} DataOut;

//CENAS PARA A COR
vec4 color(float height, float snow){
	bool r = height == -5.0;
	int nr = int(!r);
	int s = int(height > snow);
	return vec4(s, max(nr, s), max(int(r), s), height * nr);
} 


float remapValue(float value, vec2 sourceRange, vec2 targetRange){
	return targetRange.x + (value - sourceRange.x) * (targetRange.y - targetRange.x) / (sourceRange.y - sourceRange.x);
}

vec2 rhash(vec2 uv) {
  uv *= myt;
  uv *= mys;
  return fract(fract(uv / mys) * uv);
}

vec3 hash(vec3 p) {
  return fract(sin(vec3(dot(p, vec3(1.0, 57.0, 113.0)),
                        dot(p, vec3(57.0, 113.0, 1.0)),
                        dot(p, vec3(113.0, 1.0, 57.0)))) *
               43758.5453);
}

float voronoi2d(const in vec2 point) {
  vec2 p = floor(point);
  vec2 f = fract(point);
  float res = 0.0;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 b = vec2(i, j);
      vec2 r = vec2(b) - f + rhash(p + b);
      res += 1. / pow(dot(r, r), 8.);
    }
  }
  return remapValue(pow(1. / res, 0.0625),vec2(0,1),vec2(-1,1));
}

vec3 mod289(vec3 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289(vec4 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
    return mod289(((x*34.0)+1.0)*x);
}

vec4 taylorInvSqrt(vec4 r) {
	return 1.79284291400159 - 0.85373472095314 * r;
}


float snoise(vec3 v) { 
	const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
	const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);
	// First corner
	vec3 i  = floor(v + dot(v, C.yyy) );
	vec3 x0 =   v - i + dot(i, C.xxx) ;

	// Other corners
	vec3 g = step(x0.yzx, x0.xyz);
	vec3 l = 1.0 - g;
	vec3 i1 = min( g.xyz, l.zxy );
	vec3 i2 = max( g.xyz, l.zxy );

	//   x0 = x0 - 0.0 + 0.0 * C.xxx;
	//   x1 = x0 - i1  + 1.0 * C.xxx;
	//   x2 = x0 - i2  + 2.0 * C.xxx;
	//   x3 = x0 - 1.0 + 3.0 * C.xxx;
	vec3 x1 = x0 - i1 + C.xxx;
	vec3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
	vec3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y

	// Permutations
	i = mod289(i); 
	vec4 p = permute( permute( permute( 
	           i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
	         + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) 
	         + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

	// Gradients: 7x7 points over a square, mapped onto an octahedron.
	// The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
	float n_ = 0.142857142857; // 1.0/7.0
	vec3  ns = n_ * D.wyz - D.xzx;

	vec4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,7*7)

	vec4 x_ = floor(j * ns.z);
	vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

	vec4 x = x_ *ns.x + ns.yyyy;
	vec4 y = y_ *ns.x + ns.yyyy;
	vec4 h = 1.0 - abs(x) - abs(y);

	vec4 b0 = vec4( x.xy, y.xy );
	vec4 b1 = vec4( x.zw, y.zw );

	//vec4 s0 = vec4(lessThan(b0,0.0))*2.0 - 1.0;
	//vec4 s1 = vec4(lessThan(b1,0.0))*2.0 - 1.0;
	vec4 s0 = floor(b0)*2.0 + 1.0;
	vec4 s1 = floor(b1)*2.0 + 1.0;
	vec4 sh = -step(h, vec4(0.0));

	vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
	vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

	vec3 p0 = vec3(a0.xy,h.x);
	vec3 p1 = vec3(a0.zw,h.y);
	vec3 p2 = vec3(a1.xy,h.z);
	vec3 p3 = vec3(a1.zw,h.w);

	//Normalise gradients
	vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
	p0 *= norm.x;
	p1 *= norm.y;
	p2 *= norm.z;
	p3 *= norm.w;

	// Mix final noise value
	vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
	m = m * m;
	return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), 
                                  dot(p2,x2), dot(p3,x3) ) );
}

/*
* Procedural multifractal evaluated at "point"; 
* returns value stored in "value".
*
* Copyright 1994 F. Kenton Musgrave 
* 
* Parameters:
*    ``H''  determines the highest fractal dimension
*    ``lacunarity''  is gap between successive frequencies
*    ``octaves''  is the number of frequencies in the fBm
*    ``offset''  is the zero offset, which determines multifractality
*/

float multifractal(vec3 point, float H, float lacunarity, float octaves, float offset){
	float value, frequency, rem,noise;
    int i;
	bool first =true;
	float exponent_array[8+1];

    /* precompute and store spectral weights */
	if (first) {
         /* seize required memory for exponent_array */
        frequency = 1.0;
        for (i=0; i<=octaves; i++) {
            /* compute weight for each frequency */
            exponent_array[i] = pow( frequency, -H );
            frequency *= lacunarity;
        }
		first = false;
	}
   	value = 1.0;            /* initialize vars to proper values */
	frequency = 1.0;
	/* inner loop of multifractal construction */
	for (i=0; i<octaves; i++) {
		noise = 1 - abs(snoise(point));
		value *= offset * frequency * noise;
		point.x *= lacunarity;
		point.y *= lacunarity;
		point.z *= lacunarity;
	}
	rem = octaves - floor(octaves);
	if (rem > 0){
		noise = 1 - abs(snoise(point));
		value += rem * noise * exponent_array[i];
	}
	return value;
}

void main() {
	
	int k = 1024;
	float scale = 10;
	float octaves = 8.0;
	float H = 0.97;
	float lacunarity = 2.8;
	float offset = 0.9;
	float pointy = 0;    

	vec2 p = (position.xz+k)/(2*k);
	vec2 p2 = (vec2(position.x+1,position.z)+k)/(2*k);
	vec2 p3 = (vec2(position.x-1,position.z)+k)/(2*k);
	vec2 p4 = (vec2(position.x,position.z+1)+k)/(2*k);
	vec2 p5 = (vec2(position.x,position.z-1)+k)/(2*k);

	float h = multifractal(vec3(p.x,0.0,p.y),H,lacunarity,octaves,offset) * scale;
	float h2 = multifractal(vec3(p2.x,0.0,p2.y),H,lacunarity,octaves,offset) * scale;
	float h3 = multifractal(vec3(p3.x,0.0,p3.y),H,lacunarity,octaves,offset) * scale;
	float h4 = multifractal(vec3(p4.x,0.0,p4.y),H,lacunarity,octaves,offset) * scale;
	float h5 = multifractal(vec3(p5.x,0.0,p5.y),H,lacunarity,octaves,offset) * scale;

	h = max(-5,h);
	h2 = max(-5,h2);
	h3 = max(-5,h3);
	h4 = max(-5,h4);
	h5 = max(-5,h5);

	vec4 newPos = vec4(position.x,h,position.z,1);

	vec3 x = vec3(newPos.x+1,h2,newPos.z)-vec3(newPos.x-1,h3,newPos.z);

	vec3 z = vec3(newPos.x,h4,newPos.z+1)-vec3(newPos.x,h5,newPos.z-1);

	vec4 color = color(newPos.y, 65.0);
	DataOut.cor = vec4(color.rgb, 1.0);
	newPos.y = color.a;

	vec3 normal = normalize(cross(z,x));

	DataOut.normal = normalize(m_normal * normal);
	
	DataOut.l_dir = vec3(normalize(- (m_view * l_dir)));

	gl_Position = m_pvm * newPos;
}