#include "shader/math.fxsub"
#include "shader/common.fxsub"
#include "shader/phase.fxsub"
#include "shader/fog.fxsub"

#include "../../shader/gbuffer.fxsub"
#include "../../shader/gbuffer_sampler.fxsub"

void ScatteringFogVS(
	in float4 Position : POSITION,
	in float2 Texcoord : TEXCOORD0,
	out float3 oTexcoord0 : TEXCOORD0,
	out float4 oTexcoord1  : TEXCOORD1,
	out float4 oPosition : POSITION)
{
	oTexcoord0 = normalize(Position.xyz - CameraPosition);
	oTexcoord1 = oPosition = mul(Position, matWorldViewProject);
	oTexcoord1.xy = PosToCoord(oTexcoord1.xy / oTexcoord1.w) + ViewportOffset;
	oTexcoord1.xy = oTexcoord1.xy * oTexcoord1.w;
}

float4 ScatteringFogPS(
	in float3 viewdir  : TEXCOORD0,
	in float4 texcoord : TEXCOORD1) : COLOR
{
	float2 coord = texcoord.xy / texcoord.w;

	float4 MRT5 = tex2Dlod(Gbuffer5Map, float4(coord, 0, 0));
	float4 MRT6 = tex2Dlod(Gbuffer6Map, float4(coord, 0, 0));
	float4 MRT7 = tex2Dlod(Gbuffer7Map, float4(coord, 0, 0));
	float4 MRT8 = tex2Dlod(Gbuffer8Map, float4(coord, 0, 0));

	MaterialParam materialAlpha;
	DecodeGbuffer(MRT5, MRT6, MRT7, MRT8, materialAlpha);

	float3 sum1 = materialAlpha.albedo + materialAlpha.specular;
	clip(dot(sum1, 1.0) - 1e-5);

	float3 V = normalize(viewdir);

	float scaling = 1000;

	ScatteringParams setting;
	setting.sunSize = mSunRadius;
	setting.sunRadiance = mSunRadiance;
	setting.mieG = mMiePhase;
	setting.mieHeight = mMieHeight * scaling;
	setting.rayleighHeight = mRayleighHeight * scaling;
	setting.earthRadius = 6360 * scaling;
	setting.earthAtmTopRadius = 6380 * scaling;
	setting.earthCenter = float3(0, -setting.earthRadius, 0);
	setting.waveLambdaMie = ComputeWaveLengthMie(mWaveLength, mMieColor, mMieTurbidity * scaling, 3);
	setting.waveLambdaRayleigh = ComputeWaveLengthRayleigh(mWaveLength) * mRayleighColor;
	setting.fogRange = mFogRange;
	
	float3 fog = ComputeFogChapman(setting, CameraPosition + float3(0, scaling, 0), V, LightDirection, materialAlpha.linearDepth);

	return float4(fog, 0);
}

#define OBJECT_TEC(name, mmdpass) \
	technique name<string MMDPass = mmdpass;>{\
		pass DrawObject {\
			ZEnable = false; ZWriteEnable = false;\
			AlphaBlendEnable = true; AlphaTestEnable = false;\
			SrcBlend = ONE; DestBlend = ONE;\
			CullMode = NONE;\
			VertexShader = compile vs_3_0 ScatteringFogVS();\
			PixelShader  = compile ps_3_0 ScatteringFogPS();\
		}\
	}

OBJECT_TEC(FogTec0, "object")
OBJECT_TEC(FogTecBS0, "object_ss")

technique EdgeTec<string MMDPass = "edge";>{}
technique ShadowTech<string MMDPass = "shadow";>{}
technique ZplotTec<string MMDPass = "zplot";>{}
technique MainTec1<string MMDPass = "object";>{}
technique MainTecBS1<string MMDPass = "object_ss";>{}