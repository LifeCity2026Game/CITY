using UnityEngine;
[System.Serializable]
public class NPCWallet : MonoBehaviour
{
    public string accountNumber,displayName;
    public long balance=1000;
    public void Deposit(long amount){if(amount>0)balance+=amount;}
    public bool Withdraw(long amount){if(amount<=0||balance<amount)return false;balance-=amount;return true;}
}
