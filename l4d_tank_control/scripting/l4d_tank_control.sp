#pragma semicolon 1
#include <sourcemod>
#include <colors>
#include <sdkhooks>
#include <sdktools>
#include <left4downtown>
#include <l4d_direct>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY

native Is_Ready_Plugin_On();

//static		bool:g_bWasFlipped, bool:g_bSecondRound;
static	queuedTank, String:tankSteamId[32], Handle:hTeamTanks, Handle:hTeamFinalTanks, Handle:g_hCvarInfLimit;
static		bool:IsSecondTank,bool:IsFinal;	
static bool:g_bIsTankAlive;
static Handle:sdkReplaceWithBot = INVALID_HANDLE;
static const String:GAMEDATA_FILENAME[]             = "l4daddresses";

public Plugin:myinfo = {
	name = "L4D Tank Control",
	author = "Jahze, vintik, raziEiL [disawar1], Harry Potter",
	version = "1.7",
	description = "Forces each player to play the tank at least once before Map change."
};

static bool:g_bCvartankcontroldisable,Handle:hCvarFlags, Handle:gCvarFlags;
static bool:resuce_start = false;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("ChoseTankPrintWhoBecome", Native_ChoseTankPrintWhoBecome);
	CreateNative("WhoIsTank", Native_WhoIsTank);
	return APLRes_Success;
}

public Native_WhoIsTank(Handle:plugin, numParams)
{
	return queuedTank;
}

public Native_ChoseTankPrintWhoBecome(Handle:plugin, numParams)
{
	if (IsPluginDisabled()) return;
	

	if(queuedTank > 0 && IsClientInGame(queuedTank) && GetClientTeam(queuedTank) == 3)
	{
		CPrintToChatAll("{green}[IamTank]{red} %N {default}will become the {green}tank{default}!", queuedTank); 
	}
	else
		ChoseTankAndPrintWhoBecome();
}

public OnPluginStart()
{
	Require_L4D();
	g_hCvarInfLimit = FindConVar("z_max_player_zombies");
	
	hCvarFlags = CreateConVar("tank_control_disable", "0", "if set, no Forces each player to play the tank at once,1=disabled", CVAR_FLAGS, true, 0.0, true, 1.0);
	gCvarFlags = CreateConVar("tank_control_clear_team", "0", "clear who_has_been_tank_arraylist for certain team, useful when map change. 1 = both sur and inf teams", CVAR_FLAGS, true, 0.0);
	
	HookEvent("player_team", TC_ev_OnTeamChange);
	HookEvent("player_left_start_area", TC_ev_LeftStartAreaEvent, EventHookMode_PostNoCopy);
	HookEvent("round_start", TC_ev_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("finale_start", Event_Finale_Start);
	//for linux
	if(IsWindowsOrLinux() == 2)
	{
		HookEvent("tank_spawn", TC_ev_TankSpawn, EventHookMode_PostNoCopy);
		HookEvent("entity_killed",		TC_ev_EntityKilled);
		PrepSDKCalls();
	}
	
	HookConVarChange(hCvarFlags, OnCvarChange_tank_control_disable);
	HookConVarChange(gCvarFlags, OnCvarChange_clear_hasbeentank_team);
	
	RegConsoleCmd("sm_tank", Command_FindNexTank);
	RegConsoleCmd("sm_t", Command_FindNexTank);
	RegConsoleCmd("sm_boss", Command_FindNexTank);
	RegAdminCmd("sm_settank", Command_SetTank, ADMFLAG_BAN, "sm_settank <player> - force this player will become the tank");
	
	//hTeamATanks = CreateArray(32);
	//hTeamBTanks = CreateArray(32);
	hTeamTanks = CreateArray(64);
	hTeamFinalTanks = CreateArray(64);
	
	g_bCvartankcontroldisable = GetConVarBool(hCvarFlags);
}

stock Require_L4D()
{
    decl String:game[32];
    GetGameFolderName(game, sizeof(game));
    if (!StrEqual(game, "left4dead", false))
    {
        SetFailState("Plugin supports Left 4 Dead 1 only.");
    }
}

public TC_ev_LeftStartAreaEvent(Handle:event, String:name[], bool:dontBroadcast)
{
	if(!Is_Ready_Plugin_On())
		ChoseTankAndPrintWhoBecome();
}

public Action:Command_SetTank(client, args)
{
	if (args < 1 || args > 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_settank <player> - force this player will become the tank");
		return Plugin_Handled;
	}
	
	decl String:target[64];
	GetCmdArgString(target, sizeof(target));
	new player_id = FindTarget(client, target, true /*nobots*/, false /*immunity*/);
	
	if(player_id == -1)
		return Plugin_Handled;	
	
	if(GetClientTeam(player_id) != 3)
	{
		ReplyToCommand(client, "[SM] <%N> is not in infected team",player_id);
		return Plugin_Handled;
	}
	
	queuedTank = player_id;
	CPrintToChatAll("{green}[IamTank]{default} Adm forces {red}%N {default}will become the {green}tank{default}!", queuedTank); 
	
	return Plugin_Handled;	
}

public Action:Command_FindNexTank(client, args)
{
	if (client<=0 || IsPluginDisabled()) return Plugin_Handled;

	new iTeam = GetClientTeam(client);
	if(iTeam != 2){
		if(queuedTank== -2)
			ChooseTank();
		if(queuedTank== -1){
			for (new i = 1; i < MaxClients+1; i++)
				if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i) && GetClientTeam(i) == iTeam)
					CPrintToChat(i, "{green}[IamTank] {default}Everyone has been{green} tank{default} at once，{olive}random now{default}!"); 
		}
		else if (queuedTank>0)
			for (new i = 1; i < MaxClients+1; i++)
				if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i) && GetClientTeam(i) == iTeam)
					CPrintToChat(i, "{green}[IamTank]{red} %N {default}will become the {green}tank{default}!", queuedTank); 
	}
	PrintTankOwners(client);
	return Plugin_Handled;
}

