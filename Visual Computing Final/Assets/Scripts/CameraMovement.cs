using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraMovement : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {

    }
    private void FixedUpdate()
    {
        Vector3 moveVector = Vector3.zero;
        if (Input.GetKey(KeyCode.A)) moveVector += -transform.right;
        if (Input.GetKey(KeyCode.D)) moveVector += transform.right;
        if (Input.GetKey(KeyCode.W)) moveVector += transform.forward;
        if (Input.GetKey(KeyCode.S)) moveVector += -transform.forward;

        transform.position = transform.position + moveVector.normalized * Time.fixedDeltaTime;
    }
}
