using UnityEngine;

public class noisePhysics : MonoBehaviour
{
	[SerializeField] Texture2D noiseTex;
	[SerializeField] Material sdfShader;

	Vector3 dest = Vector3.zero;

	Vector3 velocity = Vector3.zero;

	Vector3 boatUp = Vector3.up;
	[Header("Boat Physics Paramters")]
	[SerializeField] float gravity = 1;
	[SerializeField] float waveForceMult = 1;
	[SerializeField] float bouyancyMult = 1;
	[SerializeField] float destForceMult = 1;
	[SerializeField] float rotationSpeed = 60f;

	[Header("Noise Parameters")]
	[SerializeField] float scale = 1;
	[SerializeField] float lacunarity = 1;
	[SerializeField] float persistance = 1;
	[SerializeField] float heightMult = 1;
	[SerializeField] int octaves = 1;

	private void Start()
	{
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
		
		float x = transform.position.x;
		float z = transform.position.y;
		float y = GetComplexNoise(x, z);
		Vector3 terrainNormal = GetTerrainNormal(x, z);
		boatUp = Vector3.Lerp(boatUp, terrainNormal, 0.2f);
		//Quaternion upRotation = Quaternion.FromToRotation(transform.up, boatUp);
		//transform.rotation = upRotation * transform.rotation;
		Vector3 forwardProjected = Vector3.ProjectOnPlane(transform.forward, terrainNormal).normalized;
		//transform.rotation = Quaternion.LookRotation(forwardProjected, terrainNormal);
		//HandleForces(y);
		Debug.Log(y);
	}
	
	float SampleNoiseTexture(float x, float z) 
	{
		float u = x - Mathf.Floor(x); // Wraps properly from 0 to 1
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
			float xn = x / (scale * Mathf.Pow(lacunarity, i));
			float zn = z / (scale * Mathf.Pow(lacunarity, i));

			noiseSum += SampleNoiseTexture(xn, zn) * (Mathf.Pow(persistance, i));
		}
		return heightMult * noiseSum;
	}
	Vector3 GetTerrainNormal(float x, float z)
	{
		float epsilon = 0.2f;
		float n = GetComplexNoise(x, z);
		Vector3 u = new Vector3(epsilon, GetComplexNoise(x + epsilon, z)-n, 0);
		Vector3 v = new Vector3(0, GetComplexNoise(x, z + epsilon)-n,epsilon);
		Vector3 normal = Vector3.Cross(u, v).normalized;
		Debug.DrawLine(transform.position, transform.position + normal,Color.white);
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
	void SetShaderNoiseParams() 
	{
		sdfShader.SetFloat("_Scale", scale);
		sdfShader.SetFloat("_Lacunarity", lacunarity);
		sdfShader.SetFloat("_Persistance", persistance);
		sdfShader.SetFloat("_HeightMult", heightMult);
		sdfShader.SetInt("_Octaves", octaves);
	}
}

