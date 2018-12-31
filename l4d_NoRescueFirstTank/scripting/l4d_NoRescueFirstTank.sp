#include <sourcemod>
#include <sdktools>
#include <l4d_lib>
#include <left4downtown>

static 		Handle:g_hEnableNoFinalFirstTank, bool:g_bEnableNoFinalFirstTank;

static bool:resuce_start,bool:HasBlockFirstTank,bool:timercheck;
static bool:g_bFixed,bool:Tank_firstround_spawn,Float:g_fTankData_origin[3],Float:g_fTankData_angel[3];

public Plugin:myinfo = 
{
	name = "L4D Final No First Tank",
	author = "Harry Potter",
	description = "Final Stage except for 'The Sacrifice', No First Tank Spawn as the final rescue start and second tank spawn same position for both team",
	version = "1.2",
	url = "https://steamcommunity.com/id/fbef0102/"
}

public OnPluginStart()
{
	g_hEnableNoFinalFirstTank	= CreateConVar("no_final_first_tank", "1", "Removes tanks which spawn as the rescue starts on finales.", _, true, 0.0, true, 1.0);
	HookEvent("finale_start", Event_Finale_Start);
	HookEvent("round_start", 	Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", PD_ev_TankSpawn, EventHookMode_PostNoCopy);
	
	g_bEnableNoFinalFirstTank = GetConVarBool(g_hEnableNoFinalFirstTank);
	HookConVarChange(g_hEnableNoFinalFirstTank, Enable_CvarChange);
}

public OnMapStart()
{
	//強制rescue Second tank出生在一樣的位置
	g_bFixed = false;
	Tank_firstround_spawn = false;
	ClearVec();
}

public Action:Event_Finale_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(IsTankProhibit()) return;
	if(!g_bEnableNoFinalFirstTank)  return;
	
	if(IsFinalMap()||Is_Final_Stage()){
		resuce_start = true;
		CreateTimer(0.1, On_t_Instruction);
	}
}

public Action:On_t_Instruction(Handle:timer)
{
	PrintToChatAll("\x05救援開始 \x01後只有 \x04一隻Tank!"); 
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	resuce_start = false;
	HasBlockFirstTank = false;
	timercheck = false;
}

public Action:PD_ev_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnableNoFinalFirstTank && resuce_start)
	{
		if(!HasBlockFirstTank)
		{
			CreateTimer(0.1, KillFirstTank);
			
			//PrintToChatAll("block First Tank");
			PrintToChatAll("\x01Block \x04Tank \x01spawn, \x05continue final rescue progress\x01!");
			return;
		}
		else
		{
			//PrintToChatAll("Second Tank Spawn");
			if (!InSecondHalfOfRound())
			{
				if(!Tank_firstround_spawn){
					new iTank = IsTankInGame();
					if (iTank){
						GetEntPropVector(iTank, Prop_Send, "m_angRotation", g_fTankData_angel);
						GetEntPropVector(iTank, Prop_Send, "m_vecOrigin", g_fTankData_origin);
						//PrintToChatAll("round1 tank pos: %.1f %.1f %.1f", vector[0], vector[1], vector[2]);
						Tank_firstround_spawn = true;
					}
				}
			}
			else
			{
				if(g_bFixed || !Tank_firstround_spawn) return;
				
				new iTank = IsTankInGame();
				if (iTank){

					TeleportEntity(iTank, g_fTankData_origin, g_fTankData_angel, NULL_VECTOR);
					//PrintToChatAll("teleport '%N' to round1 pos.", iTank);
					g_bFixed = true;
				}
			}
		}
	}
	
}
public Action:KillFirstTank(Handle:timer)
{
	if(timercheck) return;
	timercheck = true;
	
	new iTank = IsTankInGame();
	if(iTank && IsClientConnected(iTank) && IsClientInGame(iTank))
	{
		//PrintToChatAll("kill First Tank");
		ForcePlayerSuicide(iTank);
		HasBlockFirstTank = true;
	}
}
public Enable_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	g_bEnableNoFinalFirstTank = GetConVarBool(g_hEnableNoFinalFirstTank);
}


static bool:IsTankProhibit()//犧牲最後一關
{
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);
	return StrEqual(sMap, "l4d_river03_port");
}

static bool:Is_Final_Stage()//非官方圖最後一關
{
	decl String:mapbuf[32];
	GetCurrentMap(mapbuf, sizeof(mapbuf));
	if(StrEqual(mapbuf, "l4d_vs_city17_05")||
	StrEqual(mapbuf, "l4d_vs_deadflagblues05_station")||
	StrEqual(mapbuf, "l4d_ihm05_lakeside")||
	StrEqual(mapbuf, "l4d_vs_stadium5_stadium")||
	StrEqual(mapbuf, "l4d_dbd_new_dawn")||
	StrEqual(mapbuf, "l4d_jsarena04_arena")
	)
		return true;
	return false;
}

IsTankInGame(exclude = 0)
{
	for (new i = 1; i <= MaxClients; i++)
		if (exclude != i && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerTank(i) && IsInfectedAlive(i) && !IsIncapacitated(i))
			return i;

	return 0;
}

bool:InSecondHalfOfRound()
{
	return GameRules_GetProp("m_bInSecondHalfOfRound");
}

static ClearVec()
{
	for (new index; index < 3; index++){
		g_fTankData_origin[index] = 0.0;
		g_fTankData_angel[index] = 0.0;
	}
}
