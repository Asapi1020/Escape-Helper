class AAS_Mutator extends KFMutator
	config(AutoAmmoSupply);

var config float SupplyInterval;

const DefaultInterval = 60.f;
const SupplyMessage = "Automatically ammo supplied.";

function PostBeginPlay()
{
	Super.PostBeginPlay();
	SetTimer(5.f, false, 'CheckMatchHasBegun');

	if(SupplyInterval <= 0.f)
	{
		SupplyInterval = DefaultInterval;
		SaveConfig();
	}
}

function CheckMatchHasBegun()
{
	if(MyKFGI.MyKFGRI.bMatchHasBegun)
	{
		SetTimer(SupplyInterval, false, 'AutoAmmoSupply');
		return;
	}

	SetTimer(5.f, false, 'CheckMatchHasBegun');
}

function AutoAmmoSupply()
{
	local KFPlayerController KFPC;
	local KFPawn Player;
	local KFWeapon KFW;
	local bool bSupplied;

	foreach WorldInfo.AllControllers(class'KFPlayerController', KFPC)
	{
		bSupplied = false;
		Player = KFPawn(KFPC.Pawn);

		if(Player != none)
		{
			foreach Player.InvManager.InventoryActors(class'KFWeapon', KFW)
			{
				KFW.AddAmmo(KFW.GetMaxAmmoAmount(0));
        		bSupplied = true;
			}

			if(bSupplied)
			{
				NotifySupply(KFPC);
			}
		}
	}
	SetTimer(SupplyInterval, false, 'AutoAmmoSupply');
}

function Mutate(string MutateString, PlayerController Sender)
{
	local array<string> splitbuf;

	if(WorldInfo.NetMode == NM_Standalone || Sender.PlayerReplicationInfo.bAdmin)
	{
		ParseStringIntoArray(MutateString, splitbuf, " ", false);

		if (splitbuf[0] ~= "SetSupplyInterval")
		{
			if (float(splitbuf[1]) > 0.f)
			{
				SupplyInterval = float(splitbuf[1]);
				SaveConfig();
			}
			Sender.ClientMessage("SupplyInterval=" $ string(SupplyInterval));
		}
	}
}

unreliable client function NotifySupply(KFPlayerController KFPC)
{
	KFPC.MyGFxHUD.ShowNonCriticalMessage(SupplyMessage);
}