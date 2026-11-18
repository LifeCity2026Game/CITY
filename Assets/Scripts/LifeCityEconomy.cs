using UnityEngine;
using System.Collections.Generic;
public class LifeCityEconomy : MonoBehaviour
{
    public static LifeCityEconomy Instance;
    public long[] accounts=new long[6];
    public readonly Dictionary<string,NPCWallet> npcAccounts=new Dictionary<string,NPCWallet>();
    public long centralTreasury;
    void Awake()
    {
        Instance=this; accounts[0]=long.MaxValue;
        for(int i=1;i<6;i++)accounts[i]=0;
        if(LifeCityBootstrap.Instance!=null)
            foreach(var n in LifeCityBootstrap.Instance.citizens) npcAccounts[n.accountNumber]=n;
    }
    public string Resolve(string account)
    {
        if(npcAccounts.ContainsKey(account))return npcAccounts[account].displayName;
        return "حساب پیدا نشد";
    }
    public bool TransferToNPC(string account,long amount,int fromAccount=0)
    {
        if(!npcAccounts.TryGetValue(account,out var npc)||amount<=0)return false;
        if(fromAccount!=0 && accounts[fromAccount]<amount)return false;
        if(fromAccount!=0)accounts[fromAccount]-=amount;
        npc.Deposit(amount); return true;
    }
    public bool WithdrawFromNPC(string account,long amount,int toAccount=0)
    {
        if(!npcAccounts.TryGetValue(account,out var npc)||!npc.Withdraw(amount))return false;
        if(toAccount!=0)accounts[toAccount]+=amount;
        return true;
    }
}
