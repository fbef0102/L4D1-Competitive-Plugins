
/*=======================================================================================
	Change Log:

1.1 (26-03-2019)
	- Initial release.
	- Cleared old code, converted to new syntax and methodmaps.	
1.2 (12-04-2019)
	- fix error, optimize codes, and handle exception
  
========================================================================================
	Credits:

	KaiN - for request and the original idea	
	ZenServer -[ ZS ]- - for the original plugin
	JOSHE GATITO SPARTANSKII >>> (Ex Aya Supay) - for writing  plugin again and add new commands. 
        Harry - fix error, optimize codes, and handle exception

========================================================================================*/

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <colors>

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define PLUGIN_VERSION		"1.1"

bool g_bIsGod[66];
bool g_bShouldDrawMenu = true;
bool g_bTeamRequested[4];
bool g_bPlayerSelectOrder;
ConVar g_hPlayerSelectOrder;
ConVar g_CvarMixStatus;
ConVar g_CvarSurvLimit;
ConVar g_CvarMaxPlayerZombies;
bool g_bSelectToggle;
bool g_bIsAdmin[66];
bool g_bAltOrder;
bool g_bHasVoted[66];
bool g_bHasOneVoted;
bool g_bHasBeenChosen[66];
int g_iSurvivorCaptain;
int g_iInfectedCaptain;
int g_iVotesSurvivorCaptain[66];
int g_iVotesInfectedCaptain[66];
int g_iDesignatedTeam[66];
int g_iSelectedPlayers[66];
int g_iCvar = 262144;
float g_flTickInterval;

public Plugin myinfo = 
{
	name = "Left 4 Dead Modo Mix",
	author = "Harry & Joshe Gatito & ZenServer",
	description = "Modo de juego Mix",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/joshegatito/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_CvarMixStatus = CreateConVar("mix_status", "0", "The status of the mix. DO NOT MANUALLY ALTER THIS CVAR U SON OF A FUCK", 262144, false, 0.0, false, 0.0);	

	g_CvarSurvLimit = FindConVar("survivor_limit");
	g_CvarMaxPlayerZombies = FindConVar("z_max_player_zombies");
	
	CaptainVote_OnPluginStart();
	g_hPlayerSelectOrder = CreateConVar("mix_select_order", "0", "0 = ABABAB    |    1 = ABBAABBA", g_iCvar, false, 0.0, false, 0.0);
	g_bPlayerSelectOrder = g_hPlayerSelectOrder.BoolValue;
	g_hPlayerSelectOrder.AddChangeHook(ConVarChange_MixOrder);
	g_CvarMixStatus.AddChangeHook(ConVarChange_MixStatus);
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
}

public void L4DReady_ConVarChange_MixStatus(Handle convar, char[] oldValue, char[] newValue)
{
	if (0 < g_CvarMixStatus.IntValue)
	{
		g_bShouldDrawMenu = false;
	}
	else
	{
		g_bShouldDrawMenu = true;
	}
}

public void CaptainVote_OnPluginStart()
{
	LoadTranslations("common.phrases");
	RegConsoleCmd("sm_mix", Command_Captainvote, "Initiate a player mix.", 0);
	RegAdminCmd("sm_cancel", Command_Cancel, 16384, "Cancel the mix selection process.", "", 0);
	RegConsoleCmd("spectate", Command_Spectate, "", 0);
	g_CvarMixStatus.SetInt(0, false, false);
	ResetSelectedPlayers();
	ResetTeams();
	ResetCaptains();
	ResetAllVotes();
	ResetHasVoted();
}

public void OnMapEnd()
{
	CaptainVote_OnMapEnd();
}

public void OnMapStart()
{
	CaptainVote_OnMapStart();
}

public Action Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	CaptainVote_Event_RoundStart(event, name, dontBroadcast);
	return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	CaptainVote_Event_RoundEnd(event, name, dontBroadcast);
	return Plugin_Continue;
}

public void ConVarChange_MixOrder(Handle convar, char[] oldValue, char[] newValue)
{
	g_bPlayerSelectOrder = g_hPlayerSelectOrder.BoolValue;
}

