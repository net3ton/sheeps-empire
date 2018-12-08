varying mediump vec4 position;
varying mediump vec2 var_texcoord0;

uniform lowp sampler2D DIFFUSE_TEXTURE;

uniform lowp vec4 resolution;
uniform lowp vec4 shed0;
uniform lowp vec4 shed1;
uniform lowp vec4 shed2;

float PHI = 1.61803398874989484820459 * 00000.1; // Golden Ratio   
float PI  = 3.14159265358979323846264 * 00000.1; // PI
float SQ2 = 1.41421356237309504880169 * 10000.0; // Square Root of Two

// gold_noise
float rand(vec2 co){
	float seed = 1.0;
	return fract(tan(distance(co*(seed+PHI), vec2(PHI, PI)))*SQ2);
}

float rand1(vec2 co){
	return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void main()
{
	// Pre-multiply alpha since all runtime textures already are
	//lowp vec4 tint_pm = vec4(tint.xyz * tint.w, tint.w);
	//gl_FragColor = texture2D(DIFFUSE_TEXTURE, var_texcoord0.xy) * tint_pm;

	vec2 st = gl_FragCoord.xy/resolution.xy;
	st.x *= resolution.x/resolution.y;

	const float PIXELS = 50.0;
	st.x = float(int(st.x * PIXELS))/PIXELS;
	st.y = float(int(st.y * PIXELS))/PIXELS;
	
	vec2 point[6];
	point[0] = shed0.xy;
	point[1] = shed0.zw;
	point[2] = shed1.xy;
	point[3] = shed1.zw;
	point[4] = shed2.xy;
	point[5] = shed2.zw;

	vec3 color = vec3(.11, .37, .13);
	float min_dist = 1.0;
	
	for (int i=0; i<6; i++)
	{
		float dist = distance(st, point[i]);
		min_dist = min(dist, min_dist);
	}

	if (rand(st) > 0.5)
		color += min_dist/1.5;
	else
		color += min_dist;
	
	gl_FragColor = vec4(color * resolution.z, 1.0);
}
