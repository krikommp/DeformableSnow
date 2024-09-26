Shader "Unlit/TrailDrawer"
{
    Properties
    {
        _BaseColor ("Example Colour", Color) = (0, 0.66, 0.73, 1)
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        ENDHLSL

        Pass
        {
            Name "Current"
            Tags
            {
                "LightMode"="UniversalForward"
            }

            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #if SHADER_API_GLES
            struct Attributes
            {
                float4 positionOS       : POSITION;
                float2 uv               : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            #else
            struct Attributes
            {
                uint vertexID : SV_VertexID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            #endif

            TEXTURE2D(_FootprintTexture);
            SAMPLER(sampler_FootprintTexture);

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                #if SHADER_API_GLES
                float4 pos = input.positionOS;
                float2 uv  = input.uv;
                #else
                float4 pos = GetFullScreenTriangleVertexPosition(IN.vertexID);
                float2 uv = GetFullScreenTriangleTexCoord(IN.vertexID);
                #endif

                OUT.positionCS = pos;
                OUT.uv = uv;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_FootprintTexture, sampler_FootprintTexture, IN.uv);
                return color;
            }
            ENDHLSL
        }

        Pass
        {
            Name "Trail"
            Tags
            {
                "LightMode"="UniversalForward"
            }

            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "SnowCommmon.hlsl"

            #if SHADER_API_GLES
            struct Attributes
            {
                float4 positionOS       : POSITION;
                float2 uv               : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            #else
            struct Attributes
            {
                uint vertexID : SV_VertexID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            #endif

            CBUFFER_START(UnityPerMaterial)
                float4 _HistoryOffset;
            CBUFFER_END

            TEXTURE2D(_CurrentTexture);
            SAMPLER(sampler_CurrentTexture);
            TEXTURE2D(_HistoryTexture);
            SAMPLER(sampler_HistoryTexture);

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                #if SHADER_API_GLES
                float4 pos = input.positionOS;
                float2 uv  = input.uv;
                #else
                float4 pos = GetFullScreenTriangleVertexPosition(IN.vertexID);
                float2 uv = GetFullScreenTriangleTexCoord(IN.vertexID);
                #endif

                OUT.positionCS = pos;
                OUT.uv = uv;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 currentColor = SAMPLE_TEXTURE2D(_CurrentTexture, sampler_CurrentTexture, IN.uv);

                float2 offset = _HistoryOffset.xy;
                float2 historyUV = IN.uv - offset;

                half4 historyColor = SAMPLE_TEXTURE2D(_HistoryTexture, sampler_HistoryTexture, historyUV);
                // half fade = BoxMask(historyUV, 0.5, 0.8, 0.2);
                float fade = min(SideMask(IN.uv), SideMask(historyUV));
                half mixColor = max(currentColor.r, historyColor.r * fade);
                
                half fallDownColor = mixColor - historyColor.r;
                // fallDownColor = currentColor - mixColor;
                fallDownColor = step(0.01, fallDownColor);
                fallDownColor *= currentColor;

                half historyDown = historyColor.g * fade - (_Time * 0.01);
                historyDown = saturate(historyDown);
                
                fallDownColor = max(fallDownColor, historyDown);

                half4 finalColor = 1.0;
                finalColor.r = mixColor;
                finalColor.g = fallDownColor;

                return finalColor;
            }
            ENDHLSL
        }

        Pass
        {
            Name "Trail"
            Tags
            {
                "LightMode"="UniversalForward"
            }

            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #if SHADER_API_GLES
            struct Attributes
            {
                float4 positionOS       : POSITION;
                float2 uv               : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            #else
            struct Attributes
            {
                uint vertexID : SV_VertexID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            #endif

            TEXTURE2D(_TrailTexture);
            SAMPLER(sampler_TrailTexture);

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                #if SHADER_API_GLES
                float4 pos = input.positionOS;
                float2 uv  = input.uv;
                #else
                float4 pos = GetFullScreenTriangleVertexPosition(IN.vertexID);
                float2 uv = GetFullScreenTriangleTexCoord(IN.vertexID);
                #endif

                OUT.positionCS = pos;
                OUT.uv = uv;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_TrailTexture, sampler_TrailTexture, IN.uv);
                return color;
            }
            ENDHLSL
        }
    }
}