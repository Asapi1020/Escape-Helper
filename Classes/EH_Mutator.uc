class EH_Mutator extends KFMutator
	config(EscapeHelper);

var config float SupplyInterval;
var config byte StartWave;
var config bool bAutoSave;

var bool bCurrentlySaved;
var array<EH_ReplicationInfo> ActivePlayers;
var array<int> TraderTriggerIndex;
var vector BossSpawnLoc;

const DefaultInterval = 60.f;
const SupplyMessage = "Automatically ammo supplied.";
const WaveSetMessage = "The next wave is set";

/*	This function is called after loading level.
		Launch a timer to check if match has begun and
		make sure SupplyInterval has positive value */
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

/*	This function is called when a player login the server.
		Call LoginPlayer() and let another mutator to notify this login*/
function NotifyLogin(Controller NewPlayer)
{
	if (PlayerController(NewPlayer) != None)
		LoginPlayer(PlayerController(NewPlayer));

	if (NextMutator != None)
		NextMutator.NotifyLogin(NewPlayer);
}

/*	Spawn EH_ReplicationInfo for each player.
	Client replicated class allows to display some client HUD*/
final function LoginPlayer(PlayerController PC)
{
	local EH_ReplicationInfo R;
	local int i;
	
	for (i=(ActivePlayers.Length-1); i>=0; --i)
	{
		if (ActivePlayers[i].PlayerOwner == PC)
			return;
	}

	R = Spawn(class'EH_ReplicationInfo', PC);
	R.ParentalMutator = Self;
	ActivePlayers.AddItem(R);
	R.SetTimer(3.f, false, 'NotifyMe');
}

function EH_ReplicationInfo FindReplicationInfo(PlayerController PC)
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

function SendModMessage(PlayerController PC, string msg)
{
	FindReplicationInfo(PC).WriteModMessage(msg);
}

/*	Simple Console Command for Admin made by mutator class*/
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
			SendModMessage(Sender, "SupplyInterval=" $ string(SupplyInterval));
		}
		else if (splitbuf[0] ~= "SetStartWave")
		{
			tempI = int(splitbuf[1]);
			if (tempI > 0 && tempI <= MyKFGI.MyKFGRI.WaveMax)
			{
				StartWave = tempI;
				SaveConfig();
			}
			SendModMessage(Sender, "StartWave=" $ string(StartWave));
		}
		else if (splitbuf[0] ~= "SetAutoSave")
		{
			bAutoSave = bool(splitbuf[1]);
			SaveConfig();
			SendModMessage(Sender, "AutoSave=" $ string(bAutoSave));
		}
		else if (splitbuf[0] ~= "SummonBoss")
		{
			SummonBoss(Sender);
		}
		else if (splitbuf[0] ~= "Test")
		{
			TestF(Sender);
		}
	}
}

function SummonBoss(PlayerController PC)
{
	local KFPawn_MonsterBoss Boss;

	if(MyKFGI.MyKFGRI.WaveNum != MyKFGI.MyKFGRI.WaveMax)
	{
		SendModMessage(PC, "[ERROR] Not boss wave now");
		return;
	}

	ForEach WorldInfo.AllPawns(class'KFPawn_MonsterBoss', Boss)
	{
		Boss.SetLocation(BossSpawnLoc + vect(0, 0, 15));
		return;
	}

	if(PC != none)
		SendModMessage(PC, "[ERROR] Not found Boss");
}

function NavigationPoint GetNavigationPointFromName(name PointName)
{
	local NavigationPoint NP;

	foreach WorldInfo.AllNavigationPoints(class'NavigationPoint', NP)
	{
		if(NP.name == PointName)
		{
			return NP;
		}
	}

	return none;
}

function Trigger GetTriggerFromName(name TriggerName)
{
	local Trigger T;

	foreach WorldInfo.AllActors(class'Trigger', T)
	{
		if(T.name == TriggerName)
		{
			return T;
		}
	}

	return T;
}

function TestF(PlayerController PC)
{
	local string msg;

	msg = "Distance=";
	msg $= string(VSize(PC.Pawn.location - BossSpawnLoc));

	SendModMessage(PC, msg);
}

