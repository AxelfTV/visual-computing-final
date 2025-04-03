Shader"Custom/sdf_test"
{
    Properties
    {
        _Color ("Color", Color) = (1,0,0,1)
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

            float4 _Color;
            int _MaxSteps;
            float _Epsilon;
            float _MaxDistance;
            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;

            // Signed Distance Function (SDF) for a Sphere
            float getNoise(float x, float z)
            {
                float hMult = 1 + sin(_Time.x * 30) / 2;
                return hMult * (tex2Dlod(_NoiseTex, float4(x * 0.1,z * 0.1, 0, 0)).r - 0.5);
            }
            float sdfTerrain(float3 p)
            {
                p.x += _Time.y;
                
                float height = getNoise(p.x, p.z);
                return p.y - height;
            }
            float sdfCeiling(float3 p)
            {
                return 0.25 * (sin(p.x * 2) + cos(p.z * 2)) + 5 - p.y;
            }
            float sdfTorus(float3 p, float3 o, float2 t)
            {
                p -= o;
                p = float3(p.x, p.z, -p.y);
                
                float2 q = float2(length(p.xz) - t.x, p.y);
                return length(q) - t.y;
            }

            // Raymarching function
            float raymarch(float3 ro, float3 rd)
            {
                float distanceTraveled = 0.0;
                
                for (int i = 0; i < _MaxSteps; i++)
                {
                    float3 currentPos = ro + rd * distanceTraveled;
                    float d = sdfTerrain(currentPos);

                    if (d < _Epsilon) return distanceTraveled; // Hit the sphere
                    if (distanceTraveled > _MaxDistance) return -1.0; // Too far

                    distanceTraveled += d; // Move forward
                }
                return -1.0; // No hit
            }
            float3 estimateNormal(float3 p)
            {
                float eps = 0.001; // Small step size
                
                float3 n = float3(
                    sdfTerrain(float3(p.x + eps, p.y, p.z)) - sdfTerrain(float3(p.x - eps, p.y, p.z)),
                    sdfTerrain(float3(p.x, p.y + eps, p.z)) - sdfTerrain(float3(p.x, p.y - eps, p.z)),
                    sdfTerrain(float3(p.x, p.y, p.z + eps)) - sdfTerrain(float3(p.x, p.y, p.z - eps))
                );
                return normalize(n);
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
    float3 ro = _WorldSpaceCameraPos; // Ray origin (camera position)
    float3 rd = normalize(i.viewDir); // Ray direction

    float dist = raymarch(ro, rd);

    if (dist < 0.0)
        return fixed4(0, 0, 0, 0); // No hit = transparent

    float3 hitPos = ro + rd * dist; // Get the exact hit position

    // Compute normal (assumes a function to approximate surface normal)
    float3 normal = getTerrainNormal(hitPos);

    // Define angled light direction (adjust as needed)
    float3 lightDir = normalize(float3(1, 1, 0)); // Light coming from an angle

    // Compute Lambertian shading
    float shading = 0.1 + max(dot(normal, lightDir), 0.0);

    // Apply shading to color
    return fixed4(_Color.rgb * shading, 1.0); // Final color
}   
            ENDCG
        }
    }
}
