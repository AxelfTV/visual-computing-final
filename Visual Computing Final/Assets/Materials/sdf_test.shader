Shader"Custom/sdf_test"
{
    Properties
    {
        _OceanColour ("Ocean Colour", Color) = (1,1,1,1)
        _BoatColour ("Boat Colour", Color) = (1,1,1,1)
        _MaxSteps ("Max Steps", Int) = 200
        _Epsilon ("Epsilon", Float) = 0.001
        _MaxDistance ("Max Distance", Float) = 20.0
        _NoiseTex ("Noise Texture", 2D) = "white" {} 
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha // Enable transparency

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
            };

            int _MaxSteps;
            float _Epsilon;
            float _MaxDistance;
            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;
            float3 _BoatPosition;

            float4 _OceanColour;
            float4 _BoatColour;

            // Signed Distance Function (SDF) for a Sphere
            float getNoise(float x, float z)
            {
                float xOffset = _Time.y;
                float zOffset = 0;
                float hMult = 1 + sin(_Time.x * 30) / 2;
                return hMult * (tex2Dlod(_NoiseTex, float4((x+xOffset) * 0.1,(z+zOffset) * 0.1, 0, 0)).r - 0.5);
            }
            float4 sdfSphere(float3 p)
            {
                p -= _BoatPosition;
                return float4(_BoatColour.rgb,length(p)-0.2);
            }
            float4 sdfTerrain(float3 p)
            {
                float height = getNoise(p.x, p.z);
                return float4(_OceanColour.rgb,p.y - height);
            }
            

            // Raymarching function
            float4 raymarch(float3 ro, float3 rd)
            {
                float distanceTraveled = 0.0;
                
                for (int i = 0; i < _MaxSteps; i++)
                {
                    float3 currentPos = ro + rd * distanceTraveled;

                    float4 boat = sdfSphere(currentPos);
                    float4 terrain = sdfTerrain(currentPos);
                    float4 result;

                    if(boat.w < terrain.w) result = boat;
                    else result = terrain;

                    float d = result.w;

                    if (d < _Epsilon) return float4(result.xyz,distanceTraveled); // Hit the sphere
                    if (distanceTraveled > _MaxDistance) return float4(0,0,0,-1.0); // Too far

                    distanceTraveled += d; // Move forward
                }
                return float4(0,0,0,-1.0); // No hit
            }
            float3 getTerrainNormal(float3 p)
            {
                float epsilon = 0.05;
                float n = getNoise(p.x, p.z);
                float3 u = float3(p.x + epsilon, getNoise(p.x + epsilon, p.z), p.z) - p;
                float3 v = float3(p.x + epsilon, getNoise(p.x, p.z + epsilon), p.z + epsilon) - p;
                return normalize(cross(v, u));
    

            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                
                float3 camPos = _WorldSpaceCameraPos;
                o.viewDir = normalize(o.worldPos - camPos);
                
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 ro = _WorldSpaceCameraPos;
                float3 rd = normalize(i.viewDir);

                float4 rm = raymarch(ro, rd);
                float dist = rm.w;

                if (dist < 0.0)
                return fixed4(0, 0, 0, 0);

                float3 hitPos = ro + rd * dist;

                float3 lightDir = normalize(float3(1.0, 1.0, 0.0));

                if(all(rm.rgb == _OceanColour.rgb))
                {
                    float3 normal = getTerrainNormal(hitPos);
                    float shading = 0.1 + max(dot(normal, lightDir), 0.0);
                    return fixed4(rm.rgb * shading, 1.0);
                }
                else
                {
                    return fixed4(rm.rgb,1.0);
                }
                

                
            }   
            ENDCG
        }
    }
}
