Shader "Custom/sdf_test"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _Radius ("Radius", Float) = 0.5
        _MaxSteps ("Max Steps", Int) = 100
        _Epsilon ("Epsilon", Float) = 0.001
        _MaxDistance ("Max Distance", Float) = 10.0
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
            float _Radius;
            int _MaxSteps;
            float _Epsilon;
            float _MaxDistance;

            // Signed Distance Function (SDF) for a Sphere
            float sdfSphere(float3 p, float r)
            {
                return length(p) - r;
            }

            // Raymarching function
            float raymarch(float3 ro, float3 rd)
            {
                float distanceTraveled = 0.0;
                
                for (int i = 0; i < _MaxSteps; i++)
                {
                    float3 currentPos = ro + rd * distanceTraveled;
                    float d = sdfSphere(currentPos, _Radius);

                    if (d < _Epsilon) return distanceTraveled; // Hit the sphere
                    if (distanceTraveled > _MaxDistance) return -1.0; // Too far

                    distanceTraveled += d; // Move forward
                }
                return -1.0; // No hit
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

            fixed4 frag (v2f i) : SV_Target
            {
                float3 ro = _WorldSpaceCameraPos; // Ray origin (camera position)
                float3 rd = normalize(i.viewDir); // Ray direction

                float dist = raymarch(ro, rd);

                if (dist < 0.0) return fixed4(0, 0, 0, 0); // No hit = transparent

                float3 hitPos = ro + rd * dist; // Get the exact hit position

                // Simple shading based on normal (gradient effect)
                float3 normal = normalize(hitPos);
                float shading = dot(normal, float3(0,1,0)) * 0.5 + 0.5; // Fake lighting

                return fixed4(_Color.rgb * shading, 1.0); // Final color
            }
            ENDCG
        }
    }
}
