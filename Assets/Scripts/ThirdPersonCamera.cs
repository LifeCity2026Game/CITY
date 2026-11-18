using UnityEngine;
public class ThirdPersonCamera : MonoBehaviour
{
    public Transform target; public float distance=6f,height=2.2f,sensitivity=3f;
    float yaw,pitch=12;
    void LateUpdate()
    {
        if(!target)return;
        if(Input.GetMouseButton(0)){yaw+=Input.GetAxis("Mouse X")*sensitivity; pitch-=Input.GetAxis("Mouse Y")*sensitivity; pitch=Mathf.Clamp(pitch,-5,55);}
        Quaternion rot=Quaternion.Euler(pitch,yaw,0);
        Vector3 desired=target.position+Vector3.up*height-rot*Vector3.forward*distance;
        transform.position=Vector3.Lerp(transform.position,desired,12*Time.deltaTime);
        transform.LookAt(target.position+Vector3.up*1.2f);
    }
}
