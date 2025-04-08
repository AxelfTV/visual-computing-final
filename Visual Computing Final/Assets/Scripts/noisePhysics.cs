using UnityEngine;

public class noisePhysics : MonoBehaviour
{
	[SerializeField] Texture2D noiseTex;
	[SerializeField] Material sdfShader;

	Vector3 velocity = Vector3.zero;

	Vector3 boatUp = Vector3.up;
	[Header("Boat Physics Paramters")]
	[SerializeField] Vector3 dest = Vector3.zero;
	[SerializeField] float gravity = 1;
	[SerializeField] float waveForceMult = 1;
	[SerializeField] float bouyancyMult = 1;
	[SerializeField] float destForceMult = 1;

	[Header("Noise Parameters")]
	[SerializeField] float scale = 1;
	[SerializeField] float lacunarity = 1;
	[SerializeField] float persistance = 1;
	[SerializeField] float heightMult = 1;
	[SerializeField] int octaves = 1;
	[SerializeField] float xOffset = 0;
	[SerializeField] float zOffset = 0;

	private void Start()
	{
		transform.position = dest;
		SetShaderNoiseParams();
	}
	void Update()
	{
		sdfShader.SetVector("_BoatPosition", transform.position);
		sdfShader.SetVector("_BoatForward", transform.forward);
		sdfShader.SetVector("_BoatUp", transform.up);

		SetShaderNoiseParams();

    }
	private void FixedUpdate()
	{
		AdjustNoiseParams();

        float x = transform.position.x;
		float z = transform.position.z;
		float y = GetComplexNoise(x, z);
		Vector3 terrainNormal = GetTerrainNormal(x, z);
		boatUp = Vector3.Lerp(boatUp, terrainNormal, 0.1f);
		Quaternion upRotation = Quaternion.FromToRotation(transform.up, boatUp);
		transform.rotation = upRotation * transform.rotation;
		HandleForces(y);
	}
	
	float SampleNoiseTexture(float x, float z) 
	{
		float u = x - Mathf.Floor(x);
		float v = z - Mathf.Floor(z);

		int width = noiseTex.width;
		int height = noiseTex.height;

		int texX = Mathf.Clamp((int)(u * width), 0, width - 1);
		int texY = Mathf.Clamp((int)(v * height), 0, height - 1);

		Color color = noiseTex.GetPixel(texX, texY);
		return color.r - 0.5f;
	}
	float GetComplexNoise(float x, float z) 
	{
		float noiseSum = 0;
		for (int i = 0; i < octaves; i++)
		{
			float xn = (x+xOffset) / (scale * Mathf.Pow(lacunarity, i));
			float zn = (z+zOffset) / (scale * Mathf.Pow(lacunarity, i));

			noiseSum += SampleNoiseTexture(xn, zn) * (Mathf.Pow(persistance, i));
		}
		return heightMult * noiseSum;
	}
	Vector3 GetTerrainNormal(float x, float z)
	{
		float epsilon = 0.2f;
		float n = GetComplexNoise(x, z);
        float nx = GetComplexNoise(x + epsilon, z);
        float nz = GetComplexNoise(x, z + epsilon);

        Vector3 u = new Vector3(epsilon, nx - n, 0);
        Vector3 v = new Vector3(0, nz - n, epsilon);
        
		Vector3 normal = Vector3.Cross(v, u).normalized;
        Debug.DrawRay(transform.position, normal, Color.white);
        if (normal.y < 0) return -normal;
		return normal;
	}
	void HandleForces(float y)
	{
		velocity = Vector3.zero;

		velocity += new Vector3(0, -gravity, 0);
		velocity += Vector3.ProjectOnPlane(transform.up, Vector3.up) * waveForceMult;
		Vector3 toDest = (dest - transform.position) * destForceMult;
		velocity += toDest;
		if (transform.position.y < y) 
		{
			Vector3 bouyancy = new Vector3(0,Mathf.Abs(y-transform.position.y) * bouyancyMult,0);
			velocity += bouyancy;
		}

		transform.position += velocity * Time.fixedDeltaTime;
	}
	void AdjustNoiseParams()
	{
		xOffset = 100*Mathf.Sin(Time.time/40) + 50;
		zOffset = 100*Mathf.Cos(Time.time/40) + 50 + 2*Mathf.Sin(Time.time/3);
		heightMult = 1.5f + 0.35f * Mathf.Sin(Time.time/1.25f);
		persistance = 0.7f + 0.25f * Mathf.Sin(Time.time);
		lacunarity = 1.7f + Mathf.PingPong(Time.time/30, 0.8f);
	}
	void SetShaderNoiseParams() 
	{
		sdfShader.SetFloat("_Scale", scale);
		sdfShader.SetFloat("_Lacunarity", lacunarity);
		sdfShader.SetFloat("_Persistance", persistance);
		sdfShader.SetFloat("_HeightMult", heightMult);
		sdfShader.SetInt("_Octaves", octaves);
		sdfShader.SetFloat("_XOffset", xOffset);
		sdfShader.SetFloat("_ZOffset", zOffset);
	}
}

