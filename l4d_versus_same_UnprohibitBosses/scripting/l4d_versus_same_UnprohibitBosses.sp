/*this plugin fix two issues*/
//1.Fix each round tank/Witch spawn different positions for both team
//2.Fix C17 map1 two witches
//The Author: Harry Potter
//Only for L4D1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d_direct>
#include <l4d_lib>
#include <left4downtown>

#pragma semicolon 1
#define PLUGIN_VERSION "1.4"

#define INTRO		0
#define REGULAR	1
#define FINAL		2
#define TANK		0
#define WITCH		1
#define MIN		0
#define MAX		1

static Handle:g_hCvarVsBossChance[3][2], Handle:g_hCvarVsBossFlow[3][2], Float:g_fCvarVsBossChance[3][2], Float:g_fCvarVsBossFlow[3][2];
static	bool:g_bFixed,Float:g_fTankData_origin[3],Float:g_fTankData_angel[3];
static 	Float:fWitchData_agnel[3],Float:fWitchData_origin[3];
static	bool:Tank_firstround_spawn,bool:Witch_firstround_spawn;
static bool:b_IsSecondWitch, bool:b_KillSecondWitch;
new Float:fWitchFlow;
new Handle:WITCHPARTY;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{ 
	CreateNative("SaveWitchPercent",Native_SaveWitchPercent);
	return APLRes_Success;
}

public Native_SaveWitchPercent(Handle:plugin, numParams) {
	new Float:num1 = GetNativeCell(1);
	fWitchFlow = num1;
}

public Plugin:myinfo = 
{
	name = "l4d_versus_same_UnprohibitBosses",
	author = "Harry Potter",
	description = "Force Enable bosses spawning on all maps, and same spawn positions for both team",
	version = PLUGIN_VERSION,
	url = "myself"
}
public OnPluginStart()
{
	//強制每一關生出tank與witch
	g_hCvarVsBossChance[INTRO][TANK] = FindConVar("versus_tank_chance_intro");
	g_hCvarVsBossChance[REGULAR][TANK] = FindConVar("versus_tank_chance");
	g_hCvarVsBossChance[FINAL][TANK] = FindConVar("versus_tank_chance_finale");
	g_hCvarVsBossChance[INTRO][WITCH] = FindConVar("versus_witch_chance_intro");
	g_hCvarVsBossChance[REGULAR][WITCH] = FindConVar("versus_witch_chance");
	g_hCvarVsBossChance[FINAL][WITCH] = FindConVar("versus_witch_chance_finale");
	g_hCvarVsBossFlow[INTRO][MIN]  = FindConVar("versus_boss_flow_min_intro");
	g_hCvarVsBossFlow[INTRO][MAX] = FindConVar("versus_boss_flow_max_intro");
	g_hCvarVsBossFlow[REGULAR][MIN] = FindConVar("versus_boss_flow_min");
	g_hCvarVsBossFlow[REGULAR][MAX] = FindConVar("versus_boss_flow_max");
	g_hCvarVsBossFlow[FINAL][MIN] = FindConVar("versus_boss_flow_min_finale");
	g_hCvarVsBossFlow[FINAL][MAX] = FindConVar("versus_boss_flow_max_finale");
	for (new campaign; campaign < 3; campaign++){

		for (new index; index < 2; index++){

			g_fCvarVsBossChance[campaign][index] = GetConVarFloat(g_hCvarVsBossChance[campaign][index]);
			g_fCvarVsBossFlow[campaign][index] = GetConVarFloat(g_hCvarVsBossFlow[campaign][index]);

			HookConVarChange(g_hCvarVsBossChance[campaign][index], _UB_Common_CvarChange);
			HookConVarChange(g_hCvarVsBossFlow[campaign][index], _UB_Common_CvarChange);
		}
	}

	HookEvent("tank_spawn",			TS_ev_TankSpawn,		EventHookMode_PostNoCopy);
	HookEvent("witch_spawn", TS_ev_WitchSpawn);
	HookEvent("round_start", TS_ev_RoundStart, EventHookMode_PostNoCopy);
}
public TS_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	WITCHPARTY = FindConVar("l4d_multiwitch_enabled");
	b_IsSecondWitch = false;
	b_KillSecondWitch = true;
	
	CreateTimer(2.5,COLD_DOWN);
}