PrintTankOwners(client)//給玩家debug用,查看那些人已經當過tank
{
	new iMaxArray = GetArraySize(hTeamTanks);
	new iMaxArrayFinal = GetArraySize(hTeamFinalTanks);
	decl String:sTankSteamId[64], i;

	PrintToConsole(client, "The tanks were in control of:");
	
	for (new iIndex; iIndex < iMaxArray; iIndex++){

		GetArrayString(hTeamTanks, iIndex, sTankSteamId, sizeof(sTankSteamId));
		if ((i= GetPlayerBySteamId(sTankSteamId))){

			PrintToConsole(client, "0%d. %N [%s]", iIndex + 1, i, sTankSteamId);
		}
		else
			PrintToConsole(client, "0%d. (left the team) [%s]", iIndex + 1, sTankSteamId);
			
	}
	
	if(IsFinal){
		PrintToConsole(client, "The Final tanks were in control of:");
		
		for (new iIndex; iIndex < iMaxArrayFinal; iIndex++){

			GetArrayString(hTeamFinalTanks, iIndex, sTankSteamId, sizeof(sTankSteamId));
			if ((i= GetPlayerBySteamId(sTankSteamId))){

				PrintToConsole(client, "0%d. %N [%s]", iIndex + 1, i, sTankSteamId);
			}
			else
				PrintToConsole(client, "0%d. (left the team) [%s]", iIndex + 1, sTankSteamId);
				
		}
	}
}

public OnMapStart()//每個地圖的第一關載入時清除所有has been tank list
{
	if(IsNewMission()||Is_First_Stage())
	{
		ClearArray(hTeamTanks);
		ClearArray(hTeamFinalTanks);
	}
	IsFinal = (IsFinalMap())? true: false;
}
public Action:TC_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bIsTankAlive = false;
	queuedTank = 0;
	resuce_start = false;
	IsSecondTank = false;
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

public TC_ev_OnTeamChange(Handle:event, String:name[], bool:dontBroadcast)
{
	if (IsPluginDisabled()) return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(1.0,PlayerChangeTeamCheck,client);//延遲一秒檢查
}
public Action:PlayerChangeTeamCheck(Handle:timer,any:client)
{
	if (client && client == queuedTank)
		if(!IsClientInGame(client) || GetClientTeam(client)!=3)
			ChoseTankAndPrintWhoBecome();
}
public OnClientDisconnect(client)
{
	if (IsPluginDisabled()) return;

	if (client && client == queuedTank)
		ChoseTankAndPrintWhoBecome();
}

ChoseTankAndPrintWhoBecome()
{
	if (IsPluginDisabled()) return;
	ChooseTank();
	if (queuedTank>0) {
		for (new i = 1; i < MaxClients+1; i++) {
			if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i)) {
				CPrintToChat(i, "{green}[IamTank]{red} %N {default}will become the {green}tank{default}!", queuedTank); 
			}
		}
	}
	else if (queuedTank==-1){
		for (new i = 1; i < MaxClients+1; i++) {
			if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i)) {
				CPrintToChat(i, "{green}[IamTank] {default}Everyone has been{green} tank{default} at once，{olive}random now{default}!"); 
			}
		}
	}
	else if (queuedTank==-2){
		CPrintToChatAll("{green}[IamTank] {default}There are no {red}Infected players {default}at this moment.");
	}
}

