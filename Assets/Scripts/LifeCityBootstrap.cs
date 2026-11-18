using UnityEngine;
using UnityEngine.EventSystems;
using System.Collections.Generic;

public class LifeCityBootstrap : MonoBehaviour
{
    public static LifeCityBootstrap Instance;
    public Transform player;
    public Camera cam;
    public LifeCityUI ui;
    public readonly List<Transform> vehicles = new List<Transform>();
    public readonly List<NPCWallet> citizens = new List<NPCWallet>();
    public float worldSize = 220f;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void StartGame()
    {
        if (FindObjectOfType<LifeCityBootstrap>() == null)
            new GameObject("LIFE CITY 3.0 Bootstrap").AddComponent<LifeCityBootstrap>();
    }

    void Awake()
    {
        if (Instance != null) { Destroy(gameObject); return; }
        Instance = this;
        Application.targetFrameRate = 60;
        BuildWorld();
        BuildPlayer();
        BuildCamera();
        BuildCitizens();
        ui = gameObject.AddComponent<LifeCityUI>();
    }

    Material Mat(Color c, float metallic=0f)
    {
        var m = new Material(Shader.Find("Standard"));
        m.color = c; m.SetFloat("_Metallic", metallic); m.SetFloat("_Glossiness", .35f);
        return m;
    }

    void BuildWorld()
    {
        RenderSettings.ambientLight = new Color(.62f,.66f,.72f);
        var ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
        ground.name="City Ground"; ground.transform.localScale=new Vector3(22,1,22);
        ground.GetComponent<Renderer>().material=Mat(new Color(.22f,.34f,.25f));
        var sun = new GameObject("Sun").AddComponent<Light>();
        sun.type=LightType.Directional; sun.intensity=1.15f; sun.transform.rotation=Quaternion.Euler(48,-32,0);

        // Roads and sidewalks
        MakeCube("Main Road", new Vector3(0,.03f,0), new Vector3(18,.08f,220), new Color(.12f,.13f,.15f));
        MakeCube("Cross Road", new Vector3(0,.04f,0), new Vector3(220,.08f,18), new Color(.12f,.13f,.15f));
        for(int i=-90;i<=90;i+=12)
        {
            MakeCube("Road marking",new Vector3(0,.09f,i),new Vector3(.22f,.02f,5),Color.white);
            MakeCube("Road marking",new Vector3(i,.09f,0),new Vector3(5,.02f,.22f),Color.white);
        }

        // Procedural blocks, with some buildings having accessible interiors
        for(int x=-4;x<=4;x++)
        for(int z=-4;z<=4;z++)
        {
            if(Mathf.Abs(x)<2 && Mathf.Abs(z)<2) continue;
            float px=x*24f, pz=z*24f;
            if(Mathf.Abs(px)<12 || Mathf.Abs(pz)<12) continue;
            float w=Random.Range(9f,14f), d=Random.Range(9f,14f), h=Random.Range(8f,25f);
            var b=MakeCube("Building "+x+"_"+z,new Vector3(px,h/2,pz),new Vector3(w,h,d),
                new Color(Random.Range(.35f,.72f),Random.Range(.4f,.72f),Random.Range(.48f,.78f)));
            b.AddComponent<BuildingInterior>();
            // windows on street-facing walls
            for(int floor=1;floor<h/3;floor++)
            for(int side=-1;side<=1;side+=2)
            {
                MakeCube("Window",new Vector3(px+side*(w/2+.03f),floor*3f,pz),
                    new Vector3(.08f,1.25f,1.65f),new Color(.22f,.68f,.86f));
            }
        }
        // Central plaza and recognizable service buildings
        MakeServiceBuilding("بانک مرکزی",new Vector3(-28,0,27),new Color(.72f,.62f,.24f));
        MakeServiceBuilding("بانک شهر",new Vector3(28,0,27),new Color(.2f,.55f,.8f));
        MakeServiceBuilding("نمایشگاه خودرو",new Vector3(0,0,48),new Color(.25f,.65f,.55f));
        MakeServiceBuilding("وزارت اطلاعات",new Vector3(0,0,-48),new Color(.35f,.38f,.48f));
    }

