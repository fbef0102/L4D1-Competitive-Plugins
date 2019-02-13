/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.	 All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program.	If not, see <http://www.gnu.org/licenses/>.
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#undef REQUIRE_PLUGIN
static Handle:g_hCVarMinAllowedSlots;
static Handle:g_hCVarMaxAllowedSlots;

static Handle:g_hCVarMaxPlayersDowntown;
static Handle:g_hCVarMaxPlayersToolZ;

static bool:g_bLeft4Downtown2;
static bool:g_bL4DToolz;

static g_iMinAllowedSlots;
static g_iMaxAllowedSlots;

static g_iCurrentSlots;
static g_iDesiredSlots;

static Handle:g_cvarSlotsPluginEnabled = INVALID_HANDLE;
static Handle:g_cvarSlotsAutoconf	= INVALID_HANDLE;
static Handle:g_cvarSvVisibleMaxPlayers = INVALID_HANDLE;
new bool:g_bSlotsLocked = false;
static g_slotdelay;
new Handle:g_hCvarPlayerLimit;
#define SlotVoteCommandDelay 2.5
new Handle:g_hSlotVote = INVALID_HANDLE;
new Votey = 0;
new Voten = 0;
#define VOTE_NO "no"
#define VOTE_YES "yes"
#define SLOTDELAY_TIME 60
new Handle:g_Cvar_Limits;

public Plugin:myinfo =
{
	name = "L4D Slot Vote",
	author = "X-Blaze & Harry Potter",
	description = "Allow players to change server slots by using vote.",
	version = "2.2-ds-1.2"
};

public OnPluginStart()
{
	LoadTranslations("slotvote.phrases");
	g_cvarSlotsPluginEnabled = CreateConVar("sm_slot_vote_enabled", "1", "Enabled?", FCVAR_PLUGIN);
	g_cvarSlotsAutoconf = CreateConVar("sm_slot_autoconf", "1", "Autoconfigure slots vote max|min cvars?", FCVAR_PLUGIN);
	g_hCVarMinAllowedSlots = CreateConVar("sm_slot_vote_min", "10", "Minimum allowed number of server slots (this value must be equal or lesser than sm_slot_vote_max).", FCVAR_PLUGIN, true, 1.0, true, 32.0);
	g_hCVarMaxAllowedSlots = CreateConVar("sm_slot_vote_max", "25", "Maximum allowed number of server slots (this value must be equal or greater than sm_slot_vote_min).", FCVAR_PLUGIN, true, 1.0, true, 32.0);

	g_hCVarMaxPlayersDowntown = FindConVar("l4d_maxplayers");
	g_hCVarMaxPlayersToolZ = FindConVar("sv_maxplayers");
	g_cvarSvVisibleMaxPlayers = FindConVar("sv_visiblemaxplayers");
	g_iMinAllowedSlots = GetConVarInt(g_hCVarMinAllowedSlots);
	g_iMaxAllowedSlots = GetConVarInt(g_hCVarMaxAllowedSlots);

	//PrintToServer("Slots set onload to: %d", GetConVarInt(g_hCVarMaxPlayersToolZ));
	HookConVarChange(g_hCVarMinAllowedSlots, CVarChangeMinAllowedSlots);
	HookConVarChange(g_hCVarMaxAllowedSlots, CVarChangeMaxAllowedSlots);

	if (g_hCVarMaxPlayersDowntown != INVALID_HANDLE)
	{
		g_iCurrentSlots = GetConVarInt(g_hCVarMaxPlayersDowntown);
		g_bLeft4Downtown2 = true;
	}

	if (g_hCVarMaxPlayersToolZ != INVALID_HANDLE)
	{
		g_iCurrentSlots = GetConVarInt(g_hCVarMaxPlayersToolZ);
		g_bL4DToolz = true;
	}

	//if (g_bLeft4Downtown2 && g_bL4DToolz)
	//{
	//	SetFailState("Please do not use Left4Downtown2 playerslots build with L4DToolz. Slot Vote disabled.");
	//}
	if (!g_bLeft4Downtown2 && !g_bL4DToolz)
	{
		SetFailState("Supported slot patching mods not detected. Slot Vote disabled.");
	}

	if (g_iCurrentSlots == -1)
	{
		g_iCurrentSlots = 8;
	}
	if(GetConVarBool(g_cvarSlotsAutoconf)) {
		new Handle:hSurvivorLimit = FindConVar("survivor_limit");
		//SetConVarInt(g_hCVarMinAllowedSlots, GetConVarInt(hSurvivorLimit) * 2);
		PrintToServer("Min slots automatically configured to %d", GetConVarInt(hSurvivorLimit) * 2);
		CloseHandle(hSurvivorLimit);
	}
	RegConsoleCmd("sm_slots", Cmd_SlotVote);
	RegConsoleCmd("sm_nospec", Cmd_NoSpec);
	RegConsoleCmd("sm_nospecs", Cmd_NoSpec);
	RegConsoleCmd("sm_kickspec", Cmd_NoSpec);
	RegConsoleCmd("sm_kickspecs", Cmd_NoSpec);
	RegConsoleCmd("sm_maxslots", Cmd_SlotVote);
	RegServerCmd("sm_lock_slots", Cmd_LockSlots);
	RegServerCmd("sm_unlock_slots", Cmd_UnLockSlots);
	
	g_hCvarPlayerLimit = CreateConVar("sm_slotvote_player_limit", "3", "Minimum # of players in game to start the vote", FCVAR_PLUGIN);
	g_Cvar_Limits = CreateConVar("sm_matchvotes_s", "0.60", "百分比.", 0, true, 0.05, true, 1.0);
}

