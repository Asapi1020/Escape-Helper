class AAS_ReplicationInfo extends ReplicationInfo;

var PlayerController PlayerOwner;
var AAS_Mutator ParentalMutator;

const SupplyMessage = "Automatically ammo supplied.";

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

unreliable client simulated function NotifySupply()
{
	KFPlayerController(PlayerOwner).MyGFxHUD.ShowNonCriticalMessage(SupplyMessage);
}