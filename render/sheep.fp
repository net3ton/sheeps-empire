varying mediump vec4 position;
varying mediump vec2 var_texcoord0;

uniform lowp sampler2D DIFFUSE_TEXTURE;
uniform lowp vec4 possize;

void main()
{
	vec2 st = (gl_FragCoord.xy - (possize.xy * 2.0)) / possize.zw;

	const float PIXELS = 5.0;
	st.x = 1.0 - float(int(st.x * PIXELS))/PIXELS;
	st.y = float(int(st.y * PIXELS))/PIXELS;
	
	vec4 color = texture2D(DIFFUSE_TEXTURE, var_texcoord0.xy);
	float shade = st.x * st.y * 5.0;
	color.xyz *= shade * color.w;
	
	gl_FragColor = color;

	//gl_FragColor = texture2D(DIFFUSE_TEXTURE, var_texcoord0.xy) * (possize.x/400.0);
	//gl_FragColor = texture2D(DIFFUSE_TEXTURE, var_texcoord0.xy) * (gl_FragCoord.x/800.0);
}