public OnMapStart()
{
	g_slotdelay = 15;
	CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
	
	PrecacheSound("ui/menu_enter05.wav");
	PrecacheSound("ui/beep_synthtone01.wav");
	PrecacheSound("ui/beep_error01.wav");
}

public Action:Cmd_LockSlots(args) {	
	g_bSlotsLocked = true;
	PrintToServer("Server slots count locked!");
	PrintToChatAll("Server slots count locked!");
	return Plugin_Handled;
}

public Action:Cmd_UnLockSlots(args) {
	g_bSlotsLocked = false;
	PrintToServer("[SM] Server slots count unlocked!");
	PrintToChatAll("[SM] Server slots count unlocked!");
	return Plugin_Handled;
}

public CVarChangeMinAllowedSlots(Handle:hCVar, const String:sOldValue[], const String:sNewValue[])
{
	if(!GetConVarBool(g_cvarSlotsPluginEnabled)) return;
	g_iMinAllowedSlots = StringToInt(sNewValue);

	if (g_iMinAllowedSlots > g_iMinAllowedSlots)
	{
		g_iMinAllowedSlots = g_iMaxAllowedSlots;
	}
}

public CVarChangeMaxAllowedSlots(Handle:hCVar, const String:sOldValue[], const String:sNewValue[])
{
	if(!GetConVarBool(g_cvarSlotsPluginEnabled)) return;
	g_iMaxAllowedSlots = StringToInt(sNewValue);

	if (g_iMinAllowedSlots > g_iMaxAllowedSlots)
	{
		g_iMaxAllowedSlots = g_iMinAllowedSlots;
	}
}

