Shader "Unlit/Footprint"
{
    Properties
    {
        _FootprintDepth ("Footprint Depth", Range(0, 1)) = 1.0
        _Hardness ("Hardness", Range(0, 1)) = 1.0
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        half _FootprintDepth;
        half _Hardness;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };


            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = positionInputs.positionCS;
                OUT.uv = IN.uv;
                OUT.color = IN.color;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 pct = IN.uv - 0.5f;
                float distance = length(pct);
                distance *= 2;

                half depth = saturate(_FootprintDepth);
                distance = distance / depth;

                distance *= _Hardness;
                distance = distance - (_Hardness - 1.0);
                
                distance = saturate(distance);
                distance = smoothstep(1, 0, distance);

                half4 color = 1.0f;
                color.xyz = distance;
                color.w = distance;
                
                return color;
            }
            ENDHLSL
        }
    }
}