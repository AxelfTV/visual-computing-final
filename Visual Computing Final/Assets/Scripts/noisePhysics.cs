using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class noisePhysics : MonoBehaviour
{
    [SerializeField] Texture2D noiseTex;
	[SerializeField] Material sdfShader;
	// Start is called before the first frame update
	void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
		float x = Mathf.Sin(Time.time);
		float z = Mathf.Cos(Time.time);
		float y = GetNoise(transform.position.x, transform.position.z);
		transform.position = new Vector3(x, y, z);
		sdfShader.SetVector("_BoatPosition", transform.position);
	}
    float GetNoise(float x, float z)
    {

		float shaderTimeY = Shader.GetGlobalVector("_Time").y;
		float xOffset = shaderTimeY;
		float zOffset = 0;

		float hMult = 1f + Mathf.Sin((shaderTimeY/20) * 30f) / 2f;

		float u = (x+xOffset) * 0.1f % 1f;
		float v = (z+zOffset) * 0.1f % 1f;

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
}

