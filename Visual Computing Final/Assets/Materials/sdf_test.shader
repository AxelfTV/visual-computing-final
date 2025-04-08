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
            Blend SrcAlpha OneMinusSrcAlpha

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
            float opSmoothUnion(float d1, float d2, float k)
            {
                float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
                return lerp(d2, d1, h) - k * h * (1.0 - h);
            }
            float4 sdfSphere(float3 p)
            {
                p -= _BoatPosition;
                return float4(_BoatColour.rgb,length(p)-0.2);
            }
            float4 sdfCylinder(float3 p, float h, float r)
            {
                float2 d = abs(float2(length(p.xz), p.y))-float2(r,h);
                return float4(_BoatColour.rgb,min(max(d.x,d.y),0.0) + length(max(d,0.0)));
            }
            float4 sdfTriPrism( float3 p)
            {
                
                float2 h = 0.4;
                float3 q = abs(p);
                return float4(_BoatColour.rgb,max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5));
            }
            float4 sdfEllipsoid( float3 p, float3 r )
            {
                float k0 = length(p/r);
                float k1 = length(p/(r*r));
                return float4(_BoatColour.rgb,k0*(k0-1.0)/k1);
            }
            float4 sdfTerrain(float3 p)
            {
                float height = getComplexNoise(p.x, p.z);
                return float4(_OceanColour.rgb, p.y - height);
            }
            float4 sdfMast(float3 p)
            {
                float4 main = sdfCylinder(p,0.2,0.025);
                float4 side = sdfCylinder(p.yxz + float3(-0.1,0.0,0.0), 0.15,0.025);
                if(main.w < side.w) return main;
                else return side;
            }
            float4 sdfBoatBody(float3 p)
            {
                float4 l1 = sdfEllipsoid(p, float3(0.15,0.1,0.4));
                float4 l2 = sdfEllipsoid(p + float3(0.0,-0.05,0.0), float3(0.2,0.05,0.45));
                return float4(_BoatColour.rgb,opSmoothUnion(l1.w,l2.w, 0.3));
                if(l1.w < l2.w) return l1;
                else return l2;
            }
            float4 sdfBoat(float3 p)
            {
                p -= _BoatPosition;
                float3 forward = _BoatForward;
                float3 up = _BoatUp;
                float3 right = normalize(cross(up, forward));
                
                float3x3 invRot = float3x3(right, up, forward);

                p = mul(invRot, p);

                float4 body = sdfBoatBody(p + float3(0.0,-0.1,0.0));
                float4 mast = sdfMast(p + float3(0.0,-0.45,0.0));
                if(body.w < mast.w) return body;
                else return mast;
            }

            float4 raymarch(float3 ro, float3 rd)
            {
                float distanceTraveled = 0.0;
                
                for (int i = 0; i < _MaxSteps; i++)
                {
                    float3 currentPos = ro + rd * distanceTraveled;

                    float4 boat = sdfBoat(currentPos);
                    float4 terrain = sdfTerrain(currentPos);
                    float4 result;
                    
                    if(boat.w < terrain.w) result = boat;
                    else result = terrain;

                    float d = result.w;

                    if (d < _Epsilon) return float4(result.xyz,distanceTraveled);
                    if (distanceTraveled > _MaxDistance) return float4(0,0,0,-1.0);

                    distanceTraveled += d;
                }
                return float4(0,0,0,-1.0);
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