public Action:Cmd_SlotVote(iClient, iArgs)
{
	if(g_bSlotsLocked) {
		PrintToChat(iClient, "[SM] You can not change slots count. It's locked by config or admin.");
		return Plugin_Handled;
	}
	if(!GetConVarBool(g_cvarSlotsPluginEnabled)) return Plugin_Handled;
	
	if(iClient < 1) return Plugin_Handled;

	if(GetAdminFlag(GetUserAdmin(iClient), Admin_Generic))
	{
		if (iArgs == 1)
		{
			decl String:buf[3];
			GetCmdArg(1, buf, sizeof(buf));
			g_iDesiredSlots = StringToInt(buf);
			
			if (g_iDesiredSlots == g_iCurrentSlots)
			{
				CPrintToChat(iClient, "%t", "Same as current", g_iDesiredSlots);
				return Plugin_Handled;
			}

			if (g_iDesiredSlots >= g_iMinAllowedSlots && g_iDesiredSlots <= g_iMaxAllowedSlots)
			{
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%N{default} Changes Server Slots: {green}%d{default} - > {green}%d",iClient,g_iCurrentSlots,g_iDesiredSlots);
				ChangeSeverSlots();
			}
			else
			{
				CPrintToChat(iClient, "%t", "Usage", g_iMinAllowedSlots, g_iMaxAllowedSlots);
			}
			return Plugin_Handled;
		}
	}
	
	if (GetClientTeam(iClient) == 1)
	{
		PrintToChat(iClient, "%t", "Spectator response");
		return Plugin_Handled;
	}
	
	if (!TestVoteDelay(iClient))
	{
		return Plugin_Handled;
	}
	
	if (CanStartVotes(iClient))
	{
		if (iArgs == 1)
		{
			decl String:sArgs[4];
			GetCmdArg(1, sArgs, sizeof(sArgs));

			g_iDesiredSlots = StringToInt(sArgs);

			if (g_iDesiredSlots == g_iCurrentSlots)
			{
				CPrintToChat(iClient, "%t", "Same as current", g_iDesiredSlots);
				return Plugin_Handled;
			}

			if (g_iDesiredSlots >= g_iMinAllowedSlots && g_iDesiredSlots <= g_iMaxAllowedSlots)
			{
				CreateTimer(0.1, Timer_StartSlotVote, iClient, TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				CPrintToChat(iClient, "%t", "Usage", g_iMinAllowedSlots, g_iMaxAllowedSlots);
			}

			return Plugin_Handled;
		}
		CreateTimer(0.1, Timer_CreateSlotMenu, iClient, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		PrintToChat(iClient, "%t", "Vote denied");
	}

	return Plugin_Handled;
}

public Action:Timer_StartSlotVote(Handle:hTimer, any:iClient)
{
	if (IsClientInGame(iClient) && GetClientTeam(iClient) > 1)
	{
		StartSlotVote(iClient);
	}
}

public Action:Timer_CreateSlotMenu(Handle:hTimer, any:iClient)
{
	if (IsClientInGame(iClient) && GetClientTeam(iClient) > 1)
	{
		CreateSlotMenu(iClient);
	}
}

public Action:Cmd_NoSpec(iClient, iArgs)
{
	if(g_bSlotsLocked) {
		PrintToChat(iClient, "[SM] You can not kick specs. It's locked by config or admin.");
		return Plugin_Handled;
	}
	if(!GetConVarBool(g_cvarSlotsPluginEnabled)) return Plugin_Handled;
	
	new iSpecs = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)
		&&	!IsFakeClient(i)
		&&	GetClientTeam(i) == 1)
		{
			iSpecs++;
		}
	}

	if (iSpecs == 0)
	{
		PrintToChat(iClient, "%t", "No spectators");
		return Plugin_Handled;
	}

	if(GetAdminFlag(GetUserAdmin(iClient), Admin_Generic))
	{
		CPrintToChatAll("[{olive}TS{default}] {lightgreen}%N{default} kicks all spectators.",iClient);
		KickAllSpectators();
		return Plugin_Handled;
	}

	if (GetClientTeam(iClient) == 1)
	{
		PrintToChat(iClient, "%t", "Spectator response");
		return Plugin_Handled;
	}
	
	CreateTimer(0.1, Timer_StartNoSpecVote, iClient, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Handled;
}

