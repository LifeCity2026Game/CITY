using UnityEngine;
public class PlayerMotor : MonoBehaviour
{
    public float speed=5.5f, gravity=-20f;
    CharacterController controller; Vector3 velocity;
    void Start(){controller=GetComponent<CharacterController>();}
    void Update()
    {
        float x=Input.GetAxisRaw("Horizontal"), z=Input.GetAxisRaw("Vertical");
        Vector3 move=transform.right*x+transform.forward*z;
        if(move.sqrMagnitude>.01f){controller.Move(move.normalized*speed*Time.deltaTime); transform.rotation=Quaternion.Slerp(transform.rotation,Quaternion.LookRotation(move),12*Time.deltaTime);}
        if(controller.isGrounded && velocity.y<0) velocity.y=-2;
        velocity.y+=gravity*Time.deltaTime; controller.Move(velocity*Time.deltaTime);
    }
}