public Action Timer_RegisterConVar(Handle timer)
{
	g_CvarMixStatus.AddChangeHook(ConVarChange_MixStatus);
	return Plugin_Continue;
}

public void CaptainVote_ConVarChange_MixStatus(Handle convar, char[] oldValue, char[] newValue)
{
	if (StrEqual(oldValue, newValue, true)) return;
	if (!(g_CvarMixStatus.IntValue))
	{
		ResetSelectedPlayers();
		ResetTeams();
		ResetCaptains();
		ResetAllVotes();
		ResetHasVoted();
		g_bTeamRequested[2] = false;
		g_bTeamRequested[3] = false;
	}
	if (g_CvarMixStatus.IntValue == 3)
	{
		g_bSelectToggle = false;
		CPrintToChatAll("Captains will now begin to choose players.");
		DisplayVoteMenuPlayerSelect();
	}
	if (g_CvarMixStatus.IntValue == 4)
	{
		CPrintToChatAll("Teams set, let the mix begin!");
		SwapPlayersToDesignatedTeams();
		g_CvarMixStatus.SetInt(0, false, false);
	}
	if (g_CvarMixStatus.IntValue == 5)
	{
		g_CvarMixStatus.SetInt(0, false, false);
	}
}

public Action Command_Captainvote(int client, int args)
{
	char CommandArgs[128];
	GetCmdArgString(CommandArgs, 128);
	bool IsAdmin = CheckCommandAccess(client, "sm_admin", 2, false);
	if (HasServerAdmin() && !IsAdmin)
	{
		CPrintToChat(client, "This command is disabled when one or more admins are present.");
		return Plugin_Handled; //3
	}
	if (0 < args)
	{
		GetCmdArgString(CommandArgs, 128);
		if (g_CvarMixStatus.IntValue && g_bTeamRequested[2] && g_bTeamRequested[3])
		{
			if (GetClientTeam(client) == TEAM_SURVIVOR || GetClientTeam(client) == TEAM_INFECTED)
			{
				if (StrEqual(CommandArgs, "cancel", true))
				{
					g_CvarMixStatus.SetInt(5, false, false);
				}
				CPrintToChatAll("{default}[{olive}ZS{default}] {lightgreen}%N {olive}cancelled the mix request.", client);
			}
			else
			{
				CPrintToChat(client, "{default}[{olive}ZS{default}] Spectators cannot cancel mixes.");
			}
		}
		else
		{
			CPrintToChat(client, "{default}[{olive}ZS{default}] Nothing to cancel. You. Dumb. FUCK.");
		}
		return Plugin_Handled;
	}
	if (g_CvarMixStatus.IntValue)
	{
		CPrintToChat(client, "{default}[{olive}ZS{default}] A mix is already in process you dumb fuck.");
		return Plugin_Handled;
	}
	if (!IsClientInGame(client))
	{
		CPrintToChat(client, "{default}[{olive}ZS{default}] Failed to request mix.");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) == 1 && !g_bIsAdmin[client])
	{
		CPrintToChat(client, "{default}[{olive}ZS{default}] Spectators cannot start mixes.");
		return Plugin_Handled;
	}
	AdminId id = GetUserAdmin(client);
	if (id != view_as<AdminId>(-1) && id.HasFlag(view_as<AdminFlag>(14), view_as<AdmAccessMode>(1)) == true)
	{
		g_CvarMixStatus.SetInt(1, false, false);
		VoteSurvivorCaptain();
		CPrintToChatAll("{default}[{olive}ZS{default}] {lightgreen}%N {default}started a mix.", client);
		return Plugin_Handled;
	}
	int TeamID = GetClientTeam(client);
	char teamName[64] = "{red}Infected{default}";
	char oppositeTeamName[64] = "{blue}Survivors{default}";
	if (!(TeamID == 2))
	{
	}
	if (!(TeamID == 3))
	{
	}
	if (g_bTeamRequested[TeamID])
	{
		CPrintToChat(client, "{default}[{olive}ZS{default}] Your team already requested a mix. YOU DUMB FUCKING FUCK.");
		return Plugin_Handled;
	}
	g_bTeamRequested[TeamID] = true;
	if (g_bTeamRequested[2] && g_bTeamRequested[3])
	{
		g_CvarMixStatus.SetInt(1, false, false);
		VoteSurvivorCaptain();
		CPrintToChatAll("{default}[{olive}ZS{default}] The %s have agreed to start the mix.", teamName);
		g_bTeamRequested[2] = false;
		g_bTeamRequested[3] = false;
		return Plugin_Handled;
	}
	CPrintToChatAll("{default}[{olive}ZS{default}] The %s have requested to start a mix.", teamName);
	CPrintToChatAll("{olive}The %s must agree by typing {green}!mix.", oppositeTeamName);
	CreateTimer(10.0, Timer_LoadMix, view_as<any>(2), 0);
	return Plugin_Handled;
}