public Action:COLD_DOWN(Handle:timer)
{
	if (InSecondHalfOfRound())
	{
		if(fWitchFlow == 0.0)
			L4DDirect_SetVSWitchToSpawnThisRound(1, false);
		else
		{
			L4DDirect_SetVSWitchToSpawnThisRound(1, false);
			L4DDirect_SetVSWitchToSpawnThisRound(1, true);
			L4DDirect_SetVWitchFlowPercent(1, 0.2);
			L4DDirect_SetVWitchFlowPercent(1, fWitchFlow);
		}
	}
}

public OnMapStart()
{
	//強制每一關生出tank與witch
	new iCampaign = (IsFinalMap()||Is_Final_Stage())? FINAL : (IsNewMission()||Is_First_Stage())? INTRO : REGULAR;
	new Float:fTankFlow =  GetRandomBossFlow(iCampaign);
	if (!IsTankProhibit()){
		
		fTankFlow = SpecialMapTankFlow(fTankFlow,iCampaign);
		
		L4DDirect_SetVSTankToSpawnThisRound(0, true);
		L4DDirect_SetVSTankToSpawnThisRound(1, true);
		L4DDirect_SetVSTankFlowPercent(0, fTankFlow);
		L4DDirect_SetVSTankFlowPercent(1, fTankFlow);
	}
	
	if(WITCHPARTY != INVALID_HANDLE && GetConVarInt(WITCHPARTY) == 1)
	{
		LogMessage("WITCH PARTY Enable, l4d_versus_same_UnprohibitBosses.smx doesn't spawn Witch");
	}
	else
	{
		fWitchFlow = GetRandomBossFlow(iCampaign);
		
		fWitchFlow = SpecialMapWitchFlow(fWitchFlow,iCampaign);
		
		L4DDirect_SetVSWitchToSpawnThisRound(0, true);
		L4DDirect_SetVSWitchToSpawnThisRound(1, true);
		L4DDirect_SetVWitchFlowPercent(0, fWitchFlow);
		L4DDirect_SetVWitchFlowPercent(1, fWitchFlow);
	}
	
	//強制tank出生在一樣的位置
	g_bFixed = false;
	Tank_firstround_spawn = false;
	ClearVec();
	
	//強制witch出生在一樣的位置
	Witch_firstround_spawn = false;
}

static Float:GetRandomBossFlow(iCampaign)
{
	return GetRandomFloat(g_fCvarVsBossFlow[iCampaign][MIN], g_fCvarVsBossFlow[iCampaign][MAX]);
}

static bool:IsTankProhibit()//犧牲第一關與最後一關不要生Tank
{
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);
	return StrEqual(sMap, "l4d_river01_docks") || StrEqual(sMap, "l4d_river03_port")|| StrEqual(sMap, "l4d_forest03_dam");
}

static Float:SpecialMapTankFlow(const Float:fFlow,iCampaign)
{
	new Float:newfFlow = fFlow;
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);
	if(StrEqual(sMap, "l4d_vs_airport05_runway"))
	{
		newfFlow = GetRandomFloat(0.50,0.55);//tank will not spawn when after 55% in this map
	}
	else if(StrEqual(sMap, "l4d_vs_city17_02"))
	{
		new suerte = GetRandomInt(1, 2);
		switch(suerte)//tank will not spawn during infinite horde event in this map	
		{
			case 1: // if is 1
			{
				newfFlow = GetRandomFloat(g_fCvarVsBossFlow[iCampaign][MIN],0.17);
			}
			case 2: // if is 2
			{
				newfFlow = GetRandomFloat(0.53,g_fCvarVsBossFlow[iCampaign][MAX]);
			}
		}
	}
	else if(StrEqual(sMap, "l4d_vs_stadium4_city2")) //tank will not spawn after 80% in this map
	{
		newfFlow = GetRandomFloat(g_fCvarVsBossFlow[iCampaign][MIN],0.8);//tank will not spawn when after 55% in this map
	}
	
	return newfFlow;
}

