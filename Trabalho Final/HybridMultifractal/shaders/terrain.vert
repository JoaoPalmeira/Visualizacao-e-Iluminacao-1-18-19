#version 420

uniform mat4 m_pvm;
uniform mat3 m_normal;
uniform mat4 m_view;
uniform vec4 l_dir;
uniform float timer;
uniform vec4 cam_pos;

in vec4 position2;
in vec2 texCoord0;

const float PI = 3.14159265358979323846;

const mat2 myt = mat2(.12121212, .13131313, -.13131313, .12121212);
const vec2 mys = vec2(1e4, 1e6);

out Data {
	vec3 normal;
	vec3 l_dir;
	vec4 cor;
	float height;
	vec2 tc;
	vec3 eye;
	vec3 newPos;
} DataOut;

//COR 
vec4 color(float height, float snow){
	bool r = height == -5.0;
	int nr = int(!r);
	int s = int(height > snow);
	return vec4(s, max(nr, s), max(int(r), s), height * nr);
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



float HybridMultifractal(vec3 point, float H, float lacunarity, float octaves, float offset ){
	float frequency, result, sig, weight, rem; 
	int i;
	bool first = true;
	float exponent_array[8+1];

	/* precompute and store spectral weights */
	if ( first ) {
		frequency = 1;
		for (i=0; i<=octaves; i++) {
			/* compute weight for each frequency */
			exponent_array[i] = pow( frequency, -H);
			frequency *= lacunarity;
		}
		first = false;
	}

	/* get first octave of function */
	result = 1-(abs(snoise(point) + offset)) * exponent_array[0];
	weight = result;
	/* increase frequency */
	point.x *= lacunarity;
	point.y *= lacunarity;
	point.z *= lacunarity;

	/* spectral construction inner loop, where the fractal is built */
	for (i=1; i<octaves; i++) {
		/* prevent divergence */
		if ( weight > 1.0 )  weight = 1.0;

		/* get next higher frequency */
		sig = 1-(abs(snoise(point) + offset)) * exponent_array[i];
		/* add it in, weighted by previous freq's local value */
		result += weight * sig;
		/* update the (monotonically decreasing) weighting value */
		/* (this is why H must specify a high fractal dimension) */
		weight *= sig;

		/* increase frequency */
		point.x *= lacunarity;
		point.y *= lacunarity;
		point.z *= lacunarity;
	} /* for */

	/* take care of remainder in ``octaves''  */
	rem = octaves - floor(octaves);
	if ( rem > 0)
				/* ``i''  and spatial freq. are preset in loop above */
		result += rem * (1-(abs(snoise(point) + offset)) * exponent_array[i]);

	return(result);
}

void main() {
	

	int k = 256;
	float scale = 90;
	float octaves = 6.0;
	float H = 1;
	float lacunarity = 2.0;
	float offset = 0.9;
	float pointy = 0;
	
	vec2 cam = floor(cam_pos.xz);
 
    vec4 position = vec4(position2.x + cam.x, position2.y, position2.z + cam.y,1);


	vec2 p = (position.xz+k)/(2*k);
	vec2 p2 = (vec2(position.x+1,position.z)+k)/(2*k);
	vec2 p3 = (vec2(position.x-1,position.z)+k)/(2*k);
	vec2 p4 = (vec2(position.x,position.z+1)+k)/(2*k);
	vec2 p5 = (vec2(position.x,position.z-1)+k)/(2*k);

	float h = HybridMultifractal(vec3(p.x,pointy,p.y),H,lacunarity,octaves,offset) * scale;
	float h2 = HybridMultifractal(vec3(p2.x,pointy,p2.y),H,lacunarity,octaves,offset) * scale;
	float h3 = HybridMultifractal(vec3(p3.x,pointy,p3.y),H,lacunarity,octaves,offset) * scale;
	float h4 = HybridMultifractal(vec3(p4.x,pointy,p4.y),H,lacunarity,octaves,offset) * scale;
	float h5 = HybridMultifractal(vec3(p5.x,pointy,p5.y),H,lacunarity,octaves,offset) * scale;


	//restricoes da altura
	h = max(-5,h);
	h2 = max(-5,h2);
	h3 = max(-5,h3);
	h4 = max(-5,h4);
	h5 = max(-5,h5);

	
	vec4 newPos = vec4(position2.x + cam.x,h,position2.z + cam.y,1);

	vec3 x = vec3(newPos.x+1,h2,newPos.z)-vec3(newPos.x-1,h3,newPos.z);

	vec3 z = vec3(newPos.x,h4,newPos.z+1)-vec3(newPos.x,h5,newPos.z-1);

	vec4 color = color(newPos.y, 65.0);
	DataOut.cor = vec4(color.rgb, 1.0);
	newPos.y = color.a;

	vec3 normal = normalize(cross(z,x));
	DataOut.tc = texCoord0;
	DataOut.normal = normalize(m_normal * normal);
	DataOut.newPos = vec3(newPos);
	
	DataOut.l_dir = vec3(normalize(- (m_view * l_dir)));
	DataOut.height = newPos.y/800.0;
	gl_Position = m_pvm * newPos;
}