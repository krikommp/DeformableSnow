Shader "V/URP/Tessellation"
{
    Properties
    {
        _Color("Color(RGB)",Color) = (1,1,1,1)
        _Tess("Tessellation", Range(1, 32)) = 20
        _MaxTessDistance("Max Tess Distance", Range(1, 32)) = 20
        _MinTessDistance("Min Tess Distance", Range(1, 32)) = 1

        _SplatMap("SplatMap", 2D) = "white" {}
        _Displacement("Displacement", Float) = 0.1

        _SnowTex("SnowTex", 2D) = "white" {}
        _SnowColor("SnowColor", Color) = (1, 1, 1, 1)
        _GroundTex("GroundTex", 2D) = "white" {}
        _GroundColor("GroundColor", Color) = (1, 1, 1, 1)
        _NoiseScale("Noise Scale", float) = 1
        _SnowNormal("SnowNormal", 2D) = "bump" {}

        _SpecularColor("SpecularColor",Color)=(1,1,1,1)
        _Smoothness("Smoothness",float)=10

        _HeightMapUVOffset("HeightMap UV Offset", float) = 2.0
        // _TrailLocation("Trail Location", Vector) = (0, 0, 0, 0)
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
            "Queue"="Geometry+0"
        }

        Pass
        {
            Name "Pass"
            Tags {}

            // Render State
            Blend One Zero, One Zero
            Cull Back
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
            #pragma require tessellation
            #pragma require geometry

            #pragma vertex BeforeTessVertProgram
            #pragma hull HullProgram
            #pragma domain DomainProgram
            #pragma fragment FragmentProgram

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 4.6

            // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "SnowCommmon.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _SnowTex_ST;
                float4 _GroundTex_ST;
                float4 _SnowNormal_ST;
                half4 _Color;
                float _Tess;
                float _MaxTessDistance;
                float _MinTessDistance;
                float _Displacement;
                half4 _SnowColor;
                half4 _GroundColor;
                float _NoiseScale;
                float _Smoothness;
                float _HeightMapUVOffset;
                float __;
                float4 _SpecularColor;
                float4 _TrailLocation;
            CBUFFER_END

            TEXTURE2D(_SplatMap);
            SAMPLER(sampler_SplatMap);
            TEXTURE2D(_SnowTex);
            SAMPLER(sampler_SnowTex);
            TEXTURE2D(_GroundTex);
            SAMPLER(sampler_GroundTex);
            TEXTURE2D(_SnowNormal);
            SAMPLER(sampler_SnowNormal);

            #define CurrentLocation _TrailLocation.xyz
            #define CurrentSize _TrailLocation.ww


            // 顶点着色器的输入
            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
                half4 tangentOS : TANGENT;
            };

            // 片段着色器的输入
            struct Varyings
            {
                float4 color : COLOR;
                float3 normalWS : NORMAL;
                float4 vertex : SV_POSITION;
                float3 posWS:TEXCOORD0;
                float3 viewDirWS : TEXCOORD1;
                float4 snowUV : TEXCOORD2;
                float2 groundUV : TEXCOORD3;

                half4 tangentWS : TEXCOORD4;
                half4 bitangentWS : TEXCOORD5;
            };

            // 为了确定如何细分三角形，GPU使用了四个细分因子。三角形面片的每个边缘都有一个因数。
            // 三角形的内部也有一个因素。三个边缘向量必须作为具有SV_TessFactor语义的float数组传递。
            // 内部因素使用SV_InsideTessFactor语义
            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            // 该结构的其余部分与Attributes相同，只是使用INTERNALTESSPOS代替POSITION语意，否则编译器会报位置语义的重用
            struct ControlPoint
            {
                float4 vertex : INTERNALTESSPOS;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
                float3 normal : NORMAL;
                half4 tangentOS : TANGENT;
            };

            float GetHeightMap(float3 posWS)
            {
                float2 splatUV = ((posWS.xz - CurrentLocation.xz) / (2 * CurrentSize)) + float2(0.5, 0.5);
                splatUV = 1.0 - splatUV;
                float fade = Mask(splatUV);

                half amount = _SplatMap.SampleLevel(sampler_SplatMap, splatUV, 0).r * fade;

                return amount;
            }

            float3 NormalFromHeightMap(float heightMapUVOffset, float2 uv, float4 heightMapChannelSelector,
                                       float normalMapIntensity, float fade)
            {
                float2 offsetUV1 = float2(uv.x + heightMapUVOffset, uv.y);
                float2 offsetUV2 = float2(uv.x, uv.y + heightMapUVOffset);

                half4 map1 = _SplatMap.SampleLevel(sampler_SplatMap, uv, 0) * fade;
                half4 map2 = _SplatMap.SampleLevel(sampler_SplatMap, offsetUV1, 0) * fade;
                half4 map3 = _SplatMap.SampleLevel(sampler_SplatMap, offsetUV2, 0) * fade;

                half mask1 = dot(map1, heightMapChannelSelector);
                half mask2 = dot(map2, heightMapChannelSelector);
                half mask3 = dot(map3, heightMapChannelSelector);

                half leftMask = mask2 - mask1;
                half rightMask = mask3 - mask1;

                leftMask *= normalMapIntensity;
                rightMask *= normalMapIntensity;

                return float3(cross(float3(0.0, rightMask, 1.0), float3(1.0, leftMask, 0.0)));
            }

            float3 GetHeightMapNormal(float3 posWS)
            {
                float2 splatUV = ((posWS.xz - CurrentLocation.xz) / (2 * CurrentSize)) + float2(0.5, 0.5);
                splatUV = 1.0 - splatUV;
                float fade = Mask(splatUV);
                float3 normal = NormalFromHeightMap(_HeightMapUVOffset * 0.001, splatUV, float4(1, 0, 0, 0), 2.0, fade);

                return normalize(normal);
            }

            // 顶点着色器，此时只是将Attributes里的数据递交给曲面细分阶段
            ControlPoint BeforeTessVertProgram(Attributes v)
            {
                ControlPoint p;

                p.vertex = v.vertex;
                p.uv = v.uv;
                p.normal = v.normal;
                p.color = v.color;
                p.tangentOS = v.tangentOS;

                return p;
            }

            float CalcDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess)
            {
                float3 worldPosition = TransformObjectToWorld(vertex.xyz);;
                float dist = distance(worldPosition, CurrentLocation);
                float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
                return (f);
            }

            // Patch Constant Function决定Patch的属性是如何细分的。这意味着它每个Patch仅被调用一次，
            // 而不是每个控制点被调用一次。这就是为什么它被称为常量函数，在整个Patch中都是常量的原因。
            // 实际上，此功能是与HullProgram并行运行的子阶段。
            // 三角形面片的细分方式由其细分因子控制。我们在MyPatchConstantFunction中确定这些因素。
            // 当前，我们根据其距离相机的位置来设置细分因子
            TessellationFactors MyPatchConstantFunction(InputPatch<ControlPoint, 3> patch)
            {
                float minDist = _MinTessDistance;
                float maxDist = _MaxTessDistance;

                TessellationFactors f;

                float edge0 = CalcDistanceTessFactor(patch[0].vertex, minDist, maxDist, _Tess);
                float edge1 = CalcDistanceTessFactor(patch[1].vertex, minDist, maxDist, _Tess);
                float edge2 = CalcDistanceTessFactor(patch[2].vertex, minDist, maxDist, _Tess);

                // make sure there are no gaps between different tessellated distances, by averaging the edges out.
                f.edge[0] = (edge1 + edge2) / 2;
                f.edge[1] = (edge2 + edge0) / 2;
                f.edge[2] = (edge0 + edge1) / 2;
                f.inside = (edge0 + edge1 + edge2) / 3;
                return f;
            }

            //细分阶段非常灵活，可以处理三角形，四边形或等值线。我们必须告诉它必须使用什么表面并提供必要的数据。
            //这是 hull 程序的工作。Hull 程序在曲面补丁上运行，该曲面补丁作为参数传递给它。
            //我们必须添加一个InputPatch参数才能实现这一点。Patch是网格顶点的集合。必须指定顶点的数据格式。
            //现在，我们将使用ControlPoint结构。在处理三角形时，每个补丁将包含三个顶点。此数量必须指定为InputPatch的第二个模板参数
            //Hull程序的工作是将所需的顶点数据传递到细分阶段。尽管向其提供了整个补丁，
            //但该函数一次仅应输出一个顶点。补丁中的每个顶点都会调用一次它，并带有一个附加参数，
            //该参数指定应该使用哪个控制点（顶点）。该参数是具有SV_OutputControlPointID语义的无符号整数。
            [domain("tri")] //明确地告诉编译器正在处理三角形，其他选项：
            [outputcontrolpoints(3)] //明确地告诉编译器每个补丁输出三个控制点
            [outputtopology("triangle_cw")] //当GPU创建新三角形时，它需要知道我们是否要按顺时针或逆时针定义它们
            [partitioning("fractional_odd")] //告知GPU应该如何分割补丁，现在，仅使用整数模式
            [patchconstantfunc("MyPatchConstantFunction")]
            //GPU还必须知道应将补丁切成多少部分。这不是一个恒定值，每个补丁可能有所不同。必须提供一个评估此值的函数，称为补丁常数函数（Patch Constant Functions）
            ControlPoint HullProgram(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

            Varyings AfterTessVertProgram(Attributes v)
            {
                float3 posWS = TransformObjectToWorld(v.vertex);
                float d = GetHeightMap(posWS);
                v.vertex.xyz -= v.normal * d * _Displacement;
                v.vertex.xyz += v.normal * _Displacement;

                Varyings o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.snowUV.xy = TRANSFORM_TEX(v.uv, _SnowTex);
                o.snowUV.zw = TRANSFORM_TEX(v.uv, _SnowNormal);
                o.groundUV = TRANSFORM_TEX(v.uv, _GroundTex);
                o.posWS = TransformObjectToWorld(v.vertex);
                o.viewDirWS = GetCameraPositionWS() - o.posWS;
                o.normalWS = v.normal;
                o.tangentWS.xyz = TransformObjectToWorldDir(v.tangentOS.xyz);
                half sign = v.tangentOS.w * GetOddNegativeScale();
                o.bitangentWS.xyz = cross(o.normalWS, o.tangentWS) * sign;
                o.color = v.color;

                return o;
            }

            //HUll着色器只是使曲面细分工作所需的一部分。一旦细分阶段确定了应如何细分补丁，
            //则由Domain着色器来评估结果并生成最终三角形的顶点。
            //Domain程序将获得使用的细分因子以及原始补丁的信息，原始补丁在这种情况下为OutputPatch类型。
            //细分阶段确定补丁的细分方式时，不会产生任何新的顶点。相反，它会为这些顶点提供重心坐标。
            //使用这些坐标来导出最终顶点取决于域着色器。为了使之成为可能，每个顶点都会调用一次域函数，并为其提供重心坐标。
            //它们具有SV_DomainLocation语义。
            //在Demain函数里面，我们必须生成最终的顶点数据。
            [domain("tri")] //Hull着色器和Domain着色器都作用于相同的域，即三角形。我们通过domain属性再次发出信号
            Varyings DomainProgram(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch,
                                               float3 barycentricCoordinates :
                                               SV_DomainLocation)
            {
                Attributes v;

                //为了找到该顶点的位置，我们必须使用重心坐标在原始三角形范围内进行插值。
                //X，Y和Z坐标确定第一，第二和第三控制点的权重。
                //以相同的方式插值所有顶点数据。让我们为此定义一个方便的宏，该宏可用于所有矢量大小。
                #define DomainInterpolate(fieldName) v.fieldName = \
                        patch[0].fieldName * barycentricCoordinates.x + \
                        patch[1].fieldName * barycentricCoordinates.y + \
                        patch[2].fieldName * barycentricCoordinates.z;

                //对位置、颜色、UV、法线等进行插值
                    DomainInterpolate(vertex)
                    DomainInterpolate(uv)
                    DomainInterpolate(color)
                    DomainInterpolate(normal)
                    DomainInterpolate(tangentOS)

                //现在，我们有了一个新的顶点，该顶点将在此阶段之后发送到几何程序或插值器。
                //但是这些程序需要Varyings数据，而不是Attributes。为了解决这个问题，
                //我们让域着色器接管了原始顶点程序的职责。
                //这是通过调用其中的AfterTessVertProgram（与其他任何函数一样）并返回其结果来完成的。
                return AfterTessVertProgram(v);
            }

            // 片段着色器
            half4 FragmentProgram(Varyings i) : SV_TARGET
            {
                float3 normalWS = TransformObjectToWorldNormal(GetHeightMapNormal(i.posWS));
                //法线相关------------
                // half3 normalMap = UnpackNormal(SAMPLE_TEXTURE2D(_SnowNormal, sampler_SnowNormal, i.snowUV.zw));
                // half3 normalWS = mul(normalMap, half3x3(i.tangentWS.xyz, i.bitangentWS.xyz, normal.xyz));

                half amount = GetHeightMap(i.posWS);

                half4 snow = SAMPLE_TEXTURE2D(_SnowTex, sampler_SnowTex, i.snowUV.xy) * _SnowColor;
                half4 ground = SAMPLE_TEXTURE2D(_GroundTex, sampler_GroundTex, i.groundUV) * _GroundColor;
                // half amount = SAMPLE_TEXTURE2D(_SplatMap, sampler_SplatMap, i.uv).r;
                half4 c = lerp(snow, ground, amount);

                //计算主光
                Light light = GetMainLight();
                half3 diffuse = LightingLambert(light.color, light.direction, normalWS);
                half3 specular = LightingSpecular(light.color, light.direction, normalize(normalWS),
                               normalize(i.viewDirWS), _SpecularColor,
                               _Smoothness);
                //计算附加光照
                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0; lightIndex < pixelLightCount; ++lightIndex)
                {
                    Light light = GetAdditionalLight(lightIndex, i.posWS);
                    diffuse += LightingLambert(light.color, light.direction, normalWS);
                    specular += LightingSpecular(light.color, light.direction, normalize(normalWS),
                       normalize(i.viewDirWS), _SpecularColor,
                       _Smoothness);
                }
                
                half3 color = c.xyz * diffuse + specular;

                float2 splatUV = ((i.posWS.xz - CurrentLocation.xz) / (2 * CurrentSize)) + float2(0.5, 0.5);
                splatUV = 1.0 - splatUV;
                float fade = Mask(splatUV);

                half mask = _SplatMap.SampleLevel(sampler_SplatMap, splatUV, 0).r * fade;
                half ccc = fade - mask;

                return half4(color, 1.0);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            ZWrite On
            ZTest LEqual
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _GLOSSINESS_FROM_BASE_ALPHA

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment


            //由于这段代码中声明了自己的CBUFFER，与我们需要的不一样，所以我们注释掉他
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitInput.hlsl"
            //它还引入了下面2个hlsl文件
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}