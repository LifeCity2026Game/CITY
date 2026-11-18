using UnityEngine;
public class ServiceEntrance : MonoBehaviour
{
    public string serviceName="ساختمان";
    void OnTriggerEnter(Collider other){if(other.GetComponent<PlayerMotor>()) LifeCityUI.Instance?.SetNotice("نزدیک ورودی: "+serviceName+" | دکمه تعامل را بزن");}
}