public Action Timer_LoadMix(Handle timer)
{
	if (g_CvarMixStatus.IntValue) return Plugin_Handled;
	g_bTeamRequested[2] = false;
	g_bTeamRequested[3] = false;
	CPrintToChatAll("{default}[{olive}ZS{default}] Mix request timed out.");
	return Plugin_Handled;
}

public Action Command_Cancel(int client, int args)
{
	g_CvarMixStatus.SetInt(5, false, false);
	CPrintToChatAll("{lightgreen}%N {default}performed an absolute cancel.", client);
	g_bAltOrder = false;
	return Plugin_Handled;
}

public Action Command_Spectate(int client, int args)
{
	if (!g_bShouldDrawMenu)
	{
		CPrintToChat(client, "You {green}cannot{default} go to spectate during a {olive}mix selection process{default}.");
		return Plugin_Handled;
	}
	if (IsValidClient(client))
	{
		if (GetClientTeam(client) != TEAM_SPECTATOR)
		{
			if (GetClientTeam(client) == TEAM_SURVIVOR)
			{
				CPrintToChat(client, "You are now spectating.");
			}
			if (GetClientTeam(client) == TEAM_INFECTED)
			{
				CPrintToChat(client, "You are now spectating.");
			}
		}
	}
	return Plugin_Handled;
}

void VoteSurvivorCaptain()
{
	ResetSelectedPlayers();
	ResetTeams();
	ResetCaptains();
	ResetAllVotes();
	ResetHasVoted();
	DisplayVoteMenuCaptainSurvivor();
}

void DisplayVoteMenuCaptainSurvivor()
{
	if (g_CvarMixStatus.IntValue)
	{
		g_CvarMixStatus.SetInt(2, false, false);
		Menu SurvivorCaptainMenu = new Menu(Handler_SurvivorCaptainCallback, MENU_ACTIONS_DEFAULT);
		SurvivorCaptainMenu.SetTitle("Choose Captain #1:");
		int players;
		g_bHasOneVoted = false;
		char name[32];
		char number[12];
		int listplayers = g_CvarSurvLimit.IntValue * 2;
		for(int i = 1; i <= MaxClients; i++) 
		{
			if (IsClientInGame(i))
			{
				if (!(IsFakeClient(i)))
				{
					if (!IsSurvivorTeamFull() || !IsInfectedTeamFull())
					{
						if (players > listplayers)
						{
						}
					}
					if (IsSurvivorTeamFull() && IsInfectedTeamFull())
					{
						if (!IsClientInTeam(i))
						{
						}
					}
					Format(name, 32, "%N", i);
					Format(number, 10, "%i", i);
					SurvivorCaptainMenu.AddItem(number, name, 0);
					players++;
				}
			}
		}
		SurvivorCaptainMenu.ExitButton = true;
		for(int i = 1; i <= MaxClients; i++) 
		{
			if (IsClientInGame(i))
			{
				if (!(IsFakeClient(i)))
				{
					if (IsClientInTeam(i))
					{
						SurvivorCaptainMenu.Display(i, 10);
					}
				}
			}
		}
		CreateTimer(10.1, TimerCheckSurvivorCaptainVote, view_as<any>(2), 0);
	}
}

