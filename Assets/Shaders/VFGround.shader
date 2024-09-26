Shader "azhao/VFGround"
{
    Properties
    {
		_MainTex("Texture", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_centerPos("CenterPos", Vector) = (0,0,0,0)
		_minDis("minVal", Float) = 0
		_maxDis("maxVal", Float) = 20
		_factor("factor", Float) = 15
		_footstepRect("footstepRect",Vector) = (0,0,0,0)
		_footstepTex("footstepTex",2D) = "gray"{}
		_height("height" ,Float) = 0.3
		_NormalTex("Normal Tex", 2D) = "black"{}
		_normalScale("normalScale", Range(-1 , 1)) = 0
		_specColor("SpecColor",Color) = (1,1,1,1)
		_shininess("shininess", Range(1 , 100)) = 1
		_specIntensity("specIntensity",Range(0,1)) = 1
		_ambientIntensity("ambientIntensity",Range(0,1)) = 1


    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
			//在正常的vertex和fragment之间还需要hull和domain，所以在这里加上声明
			#pragma hull hullProgram
			#pragma domain domainProgram
            #pragma fragment frag


            #include "UnityCG.cginc"
			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;
			uniform float _minDis;
			uniform float _maxDis;
			uniform float3 _centerPos;
			uniform float _factor;
			float4 _footstepRect;
			sampler2D _footstepTex;
			float _height;
			sampler2D _NormalTex;
			float4 _NormalTex_ST;
			float _normalScale;
			float4 _specColor;
			float _shininess;
			float _specIntensity;
			float _ambientIntensity;
			struct a2v
			{
				float4 pos	: POSITION;
				float2 uv  : TEXCOORD0;
				float3 normal:NORMAL;
				float3 tangent:TANGENT;
			};

			struct v2t
			{				
				float2 uv  : TEXCOORD0;
				float2 footstepUV : TEXCOORD1;
				float4 worldPos	: TEXCOORD2;
				float3 worldNormal : TEXCOORD3;
				float3 worldTangent :TEXCOORD4;
				float3 worldBitangent : TEXCOORD5;
			};
			struct t2f
			{
				float4 clipPos:SV_POSITION;
				float2 uv: TEXCOORD0;				
				float2 footstepUV:TEXCOORD1;
				float4 worldPos:TEXCOORD2;
				float3 worldNormal : TEXCOORD3;
				float3 worldTangent :TEXCOORD4;
				float3 worldBitangent : TEXCOORD5;
				
			};

			struct TessOut
			{
				float2 uv  : TEXCOORD0;
				float4 worldPos	: TEXCOORD1;
				float2 footstepUV:TEXCOORD2;
				float3 worldNormal : TEXCOORD3;
				float3 worldTangent :TEXCOORD4;
				float3 worldBitangent : TEXCOORD5;
				
			};
			struct TessParam
			{
				float EdgeTess[3]	: SV_TessFactor;//各边细分数
				float InsideTess : SV_InsideTessFactor;//内部点细分数
			};

			float RemapUV(float min, float max, float val)
			{
				return (val - min) / (max - min);
			}
			half3 UnpackScaleNormal(half4 packednormal, half bumpScale)
			{
				half3 normal;
				//由于法线贴图代表的颜色是0到1，而法线向量的范围是-1到1
				//所以通过*2-1,把色值范围转换到-1到1
				normal = packednormal * 2 - 1;
				//对法线进行缩放
				normal.xy *= bumpScale;
				//向量标准化
				normal = normalize(normal);
				return normal;
			}
			//获取Lambert漫反射值
			float GetLambertDiffuse(float3 worldPos, float3 worldNormal)
			{
				float3 lightDir = UnityWorldSpaceLightDir(worldPos);
				float NDotL = saturate(dot(worldNormal, lightDir));
				
				return NDotL;
			}

			//获取BlinnPhong高光
			float GetBlinnPhongSpec(float3 worldPos, float3 worldNormal)
			{
				float3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				float3 halfDir = normalize((viewDir + _WorldSpaceLightPos0.xyz));
				float specDir = max(dot(normalize(worldNormal), halfDir), 0);
				float specVal = pow(specDir, _shininess);
				return specVal;
			}

			v2t vert(a2v i)
			{
				v2t o;
				o.worldPos = mul(unity_ObjectToWorld,i.pos);
				o.uv = i.uv;
				o.footstepUV = float2(RemapUV(_footstepRect.x, _footstepRect.z, o.worldPos.x), RemapUV(_footstepRect.y, _footstepRect.w, o.worldPos.z));
				o.worldNormal = UnityObjectToWorldNormal(i.normal);
				o.worldTangent = UnityObjectToWorldDir(i.tangent);
				o.worldBitangent = cross(o.worldNormal, o.worldTangent);
				return o;
			}
			//在hullProgram之前必须设置这些参数，不然会报错
			[domain("tri")]//图元类型,可选类型有 "tri", "quad", "isoline"
			[partitioning("integer")]//曲面细分的过渡方式是整数还是小数
			[outputtopology("triangle_cw")]//三角面正方向是顺时针还是逆时针
			[outputcontrolpoints(3)]//输出的控制点数
			[patchconstantfunc("ConstantHS")]//对应之前的细分因子配置阶段的方法名
			[maxtessfactor(64.0)]//最大可能的细分段数

			//vert顶点程序之后调用，计算细分前的三角形顶点信息
			TessOut hullProgram(InputPatch<v2t, 3> i, uint idx : SV_OutputControlPointID)
			{
				TessOut o;
				o.worldPos = i[idx].worldPos;
				o.uv = i[idx].uv;
				o.footstepUV = i[idx].footstepUV;
				o.worldNormal = i[idx].worldNormal;
				o.worldTangent = i[idx].worldTangent;
				o.worldBitangent = i[idx].worldBitangent;
				return o;
			}

			//指定每个边的细分段数和内部细分段数
			TessParam ConstantHS(InputPatch<v2t, 3> i, uint id : SV_PrimitiveID)
			{
				TessParam o;
				float4 worldPos = (i[0].worldPos + i[1].worldPos + i[2].worldPos) / 3;
				float smoothstepResult = smoothstep(_minDis, _maxDis, distance(worldPos.xz, _centerPos.xz));
				float fac = max((1.0 - smoothstepResult)*_factor, 1);
				//由于我这里是根据指定的中心点和半径范围来动态算细分段数，所以才有这个计算，不然可以直接指定变量来设置。
				o.EdgeTess[0] = fac;
				o.EdgeTess[1] = fac;
				o.EdgeTess[2] = fac;
				o.InsideTess = fac;
				return o;
			}

			//在domainProgram前必须设置domain参数，不然会报错
			[domain("tri")]
			//细分之后，把信息传到frag片段程序
			t2f domainProgram(TessParam tessParam, float3 bary : SV_DomainLocation, const OutputPatch<TessOut, 3> i)
			{
				t2f o;				
				//线性转换

				float2 uv = i[0].uv * bary.x + i[1].uv * bary.y + i[2].uv * bary.z;
				o.uv = uv;
				o.footstepUV = i[0].footstepUV * bary.x + i[1].footstepUV * bary.y + i[2].footstepUV * bary.z;
				float4 footstepCol = tex2Dlod(_footstepTex, float4(o.footstepUV, 0, 0.0));
				float addVal = footstepCol.a*_height;

				float4 worldPos = i[0].worldPos * bary.x + i[1].worldPos * bary.y + i[2].worldPos * bary.z;
				worldPos.y = worldPos.y - addVal;
				o.worldPos = worldPos;
				o.clipPos = UnityWorldToClipPos(worldPos);
				o.worldNormal = i[0].worldNormal * bary.x + i[1].worldNormal * bary.y + i[2].worldNormal * bary.z;
				o.worldTangent = i[0].worldTangent * bary.x + i[1].worldTangent * bary.y + i[2].worldTangent * bary.z;
				o.worldBitangent = i[0].worldBitangent * bary.x + i[1].worldBitangent * bary.y + i[2].worldBitangent * bary.z;
				return o;
			}
            fixed4 frag (t2f i) : SV_Target
            {
    //            // sample the texture
				//float2 mainUV = i.uv*_MainTex_ST.xy + _MainTex_ST.zw;
    //            fixed4 col = tex2D(_MainTex, mainUV)*_Color;
				//fixed4 footstepCol = tex2D(_footstepTex, i.footstepUV);
				//fixed3 footstepRGB = fixed3(footstepCol.r - 0.5, footstepCol.g - 0.5, footstepCol.b - 0.5);
				//footstepRGB = footstepRGB * footstepCol.a;
				//fixed4 finalCol = col;// fixed4(saturate(col.rgb + footstepRGB), 1);
    //            return finalCol;
				//采样漫反射贴图的颜色
				half4 col = tex2D(_MainTex, i.uv*_MainTex_ST.xy + _MainTex_ST.zw);
				//计算法线贴图的UV
				half2 normalUV = i.uv * _NormalTex_ST.xy + _NormalTex_ST.zw;
				//采样法线贴图的颜色
				half4 normalCol = tex2D(_NormalTex, normalUV);

				fixed4 footstepCol = tex2D(_footstepTex, i.footstepUV);
				fixed3 footstepRGB = UnpackScaleNormal(footstepCol*footstepCol.a, _normalScale).rgb;

				//得到切线空间的法线方向
				half3 normalVal = UnpackScaleNormal(normalCol, _normalScale).rgb;
				//normalVal = footstepRGB;
				//normalVal = normalize(normalVal + footstepRGB);
				normalVal -= footstepRGB;
				//构建TBN矩阵
				float3 tanToWorld0 = float3(i.worldTangent.x, i.worldBitangent.x, i.worldNormal.x);
				float3 tanToWorld1 = float3(i.worldTangent.y, i.worldBitangent.y, i.worldNormal.y);
				float3 tanToWorld2 = float3(i.worldTangent.z, i.worldBitangent.z, i.worldNormal.z);

				//通过切线空间的法线方向和TBN矩阵，得出法线贴图代表的物体世界空间的法线方向
				float3 worldNormal = float3(dot(tanToWorld0, normalVal), dot(tanToWorld1, normalVal), dot(tanToWorld2, normalVal));

				//用法线贴图的世界空间法线，算漫反射
				half diffuseVal = GetLambertDiffuse(i.worldPos, worldNormal);
				diffuseVal = clamp(diffuseVal, 0.6, 1);
				diffuseVal = pow(diffuseVal, 1.5);

				//用法线贴图的世界空间法线，算高光角度
				half3 specCol = _specColor * GetBlinnPhongSpec(i.worldPos, worldNormal)*_specIntensity;

				//最终颜色 = 环境色+漫反射颜色+高光颜色
				half3 finalCol = UNITY_LIGHTMODEL_AMBIENT * _ambientIntensity + saturate(col.rgb*diffuseVal) + specCol;
				return half4(finalCol,1);
            }
            ENDCG
        }
    }
}
