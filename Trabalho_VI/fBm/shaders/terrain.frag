#version 420

uniform sampler2D snow;
uniform sampler2D terraco;
uniform sampler2D calhau;

in Data {
	vec3 normal;
	vec3 l_dir;
	vec4 cor;
	float height;
	vec2 tc;
	vec3 eye;
} DataIn;

out vec4 cOut;

vec3 uncharted2Tonemap(const vec3 x) {
	const float A = 0.15;
	const float B = 0.50;
	const float C = 0.10;
	const float D = 0.20;
	const float E = 0.02;
	const float F = 0.30;
	return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 tonemapUncharted2(const vec3 color) {
	const float W = 11.2;
	const float exposureBias = 2.0;
	vec3 curr = uncharted2Tonemap(exposureBias * color);
	vec3 whiteScale = 1.0 / uncharted2Tonemap(vec3(W));
	return curr * whiteScale;
}

void main() {
	float scale = 0.1;
	vec2 t = DataIn.tc + DataIn.eye.xy;
	vec4 snowC = texture(snow,t);
	vec4 terreno = texture(terraco,t);
	vec4 roca = texture(calhau,t);

	vec3 n = normalize(DataIn.normal);
	int s = int(DataIn.cor == vec4(1.0));
	float intensity = max(0.0, dot(n, DataIn.l_dir));
	if(DataIn.height >= 65.0){
		cOut = intensity * snowC;
		cOut.xyz=tonemapUncharted2(cOut.xyz);
	}
	else if(DataIn.height<0){
		cOut = vec4(0.0,0.0,1.0,1.0);
		cOut.xyz=tonemapUncharted2(cOut.xyz);
	}
	else if(DataIn.height>=0 && DataIn.height<5){
		cOut = intensity * roca;
		cOut.xyz=tonemapUncharted2(cOut.xyz);
	}
	else{cOut = intensity * terreno; cOut.xyz=tonemapUncharted2(cOut.xyz);}

}