    void MakeServiceBuilding(string title, Vector3 p, Color c)
    {
        var g=new GameObject(title); g.transform.position=p;
        var shell=GameObject.CreatePrimitive(PrimitiveType.Cube); shell.name="Building shell";
        shell.transform.SetParent(g.transform,false); shell.transform.localPosition=new Vector3(0,4,0);
        shell.transform.localScale=new Vector3(17,8,13); shell.GetComponent<Renderer>().material=Mat(c);
        var trigger=new GameObject("Entrance"); trigger.transform.SetParent(g.transform,false);
        trigger.transform.localPosition=new Vector3(0,1,7);
        var box=trigger.AddComponent<BoxCollider>(); box.isTrigger=true; box.size=new Vector3(5,3,2);
        var marker=GameObject.CreatePrimitive(PrimitiveType.Cube); marker.name="Sign";
        marker.transform.SetParent(g.transform,false); marker.transform.localPosition=new Vector3(0,8.6f,0);
        marker.transform.localScale=new Vector3(8,.25f,.25f); marker.GetComponent<Renderer>().material=Mat(Color.white);
        trigger.AddComponent<ServiceEntrance>().serviceName=title;
        // interior floor and furniture visible when entering
        var floor=GameObject.CreatePrimitive(PrimitiveType.Cube); floor.name="Interior floor";
        floor.transform.SetParent(g.transform,false); floor.transform.localPosition=new Vector3(0,.15f,0);
        floor.transform.localScale=new Vector3(16,.3f,12); floor.GetComponent<Renderer>().material=Mat(new Color(.55f,.52f,.46f));
        var desk=GameObject.CreatePrimitive(PrimitiveType.Cube); desk.transform.SetParent(g.transform,false);
        desk.transform.localPosition=new Vector3(0,1.1f,-2); desk.transform.localScale=new Vector3(5,1.8f,1.2f);
        desk.GetComponent<Renderer>().material=Mat(new Color(.28f,.16f,.09f));
    }

    GameObject MakeCube(string n, Vector3 p, Vector3 s, Color c)
    {
        var o=GameObject.CreatePrimitive(PrimitiveType.Cube); o.name=n;
        o.transform.position=p; o.transform.localScale=s; o.GetComponent<Renderer>().material=Mat(c);
        return o;
    }

    void BuildPlayer()
    {
        var root=new GameObject("Player");
        root.transform.position=new Vector3(0,1,0); player=root.transform;
        var cc=root.AddComponent<CharacterController>(); cc.height=1.8f; cc.radius=.34f; cc.center=new Vector3(0,.9f,0);
        root.AddComponent<PlayerMotor>();
        var body=MakeCube("Torso",new Vector3(0,0,0),Vector3.one, new Color(.12f,.28f,.75f));
        body.transform.SetParent(root.transform,false); body.transform.localPosition=new Vector3(0,1.05f,0); body.transform.localScale=new Vector3(.62f,.78f,.32f);
        var head=GameObject.CreatePrimitive(PrimitiveType.Sphere); head.name="Head"; head.transform.SetParent(root.transform,false);
        head.transform.localPosition=new Vector3(0,1.62f,0); head.transform.localScale=Vector3.one*.34f; head.GetComponent<Renderer>().material=Mat(new Color(.82f,.65f,.5f));
        MakeLimb(root.transform,"Left Arm",new Vector3(-.43f,1.08f,0),new Vector3(.18f,.72f,.18f));
        MakeLimb(root.transform,"Right Arm",new Vector3(.43f,1.08f,0),new Vector3(.18f,.72f,.18f));
        MakeLimb(root.transform,"Left Leg",new Vector3(-.18f,.42f,0),new Vector3(.22f,.78f,.24f));
        MakeLimb(root.transform,"Right Leg",new Vector3(.18f,.42f,0),new Vector3(.22f,.78f,.24f));
    }

    void MakeLimb(Transform parent,string n,Vector3 p,Vector3 s)
    {
        var o=GameObject.CreatePrimitive(PrimitiveType.Capsule); o.name=n; o.transform.SetParent(parent,false);
        o.transform.localPosition=p; o.transform.localScale=s;
        o.GetComponent<Collider>().enabled=false;
        o.GetComponent<Renderer>().material=new Material(Shader.Find("Standard")){color=new Color(.12f,.28f,.75f)};
    }

    void BuildCamera()
    {
        var c=new GameObject("Main Camera").AddComponent<Camera>(); c.tag="MainCamera";
        c.transform.position=new Vector3(0,5,-8); c.fieldOfView=65; cam=c;
        c.gameObject.AddComponent<AudioListener>();
        var follow=c.gameObject.AddComponent<ThirdPersonCamera>(); follow.target=player;
    }

    void BuildCitizens()
    {
        for(int i=0;i<12;i++)
        {
            var n=GameObject.CreatePrimitive(PrimitiveType.Capsule); n.name="NPC "+(i+1);
            n.transform.position=new Vector3(Random.Range(-75,75),1,Random.Range(-75,75));
            n.GetComponent<Renderer>().material=new Material(Shader.Find("Standard")){color=new Color(Random.value*.6f+.2f,Random.value*.6f+.2f,Random.value*.6f+.2f)};
            var wallet=n.AddComponent<NPCWallet>(); wallet.accountNumber="NPC"+(1000+i); wallet.displayName="شهروند "+(i+1); wallet.balance=Random.Range(1000,10000);
            citizens.Add(wallet);
            n.AddComponent<SimpleNPCWalk>();
        }
    }
}
