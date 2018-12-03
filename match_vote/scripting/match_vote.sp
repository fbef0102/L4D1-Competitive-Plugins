#include <sourcemod>
#include <builtinvotes>
//get here: https://forums.alliedmods.net/showthread.php?t=162164

#define L4D_TEAM_SPECTATE	1
#define MATCHMODES_PATH		"configs/matchmodes.txt"

new Handle:g_hMatchVote = INVALID_HANDLE;
new Handle:g_hModesKV = INVALID_HANDLE;
new Handle:g_hCvarPlayerLimit = INVALID_HANDLE;
new String:g_sCfg[32];

public Plugin:myinfo = 
{
	name = "Match Vote",
	author = "vintik, epilimic",
	description = "!match !rmatch, re-added legacy <!match configname> command",
	version = "1.3",
	url = "https://github.com/epilimic"
}

public OnPluginStart()
{
	decl String:sBuffer[128];
	GetGameFolderName(sBuffer, sizeof(sBuffer));
	g_hModesKV = CreateKeyValues("MatchModes");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), MATCHMODES_PATH);
	if (!FileToKeyValues(g_hModesKV, sBuffer))
	{
		SetFailState("Couldn't load matchmodes.txt!");
	}

	RegConsoleCmd("sm_match", MatchRequest);
	RegConsoleCmd("sm_load", MatchRequest);
	g_hCvarPlayerLimit = CreateConVar("sm_match_player_limit", "1", "Minimum # of players in game to start the vote", FCVAR_PLUGIN);
}

public Action:MatchRequest(client, args)
{
	if (!client) return Plugin_Handled;
	if (args > 0)
	{
		//config specified
		decl String:sCfg[64], String:sBuffer[256];
		GetCmdArg(1, sCfg, sizeof(sCfg));
		BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "../../cfg/%s.cfg", sCfg);
		if (FileExists(sBuffer))
		{
			FindConfigName(sCfg, sBuffer, sizeof(sBuffer));
			if (StartMatchVote(client, sBuffer))
			{
				strcopy(g_sCfg, sizeof(g_sCfg), sCfg);
				//caller is voting for
				FakeClientCommand(client, "Vote Yes");
			}
			return Plugin_Handled;
		}
		else
		{
			PrintToChat(client,"File %s.cfg does not exist!",sCfg);
		}
	}
	//show main menu
	MatchModeMenu(client);
	return Plugin_Handled;
}

bool:FindConfigName(const String:cfg[], String:name[], maxlength)
{
	KvRewind(g_hModesKV);
	if (KvGotoFirstSubKey(g_hModesKV))
	{
		do
		{
			if (KvJumpToKey(g_hModesKV, cfg))
			{
				KvGetString(g_hModesKV, "name", name, maxlength);
				return true;
			}
		} while (KvGotoNextKey(g_hModesKV));
	}
	return false;
}

MatchModeMenu(client)
{
	new Handle:hMenu = CreateMenu(MatchModeMenuHandler);
	SetMenuTitle(hMenu, "Select match mode:");
	new String:sBuffer[64];
	KvRewind(g_hModesKV);
	if (KvGotoFirstSubKey(g_hModesKV))
	{
		do
		{
			KvGetSectionName(g_hModesKV, sBuffer, sizeof(sBuffer));
			AddMenuItem(hMenu, sBuffer, sBuffer);
		} while (KvGotoNextKey(g_hModesKV));
	}
	DisplayMenu(hMenu, client, 20);
}

public MatchModeMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[64], String:sBuffer[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		KvRewind(g_hModesKV);
		if (KvJumpToKey(g_hModesKV, sInfo) && KvGotoFirstSubKey(g_hModesKV))
		{
			new Handle:hMenu = CreateMenu(ConfigsMenuHandler);
			Format(sBuffer, sizeof(sBuffer), "Select %s config:", sInfo);
			SetMenuTitle(hMenu, sBuffer);
			do
			{
				KvGetSectionName(g_hModesKV, sInfo, sizeof(sInfo));
				KvGetString(g_hModesKV, "name", sBuffer, sizeof(sBuffer));
				AddMenuItem(hMenu, sInfo, sBuffer);
			} while (KvGotoNextKey(g_hModesKV));
			DisplayMenu(hMenu, param1, 20);
		}
		else
		{
			PrintToChat(param1, "No configs for such mode were found.");
			MatchModeMenu(param1);
		}
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public ConfigsMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[64], String:sBuffer[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo), _, sBuffer, sizeof(sBuffer));
		if (StartMatchVote(param1, sBuffer))
		{
			strcopy(g_sCfg, sizeof(g_sCfg), sInfo);
		}
		else
		{
			MatchModeMenu(param1);
		}
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	if (action == MenuAction_Cancel)
	{
		MatchModeMenu(param1);
	}
}

bool:StartMatchVote(client, const String:cfgname[])
{
	if (GetClientTeam(client) == L4D_TEAM_SPECTATE)
	{
		PrintToChat(client, "Match voting isn't allowed for spectators.");
		return false;
	}
	if (!IsBuiltinVoteInProgress())//disregard sm_vote_delay
	{
		new iNumPlayers;
		decl iPlayers[MaxClients];
		//list of non-spectators players
		for (new i=1; i<=MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == L4D_TEAM_SPECTATE))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}
		if (iNumPlayers < GetConVarInt(g_hCvarPlayerLimit))
		{
			PrintToChat(client, "Match vote cannot be started. Not enough players.");
			return false;
		}
		new String:sBuffer[64];
		g_hMatchVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		//if (LGO_IsMatchModeLoaded())
		//{
		//	Format(sBuffer, sizeof(sBuffer), "Change config to '%s'?", cfgname);
		//}
		Format(sBuffer, sizeof(sBuffer), "更換 '%s' 模式?", cfgname);
		SetBuiltinVoteArgument(g_hMatchVote, sBuffer);
		SetBuiltinVoteInitiator(g_hMatchVote, client);
		SetBuiltinVoteResultCallback(g_hMatchVote, VoteResultHandler);
		DisplayBuiltinVote(g_hMatchVote, iPlayers, iNumPlayers, 20);
		return true;
	}
	PrintToChat(client, "Match vote cannot be started now.");
	return false;
}

public VoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hMatchVote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}

public VoteResultHandler(Handle:vote, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if ( (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2) ) || num_clients ==1)
			{
				if (vote == g_hMatchVote)
				{
					DisplayBuiltinVotePass(vote, "confogl is loading...");
					CreateTimer(6.0,COLD_DOWN,_);
					PrintToChatAll("[Match] 6 秒後更換模式");
					return;
				}
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action:COLD_DOWN(Handle:timer,any:client)
{
	ServerCommand("exec %s", g_sCfg);
}
