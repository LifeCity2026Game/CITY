using UnityEngine;
public class LifeCityUI : MonoBehaviour
{
    public static LifeCityUI Instance;
    string notice="به LIFE CITY 3.0 خوش آمدی";
    string accountInput="NPC1000",amountInput="500";
    bool showBank,showWardrobe,showCars;
    GUIStyle button,label,box;
    void Awake(){Instance=this; gameObject.AddComponent<LifeCityEconomy>();}
    public void SetNotice(string s){notice=s;}
    void OnGUI()
    {
        button=new GUIStyle(GUI.skin.button){fontSize=18}; label=new GUIStyle(GUI.skin.label){fontSize=17,normal={textColor=Color.white}}; box=new GUIStyle(GUI.skin.box){fontSize=17};
        float w=Mathf.Min(310,Screen.width*.43f);
        GUI.Box(new Rect(10,10,w,46),notice,box);
        if(GUI.Button(new Rect(10,62,w,48),"بانک و حساب‌ها",button))showBank=!showBank;
        if(GUI.Button(new Rect(10,114,w,48),"شخصی‌سازی لباس",button))showWardrobe=!showWardrobe;
        if(GUI.Button(new Rect(10,166,w,48),"خودروها",button))showCars=!showCars;
        if(showBank)
        {
            GUI.Box(new Rect(10,220,w,245),"بانک آزمایشی");
            GUI.Label(new Rect(20,250,w-20,30),"حساب ۱: بی‌نهایت | حساب ۲ تا ۶: صفر",label);
            GUI.Label(new Rect(20,284,100,28),"شماره NPC",label); accountInput=GUI.TextField(new Rect(120,284,w-135,30),accountInput);
            GUI.Label(new Rect(20,318,100,28),"مبلغ",label); amountInput=GUI.TextField(new Rect(120,318,w-135,30),amountInput);
            if(GUI.Button(new Rect(20,355,w-40,40),"انتقال پول به NPC",button))
            {
                if(long.TryParse(amountInput,out long a) && LifeCityEconomy.Instance.TransferToNPC(accountInput,a))
                    notice="واریز انجام شد: "+LifeCityEconomy.Instance.Resolve(accountInput);
                else notice="حساب یا مبلغ نامعتبر است";
            }
            if(GUI.Button(new Rect(20,400,w-40,40),"برداشت از NPC به حساب ۱",button))
            {
                if(long.TryParse(amountInput,out long a) && LifeCityEconomy.Instance.WithdrawFromNPC(accountInput,a))
                    notice="برداشت انجام شد";
                else notice="موجودی NPC کافی نیست";
            }
        }
        if(showWardrobe)
        {
            GUI.Box(new Rect(10,220,w,145),"کمد لباس آزمایشی");
            if(GUI.Button(new Rect(20,255,w-40,38),"لباس آبی",button))notice="لباس آبی انتخاب شد";
            if(GUI.Button(new Rect(20,298,w-40,38),"لباس قرمز",button))notice="لباس قرمز انتخاب شد";
        }
        if(showCars)
        {
            GUI.Box(new Rect(10,220,w,190),"نمایشگاه خودرو");
            if(GUI.Button(new Rect(20,255,w-40,40),"خرید خودروی آزمایشی",button))notice="خودرو خریداری شد";
            if(GUI.Button(new Rect(20,302,w-40,40),"ظاهر کردن خودرو",button))notice="خودرو در نسخه بعدی به سیستم رانندگی متصل می‌شود";
            if(GUI.Button(new Rect(20,349,w-40,40),"خرید خانه آزمایشی",button))notice="خانه آزمایشی خریداری شد";
        }
        // Simple touch movement controls for Android
        float bx=Screen.width-150, by=Screen.height-180;
        if(GUI.RepeatButton(new Rect(bx+48,by,55,48),"▲",button)) Move(Vector3.forward);
        if(GUI.RepeatButton(new Rect(bx,by+50,55,48),"◀",button)) Move(Vector3.left);
        if(GUI.RepeatButton(new Rect(bx+96,by+50,55,48),"▶",button)) Move(Vector3.right);
        if(GUI.RepeatButton(new Rect(bx+48,by+100,55,48),"▼",button)) Move(Vector3.back);
    }
    void Move(Vector3 dir){var p=FindObjectOfType<PlayerMotor>(); if(p) p.transform.Translate(dir*3.5f*Time.deltaTime,Space.Self);}
}
