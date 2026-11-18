using UnityEngine;
public class SimpleNPCWalk : MonoBehaviour
{
    Vector3 target; float timer;
    void Start(){Pick();}
    void Update()
    {
        timer-=Time.deltaTime;
        Vector3 d=target-transform.position; d.y=0;
        if(d.magnitude<1||timer<=0)Pick();
        else {transform.position+=d.normalized*1.1f*Time.deltaTime; transform.rotation=Quaternion.Slerp(transform.rotation,Quaternion.LookRotation(d),5*Time.deltaTime);}
    }
    void Pick(){target=transform.position+new Vector3(Random.Range(-12,12),0,Random.Range(-12,12));timer=Random.Range(4,9);}
}
