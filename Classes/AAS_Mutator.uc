class AAS_Mutator extends KFMutator
	config(AutoAmmoSupply);

var config float SupplyInterval;
var config byte StartWave;

var array<AAS_ReplicationInfo> ActivePlayers;

const DefaultInterval = 60.f;
const SetWaveDelay = 3.f;

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
		if(StartWave > 1)
		{
			SetTimer(SetWaveDelay, false, 'CustomSetWave');
		}
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
	local AAS_ReplicationInfo R;

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
				R = FindReplicationInfo(KFPC);
				if(R != none)
					R.NotifySupply();
			}
		}
	}
	SetTimer(SupplyInterval, false, 'AutoAmmoSupply');
}

function Mutate(string MutateString, PlayerController Sender)
{
	local array<string> splitbuf;
	local float tempF;
	local int tempI;

	if(WorldInfo.NetMode == NM_Standalone || Sender.PlayerReplicationInfo.bAdmin)
	{
		ParseStringIntoArray(MutateString, splitbuf, " ", false);

		if (splitbuf[0] ~= "SetSupplyInterval")
		{
			tempF = float(splitbuf[1]);
			if (tempF > 0.f)
			{
				SupplyInterval = tempF;
				SaveConfig();
			}
			Sender.ClientMessage("SupplyInterval=" $ string(SupplyInterval));
		}
		else if (splitbuf[0] ~= "SetStartWave")
		{
			tempI = int(splitbuf[1]);
			if (tempI > 0)
			{
				StartWave = tempI;
				SaveConfig();
			}
			Sender.ClientMessage("StartWave=" $ string(StartWave));
		}
	}
}

final function LoginPlayer(PlayerController PC)
{
	local AAS_ReplicationInfo R;
	local int i;
	
	for (i=(ActivePlayers.Length-1); i>=0; --i)
	{
		if (ActivePlayers[i].PlayerOwner == PC)
			return;
	}

	R = Spawn(class'AAS_ReplicationInfo',PC);
	R.ParentalMutator = Self;
	ActivePlayers.AddItem(R);
}

function AAS_ReplicationInfo FindReplicationInfo(PlayerController PC)
{
	local int i;

	for(i=(ActivePlayers.Length-1); i>=0; --i)
	{
		if(ActivePlayers[i].PlayerOwner == PC)
			return ActivePlayers[i];
	}
	`Log("ReplicationInfo was not found!");
	return none;
}

function CustomSetWave(optional byte WaveNum)
{
	local KFGameInfo_Survival GameMaster;
	local KFPlayerController KFPC;
	local KFPlayerReplicationInfo KFPRI;

	if(WaveNum < 1)
	{
		if(StartWave < 1)
		{
			`Log("Invalid properties!");
			return;
		}
		WaveNum = StartWave;
	}

	GameMaster = KFGameInfo_Survival(WorldInfo.Game);

	if(GameMaster == none)
	{
		`Log("Failed to access Game Master!");
		return;
	}

	Ext_KillZeds();
	GameMaster.WaveEnded(WEC_WaveWon);
	GameMaster.WaveNum = Clamp(--StartWave, 1, GameMaster.WaveMax);
	GameMaster.MyKFGRI.WaveNum = GameMaster.WaveNum;

	foreach WorldInfo.AllControllers(class'KFPlayerController', KFPC)
	{
		KFPRI = KFPlayerReplicationInfo(KFPC.PlayerReplicationInfo);
		if(KFPRI == none)
		{
			`Log("Not found KFPRI!");
			continue;
		}
		else if(KFPRI.bOnlySpectator)
		{
			`Log("Skip a spectator");
			continue;
		}

		KFPRI.AddDosh( 1000000 );
	}
}

function Ext_KillZeds()
{
	local KFPawn_Monster AIP;
	ForEach WorldInfo.AllPawns(class'KFPawn_Monster', AIP)
	{
		if ( AIP.Health > 0 && PlayerController(AIP.Controller) == none)
			AIP.Died(none , none, AIP.Location);
	}
}