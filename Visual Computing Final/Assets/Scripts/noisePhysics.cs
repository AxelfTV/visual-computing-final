using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class noisePhysics : MonoBehaviour
{
	[SerializeField] Texture2D noiseTex;
	[SerializeField] Material sdfShader;

	Vector3 boatUp;
	// Start is called before the first frame update
	void Start()
	{
		boatUp = Vector3.up;
	}

	// Update is called once per frame
	void Update()
	{
		sdfShader.SetVector("_BoatPosition", transform.position);
		sdfShader.SetVector("_BoatForward", transform.forward);
		sdfShader.SetVector("_BoatUp", transform.up);
	}
	private void FixedUpdate()
	{
		float x = Mathf.Sin(Time.time);
		float z = Mathf.Cos(Time.time);
		float y = GetNoise(x, z);
		transform.position = new Vector3(x, y, z);
		Vector3 terrainNormal = GetTerrainNormal(x, z);
		boatUp = Vector3.Lerp(terrainNormal, boatUp, 0.975f);
		Quaternion rotation = Quaternion.FromToRotation(transform.up, boatUp);
		transform.rotation = rotation * transform.rotation;
	}
	float GetNoise(float x, float z)
	{

		float shaderTimeY = Shader.GetGlobalVector("_Time").y;
		float xOffset = shaderTimeY;
		float zOffset = 0;

		float hMult = 1f + Mathf.Sin((shaderTimeY / 20) * 30f) / 2f;

		float u = (x + xOffset) * 0.1f % 1f;
		float v = (z + zOffset) * 0.1f % 1f;

		if (u < 0) u += 1f;
		if (v < 0) v += 1f;

		int width = noiseTex.width;
		int height = noiseTex.height;

		int texX = Mathf.Clamp((int)(u * width), 0, width - 1);
		int texY = Mathf.Clamp((int)(v * height), 0, height - 1);

		Color color = noiseTex.GetPixel(texX, texY, 0);
		//Debug.Log(color);
		return hMult * (color.r - 0.5f);
	}
	Vector3 GetTerrainNormal(float x, float z)
	{
		float epsilon = 0.2f;
		float n = GetNoise(x, z);
		Vector3 u = new Vector3(x + epsilon, GetNoise(x + epsilon, z), z);
		Vector3 v = new Vector3(x, GetNoise(x, z + epsilon), z + epsilon);
		
		Vector3 normal = Vector3.Cross(u, v).normalized;
		if (normal.y < 0) return -normal;
		return normal;
	}
}