public Action:L4D_OnTryOfferingTankBot(tank_index, &bool:enterStatis)
{
	if (IsPluginDisabled()) 
		return Plugin_Continue;
			
	if(resuce_start)
	{
		new Handle:BlockFirstTank = FindConVar("no_final_first_tank");
		if(BlockFirstTank != INVALID_HANDLE)
		{
			if(GetConVarInt(BlockFirstTank) == 1)
			{
				resuce_start = false;
				return Plugin_Continue;
			}
		}
	}
		
	if(tank_index<=0) return Plugin_Continue;
	if (!IsFakeClient(tank_index)){

		for (new i=1; i <= MaxClients; i++) {
			if (!IsClientInGame(i))
				continue;

			if (GetClientTeam(i) == 2)
				continue;

			if(L4DDirect_GetTankPassedCount() >= 2)
				return Plugin_Continue;
				
			//PrintHintText(i, "Rage Meter Refilled");
			PrintToChat(i, "\x04[Tank] \x01(\x05%N\x01) \x04Tank Rage Meter Refilled.", tank_index);
			if (GetClientTeam(i) == 1)
				continue;
			CPrintToChat(i, "{green}[Tank] {default}won't pass，Only {red}1 {default}control left!");
		}
		SetTankFrustration(tank_index, 100);
		L4DDirect_SetTankPassedCount(L4DDirect_GetTankPassedCount() + 1);
		
		return Plugin_Handled;
	}

	if(IsSecondTank && queuedTank<=0)//第二隻克以後
	{
		//for (new i=1; i <= MaxClients; i++)
		//	if(IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i) && (GetClientTeam(i) == 1||GetClientTeam(i) == 3 ))
		//		CPrintToChat(i, "{green}[Tank] {green}Tank {default}隨機選人當.");
		ChooseTank();
		if(queuedTank == -1 && IsFinal) //最後一關所有人都當過另外重新輪盤 第二隻以後的克皆是不同的人當
			ChooseFinalTank();
	}
	else if (queuedTank == -2)//本來特感沒有人 現在克復活再選一次人
	{
		ChooseTank();
	}
	else if (queuedTank == -1)//自由搶第一隻克
	{
		CreateTimer(5.0, CheckForAITank, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	if (queuedTank>0){
		ForceTankPlayer(queuedTank);//強制該玩家當tank
		PushArrayString(hTeamTanks, tankSteamId);
		if(IsFinal)
			PushArrayString(hTeamFinalTanks, tankSteamId);
		queuedTank = 0;
	}
	IsSecondTank = true;//已經第一隻Tank了
	return Plugin_Continue;
}

public Action:TC_ev_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (IsPluginDisabled() || resuce_start || IsSecondTank || g_bIsTankAlive) 
		return;
	
	new tankclient = GetClientOfUserId(GetEventInt(event, "userid"));
	new Float:PlayerControlDelay = GetConVarFloat(FindConVar("director_tank_lottery_selection_time"));
	if(IsFakeClient(tankclient))
	{
		g_bIsTankAlive = true;
		
		if (queuedTank == -2)//本來特感沒有人 現在克復活再選一次人
		{
			ChooseTank();
		}
		else if (queuedTank == -1)//自由搶第一隻克
		{
			CreateTimer(5.0, CheckForAITank, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		IsSecondTank = true;//已經第一隻Tank了
	}
	CreateTimer(PlayerControlDelay-0.1, ForcePlayerBecomeTank, tankclient, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:ForcePlayerBecomeTank(Handle:timer,any:tankclient)
{
	if(queuedTank<=0 || !IsClientInGame(queuedTank) || IsFakeClient(queuedTank) || GetClientTeam(queuedTank)!=3) return;
	
	//強制該玩家當tank
	if (GetClientHealth(queuedTank) > 1 && !IsPlayerGhost(queuedTank))
	{
		L4DD_ReplaceWithBot(queuedTank, true);
	}
	L4DD_ReplaceTank(tankclient, queuedTank);
	L4DDirect_SetTankPassedCount(L4DDirect_GetTankPassedCount() + 1);
	
	PushArrayString(hTeamTanks, tankSteamId);
	if(IsFinal)
		PushArrayString(hTeamFinalTanks, tankSteamId);
	queuedTank = 0;
}

public Action:TC_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl client;
	if (g_bIsTankAlive && IsPlayerTank((client = GetEventInt(event, "entindex_killed"))))
	{
		CreateTimer(1.5, FindAnyTank, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:FindAnyTank(Handle:timer, any:client)
{
	if(!IsTankInGame()){
		g_bIsTankAlive = false;
	}
}

public Action:CheckForAITank(Handle:timer)
{

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && GetEntProp(i, Prop_Send, "m_zombieClass") == 5)
		{
			if (!IsFakeClient(i))//Tank is not AI
			{
				//PrintToChatAll("%N is first tank",i);
				GetClientAuthString(i, tankSteamId, sizeof(tankSteamId));
				if(HasBeenTank(tankSteamId) == false)
					PushArrayString(hTeamTanks, tankSteamId);
				if(IsFinal)
					PushArrayString(hTeamFinalTanks, tankSteamId);
			}
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

static ChooseFinalTank() {

	decl String:SteamId[32];
	new Handle:SteamIds = CreateArray(32);
	new infectedplayer = 0;

	for (new i = 1; i < MaxClients+1; i++) {
		if (!IsClientConnected(i) || !IsClientInGame(i) ||IsFakeClient(i)) {
			continue;
		}
		if(IsInfected(i))
			infectedplayer++;
		
		if(!IsInfected(i))
			continue;

		GetClientAuthString(i, SteamId, sizeof(SteamId));

		if (HasBeenFinalTank(SteamId) || i == queuedTank) {
			continue;
		}

		PushArrayString(SteamIds, SteamId);
	}

	if (GetArraySize(SteamIds) == 0) {//沒有人可以成為tank
		if(infectedplayer == 0)//1.SI沒有人
			queuedTank = -2;
		else//2.代表兩邊的隊伍都找過 特感這裡所有人都當過tank
			queuedTank = -1;
		return;
	}

	new idx = GetRandomInt(0, GetArraySize(SteamIds)-1);
	GetArrayString(SteamIds, idx, tankSteamId, sizeof(tankSteamId));
	queuedTank = GetInfectedPlayerBySteamId(tankSteamId);
}

static bool:HasBeenFinalTank(const String:SteamId[])
{
	if(FindStringInArray(hTeamFinalTanks, SteamId) != -1)
		return true;
	else
		return false;
}

static bool:HasBeenTank(const String:SteamId[])
{
	if(FindStringInArray(hTeamTanks, SteamId) != -1)
		return true;
	else
		return false;
}

static ChooseTank() {

	decl String:SteamId[32];
	new Handle:SteamIds = CreateArray(32);
	new infectedplayer = 0;

	for (new i = 1; i < MaxClients+1; i++) {
		if (!IsClientConnected(i) || !IsClientInGame(i) ||IsFakeClient(i)) {
			continue;
		}
		if(IsInfected(i))
			infectedplayer++;
		
		if(!IsInfected(i))
			continue;

		GetClientAuthString(i, SteamId, sizeof(SteamId));

		if (HasBeenTank(SteamId) || i == queuedTank) {
			continue;
		}

		PushArrayString(SteamIds, SteamId);
	}

	if (GetArraySize(SteamIds) == 0) {//沒有人可以成為tank
		if(infectedplayer == 0)//1.SI沒有人
			queuedTank = -2;
		else//2.代表兩邊的隊伍都找過 特感這裡所有人都當過tank
			queuedTank = -1;
		return;
	}

	new idx = GetRandomInt(0, GetArraySize(SteamIds)-1);
	GetArrayString(SteamIds, idx, tankSteamId, sizeof(tankSteamId));
	queuedTank = GetInfectedPlayerBySteamId(tankSteamId);
}

static ForceTankPlayer(iTank) {
	for (new i = 1; i < MaxClients+1; i++) {
		if (!IsClientConnected(i) || !IsClientInGame(i)) {
			continue;
		}

		if (IsInfected(i)) {
			if (iTank == i) {
				L4DDirect_SetTankTickets(i, 1000);
			}
			else {
				L4DDirect_SetTankTickets(i, 0);
			}
		}
	}
}

static GetInfectedPlayerBySteamId(const String:SteamId[]) {
	decl String:cmpSteamId[32];

	for (new i = 1; i < MaxClients+1; i++) {
		if (!IsClientConnected(i)) {
			continue;
		}

		if (!IsInfected(i)) {
			continue;
		}

		GetClientAuthString(i, cmpSteamId, sizeof(cmpSteamId));

		if (StrEqual(SteamId, cmpSteamId)) {
			return i;
		}
	}

	return 0;
}
/*
static GetSurvivorPlayerBySteamId(const String:SteamId[]) {
	decl String:cmpSteamId[32];

	for (new i = 1; i < MaxClients+1; i++) {
		if (!IsClientConnected(i)) {
			continue;
		}

		if (!IsSurvivor(i)) {
			continue;
		}

		GetClientAuthString(i, cmpSteamId, sizeof(cmpSteamId));

		if (StrEqual(SteamId, cmpSteamId)) {
			return i;
		}
	}

	return 0;
}*/

static GetPlayerBySteamId(const String:SteamId[]) {
	decl String:cmpSteamId[32];

	for (new i = 1; i < MaxClients+1; i++) {
		if (!IsClientConnected(i)) {
			continue;
		}

		GetClientAuthString(i, cmpSteamId, sizeof(cmpSteamId));

		if (StrEqual(SteamId, cmpSteamId)) {
			return i;
		}
	}

	return 0;
}

bool:IsPluginDisabled()
{
	if(g_bCvartankcontroldisable)
		return true;
	return GetConVarInt(g_hCvarInfLimit) == 1;
}

// Support l4d scores
/*
FindValidTeam()
{
	new bool:bWasFlipped;

	if (!g_bSecondRound)
		bWasFlipped = false;
	else
		bWasFlipped = true;

	g_bWasFlipped = bWasFlipped;

	if (!bWasFlipped){

		new iMaxArrayA = GetArraySize(hTeamATanks);
		new iMaxArrayB = GetArraySize(hTeamBTanks);

		if (!iMaxArrayA && !iMaxArrayB)
			return;

		decl String:sTankSteamId[64];

		new iMatchA, iMatchB, iNotMatchesA = iMaxArrayA, iNotMatchesB = iMaxArrayB;

		if (iMaxArrayA){

			for (new iIndex; iIndex < iMaxArrayA; iIndex++){

				GetArrayString(hTeamATanks, iIndex, sTankSteamId, sizeof(sTankSteamId));
				if (GetInfectedPlayerBySteamId(sTankSteamId)){
					iMatchA++;
				}
			}
		}
		if (iMaxArrayB){

			for (new iIndex; iIndex < iMaxArrayB; iIndex++){

				GetArrayString(hTeamBTanks, iIndex, sTankSteamId, sizeof(sTankSteamId));
				if (GetSurvivorPlayerBySteamId(sTankSteamId)){
					iMatchB++;
				}
			}
		}

		iNotMatchesA -= iMatchA;
		iNotMatchesB -= iMatchB;

		if (iNotMatchesA >= iMatchA && iNotMatchesB >= iMatchB){

			g_bWasFlipped = true;
			g_bBug = true;
		}
	}
	else if (bWasFlipped && g_bBug)
		g_bWasFlipped = false;

}
*/
public OnCvarChange_tank_control_disable(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_bCvartankcontroldisable = GetConVarBool(convar);	
}

public OnCvarChange_clear_hasbeentank_team(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(IsPluginDisabled())
		return;
	new clear_hasbeentank_team = StringToInt(newValue);
	if(clear_hasbeentank_team == 1)
	{
		ClearArray(hTeamTanks);
		ClearArray(hTeamFinalTanks);
	}	
}

stock IsWindowsOrLinux()
{
     new Handle:conf = LoadGameConfigFile("windowsorlinux");
     new WindowsOrLinux = GameConfGetOffset(conf, "WindowsOrLinux");
     CloseHandle(conf);
     return WindowsOrLinux; //1 for windows; 2 for linux
}

IsTankInGame(exclude = 0)
{
	for (new i = 1; i <= MaxClients; i++)
		if (exclude != i && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerTank(i) && IsInfectedAlive(i) && !IsIncapacitated(i))
			return i;

	return 0;
}

public Action:Event_Finale_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	resuce_start = true;
}

PrepSDKCalls()
{
    new Handle:ConfigFile = LoadGameConfigFile(GAMEDATA_FILENAME);
    new Handle:MySDKCall = INVALID_HANDLE;
    
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "ReplaceWithBot");
    PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
    MySDKCall = EndPrepSDKCall();
    
    if (MySDKCall == INVALID_HANDLE)
    {
        SetFailState("Cant initialize ReplaceWithBot SDKCall");
    }
    
    sdkReplaceWithBot = CloneHandle(MySDKCall, sdkReplaceWithBot);

	
    CloseHandle(ConfigFile);
    CloseHandle(MySDKCall);
}

stock L4DD_ReplaceWithBot(client, boolean)
{
    SDKCall(sdkReplaceWithBot, client, boolean);
}

stock L4DD_ReplaceTank(client, target)
{
    L4DDirect_ReplaceTank(client,target);
}