/*
	function GetClosestPathnode(PlayerController PC)
	{
		local KFPathnode N, ClosestNode;
		local float ThisDist, MinDist;

		ClosestNode = none;
		MinDist = 10000000.0;

		foreach WorldInfo.AllNavigationPoints(class'KFPathnode', N)
		{
			ThisDist = VSize(PC.Pawn.location - N.location);

			if(ThisDist < MinDist)
			{
				ClosestNode = N;
				MinDist = ThisDist;
			}
		}

		BroadcastEcho("Closest:" @ string(ClosestNode.name));
		BroadcastEcho("Distance=" $ string(MinDist));
	}

	function GetClosestTrigger(PlayerController PC)
	{
		local Trigger T, ClosestTrigger;
		local float ThisDist, MinDist;

		ClosestTrigger = none;
		MinDist = 10000000.0;

		foreach WorldInfo.AllActors(class'Trigger', T)
		{
			ThisDist = VSize(PC.Pawn.location - T.location);

			if(ThisDist < MinDist)
			{
				ClosestTrigger = T;
				MinDist = ThisDist;
			}
		}

		BroadcastEcho("Closest:" @ string(ClosestTrigger.name));
		BroadcastEcho("Distance=" $ string(MinDist));
	}
*/

function CheckMatchHasBegun()
{
	if(MyKFGI.MyKFGRI.bMatchHasBegun)
	{
		BossSpawnLoc = GetNavigationPointFromName('KFPathnode_3109').location;
		SetTimer(SupplyInterval, false, 'AutoAmmoSupply');
		SetTimer(5.f, true, 'CheckTraderOpen');

		if(StartWave > 1)
		{
			NotifyPendingSetWave();
			SetTimer(3.f, false, 'CustomSetWave');
		}
		return;
	}

	SetTimer(5.f, false, 'CheckMatchHasBegun');
}

function CheckTraderOpen()
{
	local EH_ReplicationInfo R;

	if(!bAutoSave)
	{
		return;
	}

	if(MyKFGI.MyKFGRI.bTraderIsOpen)
	{
		if(!bCurrentlySaved)
		{
			StartWave = Min(MyKFGI.MyKFGRI.WaveNum + 1, MyKFGI.MyKFGRI.WaveMax);
			SaveConfig();
			bCurrentlySaved = true;
			foreach ActivePlayers(R)
			{
				R.NotifyMessage("Progress is saved.");
			}
		}
	}
	else if(bCurrentlySaved)
	{
		bCurrentlySaved = false;
	}
}

function CheckWaveActive()
{
	if(MyKFGI.MyKFGRI.bTraderIsOpen)
	{
		SetTimer(3.f, false, 'CheckWaveActive');
		return;
	}
	else
	{
		SetTimer(1.f, false, 'MonitorBossLoc');
	}
}

function AutoAmmoSupply()
{
	local KFPlayerController KFPC;
	local KFPawn Player;
	local KFWeapon KFW;
	local bool bSupplied;
	local EH_ReplicationInfo R;

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
					R.NotifyMessage(SupplyMessage);
			}
		}
	}
	SetTimer(SupplyInterval, false, 'AutoAmmoSupply');
}

