#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4downtown>
#include <l4d_direct>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY

//static		bool:g_bWasFlipped, bool:g_bSecondRound;
static	queuedTank, String:tankSteamId[32], Handle:hTeamTanks, Handle:hTeamFinalTanks, Handle:g_hCvarInfLimit;
static		bool:IsSecondTank,bool:IsFinal;	
public Plugin:myinfo = {
	name = "L4D Tank Control",
	author = "Jahze, vintik, raziEiL [disawar1]",
	version = "1.5",
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
	/*
	if (FindConVar("l4d_team_manager_ver") != INVALID_HANDLE)
	{
		//FindValidTeam();	
		
		if (!g_bSecondRound)
			g_bWasFlipped = false;
		else
			g_bWasFlipped = true;
		
	}
	else
		g_bWasFlipped = bool:GameRules_GetProp("m_bAreTeamsFlipped");
	*/	
	queuedTank = 0;
	IsSecondTank = false;
	ChoseTankAndPrintWhoBecome();
}

public OnPluginStart()
{
	g_hCvarInfLimit = FindConVar("z_max_player_zombies");
	
	hCvarFlags = CreateConVar("tank_control_disable", "0", "if set, no Forces each player to play the tank at once,1=disabled", CVAR_FLAGS, true, 0.0, true, 1.0);
	gCvarFlags = CreateConVar("tank_control_clear_team", "0", "clear who_has_been_tank_arraylist for certain team, useful when map change. 1 = both sur and inf teams", CVAR_FLAGS, true, 0.0);
	
	HookEvent("round_end", TC_ev_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_team", TC_ev_OnTeamChange);
	HookEvent("player_left_start_area", TC_ev_LeftStartAreaEvent, EventHookMode_PostNoCopy);
	HookEvent("finale_start", Event_Finale_Start);
	
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

public TC_ev_LeftStartAreaEvent(Handle:event, String:name[], bool:dontBroadcast)
{
	ChoseTankAndPrintWhoBecome();
}

public Action:Command_SetTank(client, args)
{
	if (args < 1 || args > 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_settank <player> - force this player will become the tank");
		return Plugin_Handled;
	}
	
	new player_id;

	new String:player[64];
	
	GetCmdArg(1, player, sizeof(player));
	player_id = FindTarget(client, player, true /*nobots*/, false /*immunity*/);
	
	if(player_id == -1)
		return Plugin_Handled;	
	
	if(GetClientTeam(player_id) != 3)
	{
		ReplyToCommand(client, "[SM] <%N> is not in infected team",player_id);
		return Plugin_Handled;
	}
	
	queuedTank = player_id;
	CPrintToChatAll("{green}[我是坦]{default} Adm forces {red}%N {default}will become the {green}tank{default}!", queuedTank); 
	
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
					CPrintToChat(i, "{green}[搶坦之亂] {default}每人已當過{green} tank{default}，{olive}自由搶坦{default}!"); 
		}
		else if (queuedTank>0)
			for (new i = 1; i < MaxClients+1; i++)
				if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i) && GetClientTeam(i) == iTeam)
					CPrintToChat(i, "{green}[我是坦]{red} %N {default}will become the {green}tank{default}!", queuedTank); 
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
	resuce_start = false;
	IsSecondTank = false;
	queuedTank = 0;
	if(IsNewMission()||Is_First_Stage())
	{
		ClearArray(hTeamTanks);
		ClearArray(hTeamFinalTanks);
	}
	IsFinal = (IsFinalMap())? true: false;
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

public TC_ev_RoundEnd(Handle:event, String:name[], bool:dontBroadcast)
{
	queuedTank = 0;
	resuce_start = false;
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
	ChooseTank();
	if (queuedTank>0) {
		for (new i = 1; i < MaxClients+1; i++) {
			if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i)) {
				CPrintToChat(i, "{green}[我是坦]{red} %N {default}will become the {green}tank{default}!", queuedTank); 
			}
		}
	}
	else if (queuedTank==-1){
		for (new i = 1; i < MaxClients+1; i++) {
			if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i)) {
				CPrintToChat(i, "{green}[搶坦之亂] {red}特感隊伍{default} 每人已當過{green} tank{default}，{olive}自由搶坦{default}!"); 
			}
		}
	}
	else if (queuedTank==-2){
		CPrintToChatAll("{green}[提示] {red}特感隊伍 {default}沒有人，無法選 {green}Tank{default}.");
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

			//PrintHintText(i, "Rage Meter Refilled");
			PrintToChat(i, "\x04[Tank] \x01(\x05%N\x01) \x04Tank Rage Meter Refilled.", tank_index);
			if (GetClientTeam(i) == 1)
				continue;
			CPrintToChat(i, "{green}[Tank] {default}不會換人，剩下 {red}1 {default}次控制權!");
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

public Action:Event_Finale_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	resuce_start = true;
}