public Action:Timer_StartNoSpecVote(Handle:hTimer, any:iClient)
{
	if (IsClientInGame(iClient) && GetClientTeam(iClient) > 1)
	{
		StartNoSpecVote(iClient);
	}
}

static CreateSlotMenu(iClient)
{
	new Handle:hSlotMenu = CreateMenu(MenuHandler_SlotMenu);

	decl String:sBuffer[256], String:sCycle[4];

	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slot vote title", iClient, g_iCurrentSlots);
	SetMenuTitle(hSlotMenu, sBuffer);

	for (new i = g_iMinAllowedSlots; i <= g_iMaxAllowedSlots; i++)
	{
		FormatEx(sCycle, sizeof(sCycle), "%i", i);
		FormatEx(sBuffer, sizeof(sBuffer), "%i %T", i, "Slots", iClient);
		AddMenuItem(hSlotMenu, sCycle, sBuffer);
	}

	SetMenuExitButton(hSlotMenu, true);
	DisplayMenu(hSlotMenu, iClient, 30);
}

public MenuHandler_SlotMenu(Handle:hSlotMenu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[3];

		if (GetMenuItem(hSlotMenu, param2, sInfo, sizeof(sInfo)))
		{
			g_iDesiredSlots = StringToInt(sInfo);
			
			if (g_hCVarMaxPlayersDowntown != INVALID_HANDLE)
			{
				g_iCurrentSlots = GetConVarInt(g_hCVarMaxPlayersDowntown);
			}
			else if (g_hCVarMaxPlayersToolZ != INVALID_HANDLE)
			{
				g_iCurrentSlots = GetConVarInt(g_hCVarMaxPlayersToolZ);
			}
			if (g_iDesiredSlots == g_iCurrentSlots)
			{
				CPrintToChat(param1, "%t", "Same as current", g_iDesiredSlots);
				return;
			}

			StartSlotVote(param1);
		}
	}

	if (action == MenuAction_End)
	{
		CloseHandle(hSlotMenu);
	}
}

static StartSlotVote(iClient)
{
	if (GetClientTeam(iClient) == 1)
	{
		PrintToChat(iClient, "%t", "Spectator response");
		return;
	}

	if (CanStartVotes(iClient))
	{
		decl String:SteamId[35];
		GetClientAuthString(iClient, SteamId, sizeof(SteamId));
		LogMessage("%N(%s) starts a vote: Change server slots to %i?",  iClient, SteamId,g_iDesiredSlots);//紀錄在log文件
		CPrintToChatAll("{default}[{olive}TS{default}]{blue} %N {default}starts a vote: Change server slots to %i?", iClient, g_iDesiredSlots);
		
		
		g_hSlotVote = CreateMenu(Handler_SlotCallback, MenuAction:MENU_ACTIONS_ALL);
		SetMenuTitle(g_hSlotVote, "Change server slots to %i?",g_iDesiredSlots);
		AddMenuItem(g_hSlotVote, VOTE_YES, "Yes");
		AddMenuItem(g_hSlotVote, VOTE_NO, "No");
		SetMenuExitButton(g_hSlotVote, false);
		VoteMenuToAll(g_hSlotVote, 20);
		
		EmitSoundToAll("ui/beep_synthtone01.wav");
	
	
		/*
		new iPlayers[MaxClients], iNumPlayers;

		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i)
			||	IsFakeClient(i)
			||	(GetClientTeam(i) == 1))
			{
				continue;
			}

			iPlayers[iNumPlayers++] = i;
		}

		g_hSlotVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

		decl String:sBuffer[64];
		FormatEx(sBuffer, sizeof(sBuffer), "Change server slots to %i?", g_iDesiredSlots);
		SetBuiltinVoteArgument(g_hSlotVote, sBuffer);
		SetBuiltinVoteInitiator(g_hSlotVote, iClient);
		SetBuiltinVoteResultCallback(g_hSlotVote, SlotVoteResultHandler);
		DisplayBuiltinVote(g_hSlotVote, iPlayers, iNumPlayers, 20);

		FakeClientCommand(iClient, "Vote Yes");
		*/
		
		return;
	}

	PrintToChat(iClient, "%t", "Vote denied");
}
/*
public VoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hSlotVote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}

public SlotVoteResultHandler(Handle:vote, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	for (new i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
				decl String:sBuffer[64];
				FormatEx(sBuffer, sizeof(sBuffer), "Server slots changed to %i", g_iDesiredSlots);
				DisplayBuiltinVotePass(vote, sBuffer);

				CreateTimer(SlotVoteCommandDelay, TimerChangeMaxPlayers, _, TIMER_FLAG_NO_MAPCHANGE);
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}
*/
public Action:TimerChangeMaxPlayers(Handle:timer)
{
	ChangeSeverSlots();
	return Plugin_Stop;
}

