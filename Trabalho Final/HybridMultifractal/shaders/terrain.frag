#version 420

uniform sampler2D snow;
uniform sampler2D terraco;
uniform sampler2D calhau;
uniform sampler2D agua;
uniform sampler2D chao;

in Data {
	vec3 normal;
	vec3 l_dir;
	vec4 cor;
	float height;
	vec2 tc;
	vec3 eye;
	vec3 newPos;
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
	vec4 aguinha = texture(agua,t);
	vec4 solo = texture(chao,t);
	

	vec3 n = normalize(DataIn.normal);
	 int s = int(DataIn.cor == vec4(1.0));
	float intensity = max(0.0, dot(n, DataIn.l_dir));

	float a = clamp((n.y - .6)*5 + .5, 0, 1);

	vec4 terra = vec4(1.0,0.0,0.0,1.0);

	vec4 neve = vec4(0.0,1.0,0.0,1.0);

	vec4 rocalhada = vec4(0.0,0.0,1.0,1.0);

	
	if(DataIn.height<0.0){
		//cOut.xyz = uncharted2Tonemap(roca.xyz);
		cOut.xyz = tonemapUncharted2(aguinha.xyz);
	}
	else{
		float hscaled = DataIn.height*2.0 - 1e-05;
		float hi = int(hscaled);
		float hfrac = hscaled-float(hi);
		if( hscaled > 0.6)
            cOut.xyz= mix( mix( roca,snowC,hfrac),mix( terreno,snowC,hfrac),hfrac).xyz; // blends between the two colours 
        else if(hscaled>0 && hscaled<0.8){cOut.xyz= mix( mix( roca,terreno,hfrac),mix( terreno,snowC,hfrac),hfrac).xyz;}
		else 
			cOut.xyz = tonemapUncharted2(solo.xyz);
	}

}