public Action TimerCheckSurvivorCaptainVote(Handle timer)
{
	if (g_CvarMixStatus.IntValue)
	{
		if (!g_bHasOneVoted)
		{
			VoteSurvivorCaptain();
		}
		else
		{
			CalculateSurvivorCaptain();
			CPrintToChatAll("{default}[{olive}ZS{default}] First captain is: {lightgreen}%N{default} With {green}%i {default}votes.", g_iSurvivorCaptain, g_iVotesSurvivorCaptain[g_iSurvivorCaptain]);
			DisplayVoteMenuCaptainInfected();
		}
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public int Handler_SurvivorCaptainCallback(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case 4:
		{
			char item[16];
			menu.GetItem(param2, item, 16);
			int target = StringToInt(item, 10);
			if (IsClientInGame(target) && !IsFakeClient(target))
			{
				g_iVotesSurvivorCaptain[target]++;
				if (g_bIsGod[param1])
				{
					g_iVotesSurvivorCaptain[target] += 2;
				}
				g_bHasOneVoted = true;
			}
		}
	}
}

void DisplayVoteMenuPlayerSelect()
{
	if (g_CvarMixStatus.IntValue)
	{
		g_CvarMixStatus.SetInt(3, false, false);
		Menu PlayerSelectMenu = new Menu(Handler_PlayerSelectionCallback, MENU_ACTIONS_DEFAULT);
		PlayerSelectMenu.SetTitle("Choose wisely...");
		char name[32];
		char number[12];
		for(int i = 1; i <= MaxClients; i++) 
		{
			if ( IsValidClient(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_SPECTATOR && !g_bHasBeenChosen[i] && i != g_iSurvivorCaptain && i != g_iInfectedCaptain )
			{
				Format(name, 32, "%N", i);
				Format(number, 10, "%i", i);
				PlayerSelectMenu.AddItem(number, name, 0);
			}
		}
		PlayerSelectMenu.ExitButton = true;
		if (IsValidClient(g_iSurvivorCaptain) && IsValidClient(g_iInfectedCaptain))
		{
			if (!g_bSelectToggle)
			{
				PlayerSelectMenu.Display(g_iSurvivorCaptain, 1);
			}
			if (g_bSelectToggle)
			{
				PlayerSelectMenu.Display(g_iInfectedCaptain, 1);
			}
		}
		CreateTimer(1.1, Timer_PlayerSelection, view_as<any>(1), 0);
	}
}

public int Handler_PlayerSelectionCallback(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case 4:
		{
			char item[16];
			menu.GetItem(param2, item, 16);
			int target = StringToInt(item, 10);
			if (IsClientInGame(target) && !IsFakeClient(target))
			{
				g_bHasBeenChosen[target] = true;
				if (!g_bSelectToggle)
				{
					g_iDesignatedTeam[target] = 2;
					CPrintToChatAll("{default}[{olive}ZS{default}] {blue}%N {default}selected: {green}%N", g_iSurvivorCaptain, target);
					g_iSelectedPlayers[g_iSurvivorCaptain]++;
				}
				else
				{
					g_iDesignatedTeam[target] = 3;
					CPrintToChatAll("{default}[{olive}ZS{default}] {red}%N {default}selected: {green}%N", g_iInfectedCaptain, target);
					g_iSelectedPlayers[g_iInfectedCaptain]++;
				}
				
				g_bSelectToggle = !g_bSelectToggle;
				
				if (!g_bPlayerSelectOrder)
				{
					g_bSelectToggle = !g_bSelectToggle;
				}
				if (!g_bAltOrder)
				{
					g_bSelectToggle = !g_bSelectToggle;
				}
				g_bAltOrder = !g_bAltOrder;
			}
		}
		case 16:
		{
			if (menu)
			{
				delete menu;
			}
		}
	}
}

public Action Timer_PlayerSelection(Handle timer)
{
	if (g_CvarMixStatus.IntValue)
	{
		int SurvivorLimit = g_CvarSurvLimit.IntValue;
		int InfectedLimit = g_CvarMaxPlayerZombies.IntValue;
		if (g_iSelectedPlayers[g_iSurvivorCaptain] >= SurvivorLimit + -1 && g_iSelectedPlayers[g_iInfectedCaptain] >= InfectedLimit + -1)
		{
			g_CvarMixStatus.SetInt(4, false, false);
			return Plugin_Stop;//4
		}
		DisplayVoteMenuPlayerSelect();
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

void DisplayVoteMenuCaptainInfected()
{
	Menu InfectedCaptainMenu = new Menu(Handler_InfectedCaptainCallback, MENU_ACTIONS_DEFAULT);
	InfectedCaptainMenu.SetTitle("Choose Captain #2:");
	int players;
	g_bHasOneVoted = false;
	char name[32];
	char number[12];
	int listplayers = g_CvarSurvLimit.IntValue * 2 + -1;
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (!(IsFakeClient(i)))
			{
				if (!(g_iSurvivorCaptain == i))
				{
					if (!IsSurvivorTeamFull() || !IsInfectedTeamFull())
					{
						if (players > listplayers)
						{
						}
					}
					if (IsSurvivorTeamFull() && IsInfectedTeamFull())
					{
						if (!IsClientInTeam(i))
						{
						}
					}
					Format(name, 32, "%N", i);
					Format(number, 10, "%i", i);
					InfectedCaptainMenu.AddItem(number, name, 0);
					players++;
				}
			}
		}
	}
	InfectedCaptainMenu.ExitButton = true;
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (!(IsFakeClient(i)))
			{
				if (!(g_iSurvivorCaptain == i))
				{
					if (IsClientInTeam(i))
					{
						InfectedCaptainMenu.Display(i, 10);
					}
				}
			}
		}
	}
	CreateTimer(10.1, TimerCheckInfectedCaptainVote, view_as<any>(2), 0);
}