static StartNoSpecVote(iClient)
{
	if (GetClientTeam(iClient) == 1)
	{
		PrintToChat(iClient, "%t", "Spectator response");
		return;
	}
	
	if (!TestVoteDelay(iClient))
	{
		return;
	}
	
	if(CanStartVotes(iClient))
	{
		decl String:SteamId[35];
		GetClientAuthString(iClient, SteamId, sizeof(SteamId));
		LogMessage("%N(%s) starts a vote: kick spectators?",  iClient, SteamId);//紀錄在log文件
		CPrintToChatAll("{default}[{olive}TS{default}]{blue} %N {default}starts a vote: kick spectators?", iClient);
		
		
		g_hSlotVote = CreateMenu(Handler_SlotCallback2, MenuAction:MENU_ACTIONS_ALL);
		SetMenuTitle(g_hSlotVote, "Do you want to kick spectators?");
		AddMenuItem(g_hSlotVote, VOTE_YES, "Yes");
		AddMenuItem(g_hSlotVote, VOTE_NO, "No");
		SetMenuExitButton(g_hSlotVote, false);
		DisplayVoteMenuToNoSpecators(g_hSlotVote, 20);
		
		EmitSoundToAll("ui/beep_synthtone01.wav");
		/*
		new iNumPlayers, iPlayers[MaxClients];

		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i)
			||	IsFakeClient(i)
			||	(GetClientTeam(i) == 1))
			{
				continue;
			}

			iPlayers[iNumPlayers++] = i;
		}

		g_hNoSpecVote = CreateBuiltinVote(NoSpecVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

		decl String:sBuffer[64];
		FormatEx(sBuffer, sizeof(sBuffer), "Do you want to kick spectators?");
		SetBuiltinVoteArgument(g_hNoSpecVote, sBuffer);
		SetBuiltinVoteInitiator(g_hNoSpecVote, iClient);
		SetBuiltinVoteResultCallback(g_hNoSpecVote, NoSpecVoteResultHandler);
		DisplayBuiltinVote(g_hNoSpecVote, iPlayers, iNumPlayers, 20);

		FakeClientCommand(iClient, "Vote Yes");
		*/
		return;
	}
	
	PrintToChat(iClient, "%t", "Vote denied");
}
/*
public NoSpecVoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hNoSpecVote = INVALID_HANDLE;
			CloseHandle(vote);
		}

		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}

public NoSpecVoteResultHandler(Handle:vote, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	for (new i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
				decl String:sBuffer[64];
				FormatEx(sBuffer, sizeof(sBuffer), "Kicking spectators...");
				DisplayBuiltinVotePass(vote, sBuffer);

				CreateTimer(SlotVoteCommandDelay, TimerKickAllSpectators, _, TIMER_FLAG_NO_MAPCHANGE);
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}
*/
public Action:TimerKickAllSpectators(Handle:hTimer)
{
	KickAllSpectators();
	return Plugin_Stop;
}