static Float:SpecialMapWitchFlow(const Float:fFlow,iCampaign)
{
	new Float:newfFlow = fFlow;
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);
	if(StrEqual(sMap, "l4d_vs_airport05_runway"))
	{
		newfFlow = GetRandomFloat(0.50,0.65);//tank will not spawn when after 55% in this map
	}
	else if(StrEqual(sMap, "l4d_vs_stadium4_city2")) //witch will not spawn after 80% in this map
	{
		newfFlow = GetRandomFloat(g_fCvarVsBossFlow[iCampaign][MIN],0.8);
	}
	
	return newfFlow;
}

public _UB_Common_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	for (new campaign; campaign < 3; campaign++){

		for (new index; index < 2; index++){

			if (g_hCvarVsBossChance[campaign][index] == convar)
				g_fCvarVsBossChance[campaign][index] = GetConVarFloat(convar);
			else if (g_hCvarVsBossFlow[campaign][index] == convar)
				g_fCvarVsBossFlow[campaign][index] = GetConVarFloat(convar);
		}
	}
}

public TS_ev_WitchSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( (WITCHPARTY != INVALID_HANDLE && GetConVarInt(WITCHPARTY) == 1) || GetConVarInt(FindConVar("sv_cheats")) == 1 ) return;	
	
	new iEnt = GetEventInt(event, "witchid");
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);
	if(StrEqual(sMap, "l4d_vs_city17_01")){//issue with city17 map1, two witches spawn in this stage, kill second witch spawn
		if(b_IsSecondWitch && b_KillSecondWitch){
			//PrintToChatAll("kill city17_01 second witch...");
			CreateTimer(0.1,ColdDown, iEnt);//延遲一秒檢查
			b_KillSecondWitch = false;
		}
		else
			b_IsSecondWitch = true;
	}	
	
	if(InSecondHalfOfRound() == false)
	{
		if(Witch_firstround_spawn == false)
		{
			GetEntPropVector(iEnt, Prop_Send, "m_angRotation", fWitchData_agnel);
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fWitchData_origin);
			Witch_firstround_spawn = true;
			
			/*for (new index; index < 3; index++){
				PrintToChatAll("Witch first position: %f, %f",fWitchData_agnel[index], fWitchData_origin[index]);
			}*/
		}
	}
	else
	{
		if(Witch_firstround_spawn)
		{
			TeleportEntity(iEnt, fWitchData_origin, fWitchData_agnel, NULL_VECTOR);
			Witch_firstround_spawn = false;
			//PrintToChatAll("轉換妹子到第一回合的位置");
		}
	}
}

public Action:ColdDown(Handle:timer,any:witchid)
{
	if(IsValidEntity(witchid))
		RemoveEdict(witchid);
}

public Action:TS_ev_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
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

IsTankInGame(exclude = 0)
{
	for (new i = 1; i <= MaxClients; i++)
		if (exclude != i && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerTank(i) && IsInfectedAlive(i) && !IsIncapacitated(i))
			return i;

	return 0;
}

static ClearVec()
{
	for (new index; index < 3; index++){
		fWitchData_agnel[index] = 0.0;
		fWitchData_origin[index] = 0.0;
		g_fTankData_origin[index] = 0.0;
		g_fTankData_angel[index] = 0.0;
	}
}

bool:Is_Final_Stage()//非官方圖最後一關
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

bool:Is_First_Stage()//非官方圖第一關
{
	decl String:mapbuf[32];
	GetCurrentMap(mapbuf, sizeof(mapbuf));
	if(StrEqual(mapbuf, "l4d_vs_city17_01")||
	StrEqual(mapbuf, "l4d_vs_deadflagblues01_city")||
	StrEqual(mapbuf, "l4d_vs_stadium1_apartment")||
	StrEqual(mapbuf, "l4d_ihm01_forest")||
	StrEqual(mapbuf, "l4d_dbd_citylights")||
	StrEqual(mapbuf, "l4d_jsarena01_town"))
		return true;
	return false;
}

bool:InSecondHalfOfRound()
{
	return bool:GameRules_GetProp("m_bInSecondHalfOfRound");
}