public Action TimerCheckInfectedCaptainVote(Handle timer)
{
	if (g_CvarMixStatus.IntValue)
	{
		if (!g_bHasOneVoted)
		{
			DisplayVoteMenuCaptainInfected();
		}
		else
		{
			CalculateInfectedCaptain();
			CPrintToChatAll("{default}[{olive}ZS{default}] Second captain is: {lightgreen}%N{default} With {green}%i {default}votes.", g_iInfectedCaptain, g_iVotesInfectedCaptain[g_iInfectedCaptain]);
			g_CvarMixStatus.SetInt(3, false, false);
		}
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public int Handler_InfectedCaptainCallback(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case 4:
		{
			char item[16];
			menu.GetItem(param2, item, 16);
			int target = StringToInt(item, 10);
			if (IsClientInGame(target) && !IsFakeClient(target))
			{
				g_iVotesInfectedCaptain[target]++;
				if (g_bIsGod[param1])
				{
					g_iVotesInfectedCaptain[target] += 2;
				}
				g_bHasOneVoted = true;
			}
		}
	}
}

void ResetCaptains()
{
	g_iSurvivorCaptain = 0;
	g_iInfectedCaptain = 0;
	g_bAltOrder = false;
}

void ResetAllVotes()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iVotesSurvivorCaptain[i] = 0;
		g_iVotesInfectedCaptain[i] = 0;
	}
}

void ResetTeams()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iDesignatedTeam[i] = 1;
	}
}

void ResetSelectedPlayers()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iSelectedPlayers[i] = 0;
		g_bHasBeenChosen[i] = false;
	}
}

void CalculateSurvivorCaptain()
{
	int highestvotes;
	for(int i = 1; i <= MaxClients; i++)
	{
		if (g_iVotesSurvivorCaptain[i] > highestvotes)
		{
			highestvotes = g_iVotesSurvivorCaptain[i];
			g_iSurvivorCaptain = i;
			g_iDesignatedTeam[i] = 2;
		}
	}
}

void CalculateInfectedCaptain()
{
	int highestvotes;
	for(int i = 1; i <= MaxClients; i++)
	{
		if (g_iVotesInfectedCaptain[i] > highestvotes)
		{
			highestvotes = g_iVotesInfectedCaptain[i];
			g_iInfectedCaptain = i;
			g_iDesignatedTeam[i] = 3;
		}
	}
}

void ResetHasVoted()
{
	g_bHasOneVoted = false;
	for(int i = 1; i <= MaxClients; i++) 
	{
		g_bHasVoted[i] = false;
	}
}

