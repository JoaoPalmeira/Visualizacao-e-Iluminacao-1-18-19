#version 420

in Data {
	vec3 normal;
	vec3 l_dir;
	vec4 cor;
} DataIn;

out vec4 cOut;

void main() {
	
	vec3 n = normalize(DataIn.normal);
	int s = int(DataIn.cor == vec4(1.0));
	float intensity = max(0.0, dot(n, DataIn.l_dir));
	cOut = intensity * DataIn.cor;
}
	