static KickAllSpectators()
{
	new iSpecs;
	decl String:reason[255];
	Format(reason, sizeof(reason), "%t", "Spectator kick reason");
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 1)
		{
			if(IsPlayerGenericAdmin(i)) { 
				CPrintToChatAll("[{olive}TS{default}] Can not kick {olive}%N {default}from spectators. This player is {lightgreen}ADM{default}!", i);
				continue;
			}
			BanClient(i, 5, BANFLAG_AUTHID, reason, reason, "nospec");
			iSpecs++;
		}
	}

	if (iSpecs)
	{
		PrintToChatAll("%t", "All spectators kicked");
	}
}

stock GetHumanCount()
{
	new iHumanCount = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			iHumanCount++;
		}
	}

	return iHumanCount;
}

bool:TestVoteDelay(client)
{

	new delay = GetVoteDelay();
 	if (delay > 0)
 	{
 		CPrintToChat(client, "{default}[{olive}TS{default}] You must wait for {red}%i {default}sec then start a new vote!", delay);
 		return false;
 	}
	return true;
}

public Action:Timer_VoteDelay(Handle:timer, any:client)
{
	g_slotdelay--;
	if(g_slotdelay<=0)
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

GetVoteDelay()
{
	return g_slotdelay;
}
CheckVotes()
{
	PrintHintTextToAll("Agree: \x04%i\nDisagree: \x04%i", Votey, Voten);
}
public Action:VoteEndDelay(Handle:timer)
{
	Votey = 0;
	Voten = 0;
}
VoteMenuClose()
{
	Votey = 0;
	Voten = 0;
	CloseHandle(g_hSlotVote);
	g_hSlotVote = INVALID_HANDLE;
}
Float:GetVotePercent(votes, totalVotes)
{
	return FloatDiv(float(votes),float(totalVotes));
}

bool:CanStartVotes(client)
{
	
 	if(g_hSlotVote != INVALID_HANDLE || IsVoteInProgress())
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] A vote is already in progress!");
		return false;
	}
	new iNumPlayers;
	new playerlimit = GetConVarInt(g_hCvarPlayerLimit);
	//list of players
	for (new i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientConnected(i))
		{
			continue;
		}
		iNumPlayers++;
	}
	if (iNumPlayers < playerlimit)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] Slot vote cannot be started. Not enough {red}%d {default}players.",playerlimit);
		return false;
	}
	
	return true;
}

public Handler_SlotCallback(Handle:menu, MenuAction:action, param1, param2)
{
	//==========================
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: 
			{
				Votey += 1;
				//CPrintToChatAll("[{olive}TS{default}] %N {blue}has voted{default}.", param1);
			}
			case 1: 
			{
				Voten += 1;
				//CPrintToChatAll("[{olive}TS{default}] %N {blue}has voted{default}.", param1);
			}
		}
	}
	else if ( action == MenuAction_Cancel)
	{
		if (param1>0 && param1 <=MaxClients && IsClientConnected(param1) && IsClientInGame(param1) && !IsFakeClient(param1))
		{
			//CPrintToChatAll("[{olive}TS{default}] %N {blue}abandons the vote{default}.", param1);
		}
	}
	//==========================
	decl String:item[64], String:display[64];
	new Float:percent, Float:limit, votes, totalVotes;

	GetMenuVoteInfo(param2, votes, totalVotes);
	GetMenuItem(menu, param1, item, sizeof(item), _, display, sizeof(display));
	
	if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
	{
		votes = totalVotes - votes;
	}
	percent = GetVotePercent(votes, totalVotes);

	limit = GetConVarFloat(g_Cvar_Limits);
	
	CheckVotes();
	if (action == MenuAction_End)
	{
		VoteMenuClose();
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		CPrintToChatAll("{default}[{olive}TS{default}] No votes");
		g_slotdelay = SLOTDELAY_TIME;
		CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
		EmitSoundToAll("ui/beep_error01.wav");
		CreateTimer(2.0, VoteEndDelay);
	}	
	else if (action == MenuAction_VoteEnd)
	{
		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
		{
			g_slotdelay = SLOTDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/beep_error01.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] {red}Vote fail.{default} At least {red}%d%%%%{default} to agree.(agree {green}%d%%%%{default}, total {green}%i {default}votes)", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
		}
		else
		{
			g_slotdelay = SLOTDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/menu_enter05.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] {blue}Vote pass.{default}(agree {green}%d%%%%{default}, total {green}%i {default}votes)", RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
			CreateTimer(SlotVoteCommandDelay, TimerChangeMaxPlayers, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return 0;
}

