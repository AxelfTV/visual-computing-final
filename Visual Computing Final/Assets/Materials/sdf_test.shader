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
            float3 _BoatForward;
            float3 _BoatUp;
            float4 _OceanColour;
            float4 _BoatColour;

            //Noise Parameters
            float _Scale;
            float _Lacunarity;
            float _Persistance;
            float _HeightMult;
            int _Octaves;
            float _XOffset;
            float _ZOffset;
            

     
            
            float sampleNoiseTexture(float x, float z)
            {
                return tex2Dlod(_NoiseTex, float4(x ,z, 0, 0)).r -0.5;
            }
            float getComplexNoise(float x, float z)
            {
                x += _XOffset;
                z += _ZOffset;
                float noiseSum = 0;
                for(int i = 0; i < _Octaves; i++)
                {
                    float xn = x/(_Scale * pow(_Lacunarity,i));
                    float zn = z/(_Scale * pow(_Lacunarity,i));

                    noiseSum += sampleNoiseTexture(xn, zn ) * (pow(_Persistance,i));
                }
                return _HeightMult * noiseSum;
            }
            
            float4 sdfSphere(float3 p)
            {
                p -= _BoatPosition;
                return float4(_BoatColour.rgb,length(p)-0.2);
            }
            float4 sdfTriPrism( float3 p)
            {
                p -= _BoatPosition;
                float3 forward = _BoatForward;
                float3 up = _BoatUp;
                float3 right = normalize(cross(up, forward));
                

                // Inverse rotation matrix (transpose of orthonormal basis)
                float3x3 invRot = float3x3(right, up, forward); // right, up, forward as rows

                // Rotate the point into local object space
                p = mul(invRot, p);

                float2 h = 0.4;
                float3 q = abs(p);
                return float4(_BoatColour.rgb,max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5));
            }
            float4 sdfTerrain(float3 p)
            {
                float height = getComplexNoise(p.x, p.z);
                return float4(_OceanColour.rgb, p.y - height);
            }
            float4 sdfBoat(float3 p)
            {
                return sdfTriPrism(p);

            }

            // Raymarching function
            float4 raymarch(float3 ro, float3 rd)
            {
                float distanceTraveled = 0.0;
                
                for (int i = 0; i < _MaxSteps; i++)
                {
                    float3 currentPos = ro + rd * distanceTraveled;

                    float4 boat = sdfTriPrism(currentPos);
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
                float n = getComplexNoise(p.x, p.z);
                float3 u = float3(epsilon, getComplexNoise(p.x + epsilon, p.z) - n, 0);
                float3 v = float3(0, getComplexNoise(p.x, p.z + epsilon) - n, epsilon);
                return normalize(cross(v, u));
            }
            float3 getBoatNormal(float3 currentPos)
            {
                float2 e = float2(1.0,-1.0) * 0.5773;
                float eps = 0.0005;
                return normalize(e.xyy * sdfBoat(currentPos + e.xyy * eps).w + 
                                 e.yyx * sdfBoat(currentPos + e.yyx * eps).w + 
                                 e.yxy * sdfBoat(currentPos + e.yxy * eps).w + 
                                 e.xxx * sdfBoat(currentPos + e.xxx * eps).w);
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
    
                float normal;
    
                if(all(rm.rgb == _OceanColour.rgb)) normal = getTerrainNormal(hitPos);
                    
                else normal = getBoatNormal(hitPos);
    
                float shading = 0.1 + max(dot(normal, lightDir), 0.0);
                return fixed4(rm.rgb * shading, 1.0);

                
            }   
            ENDCG
        }
    }
}