public void CaptainVote_OnMapStart()
{
	g_CvarMixStatus.SetInt(0, false, false);
	ResetSelectedPlayers();
	ResetTeams();
	ResetCaptains();
	ResetAllVotes();
	ResetHasVoted();
}

public void CaptainVote_OnMapEnd()
{
	g_CvarMixStatus.SetInt(0, false, false);
	ResetSelectedPlayers();
	ResetTeams();
	ResetCaptains();
	ResetAllVotes();
	ResetHasVoted();
}

public Action CaptainVote_Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	g_CvarMixStatus.SetInt(0, false, false);
}

public Action CaptainVote_Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	g_CvarMixStatus.SetInt(0, false, false);
}

public int CaptainVote_OnClientDisconnect_Post(int client)
{
	g_iVotesSurvivorCaptain[client] = 0;
	g_iVotesInfectedCaptain[client] = 0;
	g_bHasVoted[client] = false;
}

void SwapPlayersToDesignatedTeams()
{
	g_iDesignatedTeam[g_iSurvivorCaptain] = TEAM_SURVIVOR;
	g_iDesignatedTeam[g_iInfectedCaptain] = TEAM_INFECTED;
	for(int i = 1; i <= MaxClients; i++) 
	{
		if (!IsValidClient(i) || IsFakeClient(i) || GetClientTeam(i) == TEAM_SPECTATOR)
		{
		}
		else
		{
			ChangeClientTeam(i, 1);
			if (g_iDesignatedTeam[i] == TEAM_SURVIVOR)
			{
				CreateTimer(g_flTickInterval, MoveToSurvivor, i, 2);
			}
			if (g_iDesignatedTeam[i] == TEAM_INFECTED)
			{
				CreateTimer(g_flTickInterval, MoveToInfected, i, 2);
			}
		}
	}
	g_CvarMixStatus.SetInt(0, false, false);
}

public Action MoveToSurvivor(Handle timer, any target)
{
	char playerName[64];
	GetClientName(target, playerName, 64);
	FakeClientCommand(target, "sm_survivor");
	return Plugin_Continue;
}

public Action MoveToInfected(Handle timer, any target)
{
	char playerName[64];
	GetClientName(target, playerName, 64);
	FakeClientCommand(target, "sm_infected");
	return Plugin_Continue;
}

bool IsSurvivorTeamFull()
{
	int g_iSurvivorTeamSize;
	for(int i = 1; i <= MaxClients; i++) 
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) == TEAM_SURVIVOR)
		{
		}
	}
	g_iSurvivorTeamSize++;
	int SurvivorLimit = g_CvarSurvLimit.IntValue;
	if (SurvivorLimit == g_iSurvivorTeamSize) return true;
	return false;
}

bool IsInfectedTeamFull()
{
	int g_iInfectedTeamSize;
	for(int i = 1; i <= MaxClients; i++) 
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) == TEAM_INFECTED)
		{
		}
	}
	g_iInfectedTeamSize++;
	int InfectedLimit = g_CvarMaxPlayerZombies.IntValue;
	if (InfectedLimit == g_iInfectedTeamSize) return true;
	return false;
}

bool IsClientInTeam(int client)
{
	if (!IsClientInGame(client) || IsFakeClient(client)) return false;
	if (GetClientTeam(client) == TEAM_SURVIVOR || GetClientTeam(client) == TEAM_INFECTED) return true;
	return false;
}

public void ConVarChange_MixStatus(Handle convar, char[] oldValue, char[] newValue)
{
	L4DReady_ConVarChange_MixStatus(convar, oldValue, newValue);
	CaptainVote_ConVarChange_MixStatus(convar, oldValue, newValue);
}

bool HasServerAdmin()
{
	int admins;
	for(int i = 1; i <= MaxClients; i++) 
	{
		if (!IsValidClient(i) || IsFakeClient(i))
		{
		}
		else if (g_bIsAdmin[i])
		{
			admins++;
		}
	}
	if (0 < admins) return true;
	return false;
}

bool IsValidClient(int client)
{
	if (client < 1 || client > MaxClients) return false;
	return IsClientInGame(client);
}