public Handler_SlotCallback2(Handle:menu, MenuAction:action, param1, param2)
{
	//==========================
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: 
			{
				Votey += 1;
				//CPrintToChatAll("[{olive}TS{default}] %N {blue}has voted{default}.", param1);
			}
			case 1: 
			{
				Voten += 1;
				//CPrintToChatAll("[{olive}TS{default}] %N {blue}has voted{default}.", param1);
			}
		}
	}
	else if ( action == MenuAction_Cancel)
	{
		if (param1>0 && param1 <=MaxClients && IsClientConnected(param1) && IsClientInGame(param1) && !IsFakeClient(param1))
		{
			//CPrintToChatAll("[{olive}TS{default}] %N {blue}abandons the vote{default}.", param1);
		}
	}
	//==========================
	decl String:item[64], String:display[64];
	new Float:percent, Float:limit, votes, totalVotes;

	GetMenuVoteInfo(param2, votes, totalVotes);
	GetMenuItem(menu, param1, item, sizeof(item), _, display, sizeof(display));
	
	if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
	{
		votes = totalVotes - votes;
	}
	percent = GetVotePercent(votes, totalVotes);

	limit = GetConVarFloat(g_Cvar_Limits);
	
	CheckVotes();
	if (action == MenuAction_End)
	{
		VoteMenuClose();
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		CPrintToChatAll("{default}[{olive}TS{default}] No votes");
		g_slotdelay = SLOTDELAY_TIME;
		CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
		EmitSoundToAll("ui/beep_error01.wav");
		CreateTimer(2.0, VoteEndDelay);
	}	
	else if (action == MenuAction_VoteEnd)
	{
		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
		{
			g_slotdelay = SLOTDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/beep_error01.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] {red}Vote fail.{default} At least {red}%d%%%%{default} to agree.(agree {green}%d%%%%{default}, total {green}%i {default}votes)", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
		}
		else
		{
			g_slotdelay = SLOTDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/menu_enter05.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] {blue}Vote pass.{default}(agree {green}%d%%%%{default}, total {green}%i {default}votes)", RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
			CreateTimer(0.1, TimerKickAllSpectators, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return 0;
}

bool:IsPlayerGenericAdmin(client)
{
    if (CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false))
    {
        return true;
    }

    return false;
}  

stock bool:DisplayVoteMenuToNoSpecators(Handle:hMenu,iTime)
{
    new iTotal = 0;
    new iPlayers[MaxClients];
    
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) == 1)
        {
            continue;
        }
        
        iPlayers[iTotal++] = i;
    }
    
    return VoteMenu(hMenu, iPlayers, iTotal, iTime, 0);
}

ChangeSeverSlots()
{
	if (g_bL4DToolz)
	{
		SetConVarInt(g_hCVarMaxPlayersToolZ, g_iDesiredSlots);	
		SetConVarInt(g_cvarSvVisibleMaxPlayers, g_iDesiredSlots);
		g_iCurrentSlots = GetConVarInt(g_hCVarMaxPlayersToolZ);
	}
	if (g_bLeft4Downtown2)
	{
		SetConVarInt(g_hCVarMaxPlayersDowntown, g_iDesiredSlots);
		SetConVarInt(g_cvarSvVisibleMaxPlayers, g_iDesiredSlots);
		g_iCurrentSlots = GetConVarInt(g_hCVarMaxPlayersDowntown);
	}
}
