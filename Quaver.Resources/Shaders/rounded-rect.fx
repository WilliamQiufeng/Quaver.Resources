#if OPENGL
	#define SV_POSITION POSITION
	#define VS_SHADERMODEL vs_3_0
	#define PS_SHADERMODEL ps_3_0
#else
	#define VS_SHADERMODEL vs_4_0_level_9_1
	#define PS_SHADERMODEL ps_4_0_level_9_1
#endif

Texture2D SpriteTexture;

sampler2D SpriteTextureSampler = sampler_state
{
	Texture = <SpriteTexture>;
};

struct VertexShaderOutput
{
	float4 Position : SV_POSITION;
	float4 Color : COLOR0;
	float2 TextureCoordinates : TEXCOORD0;
};

// The pixel-space width/height of the rectangle being drawn.
float2 p_size;

// The corner radius, in pixels.
float p_radius;

// Exponent for the corner's distance norm. 2.0 is a true circular arc, which (correctly) still
// reads as a flat vertical/horizontal run near a cap's tip before it visibly curves - the tangent
// there is exactly parallel to the edge, so the boundary's deviation from straight grows only with
// the square of the distance travelled. Dropping the exponent below 2 sharpens the curve so it
// bends away almost immediately, at the cost of the cap looking a bit more like a pointed lens than
// a perfectly soft circular pill. 1.5 was chosen as a moderate middle ground between the two.
static const float CORNER_NORM_EXPONENT = 1.5;

float4 MainPS(VertexShaderOutput input) : COLOR
{
	float2 halfSize = p_size * 0.5;

	// Pixel position relative to the center of the rectangle.
	float2 p = input.TextureCoordinates * p_size - halfSize;

	float2 q = abs(p) - (halfSize - p_radius);
	float2 qPos = max(q, 0);
	float cornerDist = pow(pow(qPos.x, CORNER_NORM_EXPONENT) + pow(qPos.y, CORNER_NORM_EXPONENT), 1.0 / CORNER_NORM_EXPONENT);
	float dist = cornerDist + min(max(q.x, q.y), 0) - p_radius;

	// Anti-aliased feather, in the same "virtual" pixel units as p_size/p_radius. UI is drawn
	// through WindowManager.Scale, so a button's actual on-screen pixel footprint can be smaller
	// than its virtual Width/Height (e.g. when the window/backbuffer is smaller than the virtual
	// UI resolution) - shrinking a too-thin feather below a single real screen pixel and leaving
	// the boundary under-antialiased. That's especially visible right at a rounded cap's tip,
	// where the true curve is already only fractions of a pixel wide, so a hard edge there reads
	// as "flat, then a sudden step into the curve". Feather is kept wide enough to stay above one
	// real pixel with margin even when downscaled.
	float coverage = 1 - smoothstep(0, 3, dist);

	float4 texColor = tex2D(SpriteTextureSampler, input.TextureCoordinates);
	float4 color = texColor * input.Color;
	color.a *= coverage;

	return color;
}

technique SpriteDrawing
{
	pass P0
	{
		PixelShader = compile PS_SHADERMODEL MainPS();
	}
};
