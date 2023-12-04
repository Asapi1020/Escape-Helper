class EH_ReplicationInfo extends ReplicationInfo;

var PlayerController PlayerOwner;
var EH_Mutator ParentalMutator;

function PostBeginPlay()
{
	PlayerOwner = PlayerController(Owner);
}

function Tick(float Delta)
{
	if (PlayerOwner==None || PlayerOwner.Player==None)
	{
		Destroy();
		return;
	}
}

unreliable client simulated function NotifyMessage(string msg)
{
	KFPlayerController(PlayerOwner).MyGFxHUD.ShowNonCriticalMessage(msg);
}

unreliable client simulated function NotifyMe()
{
	local KFPlayerController KFPC;

    KFPC = KFPlayerController(PlayerOwner);
    if(KFPC != none)
    {
        KFPC.MyGFxManager.PartyWidget.PartyChatWidget.SetVisible(true);
    }
    WriteModMessage("Escape Helper is loaded");
}

unreliable client simulated function WriteModMessage(string msg)
{
	WriteToChat(msg, "b83dba");
}

unreliable client simulated function WriteToChat(string Message, string HexColor)
{
    local KFPlayerController KFPC;

    KFPC = KFPlayerController(PlayerOwner);
    if(KFPC == none)
    {
    	`Log("No KFPC found");
    	return;
    }

    if (KFPC.MyGFxManager != none && KFPC.MyGFxManager.PartyWidget != None && KFPC.MyGFxManager.PartyWidget.PartyChatWidget != None)
    {
        KFPC.MyGFxManager.PartyWidget.PartyChatWidget.AddChatMessage(Message, HexColor);
    }

    if (KFPC.MyGFxHUD != None && KFPC.MyGFxHUD.HudChatBox != None)
    {
        KFPC.MyGFxHUD.HudChatBox.AddChatMessage(Message, HexColor);
    }
}