function CustomSetWave(optional byte WaveNum)
{
	local KFGameInfo_Survival GameMaster;

	//	Initialization
	if(WaveNum < 1)
	{
		if(StartWave < 1)
		{
			`Log("Invalid properties!");
			return;
		}
		WaveNum = StartWave;
	}

	GameMaster = KFGameInfo_Survival(MyKFGI);

	if(GameMaster == none)
	{
		`Log("Failed to access Game Master!");
		return;
	}

	//	SetWave with TraderTime
	Ext_KillZeds();

	KFGameInfo_Objective(GameMaster).MyKFMI.ObjectiveModeObjectives[Min(WaveNum, GameMaster.MyKFGRI.WaveMax)-2].bShouldAutoStartWave = true;
	GameMaster.WaveNum = Clamp(WaveNum-2, 0, GameMaster.WaveMax-2);
	GameMaster.MyKFGRI.WaveNum = GameMaster.WaveNum;
	GameMaster.StartWave();
	GameMaster.WaveEnded(WEC_WaveWon);

	if(WaveNum == 11)
	{
		SetTimer(3.f, false, 'CheckWaveActive');
	}

	SetTimer((WaveNum != 11 ? 1.f : 12.f), false, 'RichTeleport');
}

function MonitorBossLoc()
{
	local KFPawn_MonsterBoss Boss;

	ForEach WorldInfo.AllPawns(class'KFPawn_MonsterBoss', Boss)
	{
		if(IsInBossArea(Boss))
		{
			`Log("Boss is in the correct area.");
			if(EveryonInBossArea())
			{
				`Log("Monitoring Done!");
				return;
			}
		}
		else if(NearbyPlayer(Boss))
		{
			`Log("Boss is near a player");
			Boss.SetLocation(BossSpawnLoc + vect(0, 0, 15));
		}
		else if(SomeoneInBossArea())
		{
			`Log("Some one already reached boss area");
			Boss.SetLocation(BossSpawnLoc + vect(0, 0, 15));
		}
	}

	SetTimer(1.f, false, 'MonitorBossLoc');
	`Log("Monitoring...");
}

function bool NearbyPlayer(Pawn P)
{
	local KFPawn_Human Player;

	ForEach WorldInfo.AllPawns(class'KFPawn_Human', Player)
	{
		if(VSize(P.location - Player.location) < 3000)
		{
			return true;
		}
	}

	return false;
}

function bool EveryonInBossArea()
{
	local KFPawn_Human Player;

	ForEach WorldInfo.AllPawns(class'KFPawn_Human', Player)
	{
		if(!IsInBossArea(Player))
		{
			return false;
		}
	}

	return true;
}

function bool SomeoneInBossArea()
{
	local KFPawn_Human Player;

	ForEach WorldInfo.AllPawns(class'KFPawn_Human', Player)
	{
		if(IsInBossArea(Player))
		{
			return true;
		}
	}

	return false;
}

function bool IsInBossArea(Pawn P)
{
	return VSize(P.location - BossSpawnLoc) < 4800;
}

function NotifyPendingSetWave()
{
	local KFPlayerController KFPC;
	local EH_ReplicationInfo R;

	foreach WorldInfo.AllControllers(class'KFPlayerController', KFPC)
	{
		R = FindReplicationInfo(KFPC);
		if(R != none)
		{
			R.NotifyMessage(WaveSetMessage @ string(StartWave));
		}
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

function RichTeleport()
{
	local KFPlayerController KFPC;
	local KFPlayerReplicationInfo KFPRI;
	local KFTraderTrigger KFTrader;

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
		KFPC.Pawn.SetLocation(ChoosePlayerStart().Location + vect(0,0,15));
		KFPC.Pawn.CreateInventory(class'KFWeap_Healer_Syringe');
	}

	MyKFGI.MyKFGRI.OpenedTrader.CloseTrader();

	foreach DynamicActors(class'KFTraderTrigger', KFTrader)
	{
		if(GetObjectIndex(KFTrader) == TraderTriggerIndex[MyKFGI.MyKFGRI.WaveNum-1])
		{
			KFTrader.OpenTrader();
			MyKFGI.MyKFGRI.OpenedTrader = KFTrader;
			break;
		}       
	}
}

static function int GetObjectIndex(Object O)
{
	return int(GetRightMost(string(O.name)));
}

function PlayerStart ChoosePlayerStart()
{
	local PlayerStart P;

	foreach WorldInfo.AllNavigationPoints(class'PlayerStart', P)
	{
		if(P.bEnabled)
		{
			return P;
		}
	}

	`Log("There is no enabled PlayerStart!");
	return none;
}

function BroadcastEcho(string msg)
{
	local EH_ReplicationInfo R;

	foreach ActivePlayers(R)
	{
		R.WriteModMessage(msg);
	}
}

defaultproperties
{
	TraderTriggerIndex=(INDEX_NONE, 0, 1, 3, 6, 6, 2, 4, 7, 5)
}

/*
wave=(PlayerStart, TraderTrigger)
 2=(13, -)
 3=(21, 0)
 4=(23, 3)
 5=(15, -)
 6=( 8, 6)
 7=(16, 2)
 8=(22, 4)
 9=(12, 7)
10=( 0, 5)

Trigger_1
KFPathnode_3109
*/