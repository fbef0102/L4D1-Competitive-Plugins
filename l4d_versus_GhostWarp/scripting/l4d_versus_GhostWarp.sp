/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.GhostWarp.sp
 *  Type:			Module
 *  Description:	...
 *  Credits:		Most of credits goes to Confogl (http://code.google.com/p/confogl/)
 *
 *  Copyright (C) 2012-2015 raziEiL <war4291@mail.ru>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */
#include <sourcemod>
#include <sdktools>
#include <colors>
#include <l4d_direct>

#define L4D_TEAM_SURVIVORS 2
#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SPECTATE 1

static  bool:g_bDelay[MAXPLAYERS+1], g_iLastTarget[MAXPLAYERS+1];
new		SurvivorIndex[MAXPLAYERS+1],SurvivorCount;
//native	IsInReady();

new Handle:hNameToCharIDTrie;
new Handle:hFlowArray;
public Plugin:myinfo = 
{
	name = "l4d_versus_GhostWarp",
	author = "CanadaRox,L4D1 port by Harry",
	description = "Allows infected to warp to survivors (MOUSE2 or use command)",
	version = "1.2",
	url = "myself"
}

enum survFlowEnum
{
	surv,
	Float:flow
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("RebuildIndex", Native_RebuildIndex);
    return APLRes_Success;
}

public  OnPluginStart()
{
	HookEvent("player_death", GW_ev_PlayeDeath);
	HookEvent("round_start", event_round_start);
	HookEvent("player_team", event_player_teamchange,EventHookMode_Pre);
	
	PrepTries();
	hFlowArray = CreateArray(2);

	RegConsoleCmd("sm_warpto", WarpTo_Cmd, "Warps to the specified survivor");
}

PrepTries()
{
	hNameToCharIDTrie = CreateTrie();
	SetTrieValue(hNameToCharIDTrie, "bill", 0);
	SetTrieValue(hNameToCharIDTrie, "zoey", 1);
	SetTrieValue(hNameToCharIDTrie, "francis", 2);
	SetTrieValue(hNameToCharIDTrie, "louis", 3);

}

public Action:WarpTo_Cmd(client, args)
{
	if (!IsGhostInfected(client))
	{
		return Plugin_Handled;
	}

	if (args != 1)
	{
		ReplyToCommand(client, "Usage: sm_warpto <#|name> (1|Francis, 2|Bill, 3|Zoey, 4|Louis)");
		return Plugin_Handled;
	}
	
	decl String:arg[12];
	decl survivorFlowRank;
	GetCmdArg(1, arg, sizeof(arg));
	survivorFlowRank = StringToInt(arg);
	
	if (survivorFlowRank)//number
	{
		decl Float:origin[3];
		GetClientAbsOrigin(GetSurvivorOfFlowRank(survivorFlowRank), origin);
		TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
	}
	else//name
	{
		if(StrEqual(arg,"Zoey")||StrEqual(arg,"ZOEY"))	
			arg = "zoey";
		else if(StrEqual(arg,"Louis")||StrEqual(arg,"LOUIS"))
			arg = "louis";
		else if(StrEqual(arg,"Bill")||StrEqual(arg,"BILL"))
			arg = "bill";
		else if(StrEqual(arg,"Francis")||StrEqual(arg,"FRANCIS"))
			arg = "francis";
		
		decl target;
		if (GetTrieValue(hNameToCharIDTrie, arg, target))
		{
			target = GetClientOfCharID(target);
			decl Float:origin[3];
			GetClientAbsOrigin(target, origin);
			TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
		}
	}
	return Plugin_Handled;
}
stock GetSurvivorOfFlowRank(rank)
{
	decl survFlowEnum:currentSurv[survFlowEnum];
	for (new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		{
			currentSurv[surv] = client;
			currentSurv[flow] = L4DDirect_GetFlowDistance(client);
			PushArrayArray(hFlowArray, currentSurv[0]);
		}
	}
	SortADTArrayCustom(hFlowArray, sortFunc);
	new arraySize = GetArraySize(hFlowArray);
	if (rank - 1 > arraySize)
		rank = arraySize;
	GetArrayArray(hFlowArray, rank - 1, currentSurv);
	ClearArray(hFlowArray);

	return currentSurv[0];
}

public sortFunc(index1, index2, Handle:array, Handle:hndl)
{
	decl item1[2];

	decl item2[2];

	if (Float:item1[1] > Float:item2[1])
		return -1;
	else if (Float:item1[1] < Float:item2[1])
		return 1;
	else
		return 0;
}

stock GetClientOfCharID(characterID)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			if (GetEntProp(client, Prop_Send, "m_survivorCharacter") == characterID)
				return client;
		}
	}
	return 0;
}
public GW_ev_PlayeDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_iLastTarget[client] = 0;
}

public Action:OnPlayerRunCmd(client, &buttons)
{
	if( (buttons & IN_ATTACK2) && SurvivorCount && !g_bDelay[client] && !IsFakeClient(client) && IsGhostInfected(client))
	{
		g_bDelay[client] = true;
		CreateTimer(0.35, GW_t_ResetDelay, client);
		GW_WarpToSurvivor(client);
	}
	return Plugin_Continue;
}
stock IsGhostInfected(client)
{
	return GetClientTeam(client) == L4D_TEAM_INFECTED && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_isGhost");
}
GW_WarpToSurvivor(client)
{
	if (!SurvivorCount) return;

	new target = SurvivorIndex[g_iLastTarget[client]];

	if (!target){

		g_iLastTarget[client] = 0;
		GW_WarpToSurvivor(client);
		return;
	}
	if (!IsClientInGame(target)) return;

	// Prevent people from spawning and then warp to survivor
	SetEntProp(client, Prop_Send, "m_ghostSpawnState", 256);

	decl Float:position[3], Float:anglestarget[3];

	GetClientAbsOrigin(target, position);
	GetClientAbsAngles(target, anglestarget);

	TeleportEntity(client, position, anglestarget, NULL_VECTOR);

	if (++g_iLastTarget[client] == SurvivorCount)
		g_iLastTarget[client] = 0;
}

public Action:GW_t_ResetDelay(Handle:timer, any:client)
{
	g_bDelay[client] = false;
}

/*
stock _GW_CvarDump()
{
	decl bool:iVal;
	if ((iVal = GetConVarBool(g_hWarpEnable)) != g_bWarpEnable)
		DebugLog("%d		|	%d		|	rotoblin_ghost_warp", iVal, g_bWarpEnable);
}
*/
public Native_RebuildIndex(Handle:plugin, numParams)
{
	ResetCounts();

	if (!IsServerProcessing()) return;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;

		switch (GetClientTeam(i))
		{
			case L4D_TEAM_SURVIVORS:
			{
				if (IsPlayerAlive(i))
					SurvivorIndex[SurvivorCount++] = i;
			}
		}
	}
}

MyPlugin_RebuildIndex()
{
	ResetCounts();

	if (!IsServerProcessing()) return;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;

		switch (GetClientTeam(i))
		{
			case L4D_TEAM_SURVIVORS:
			{
				if (IsPlayerAlive(i))
					SurvivorIndex[SurvivorCount++] = i;
			}
		}
	}
}

static ResetCounts()
{
	SurvivorCount = 0;
}

public event_round_start(Handle:event, const String:name[], bool:dontBroadcast)//回合開始reset
{
	MyPlugin_RebuildIndex();
}

public event_player_teamchange(Handle:event, String:name[], bool:dontBroadcast)//有人跳隊到則reset
{
		
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client&&IsClientInGame(client)&& GetClientTeam(client) == L4D_TEAM_SURVIVORS)//從sur 跳隊
		MyPlugin_RebuildIndex();
		
	CreateTimer(1.0,PlayerChangeTeamCheck,client);//延遲一秒檢查
}

public Action:PlayerChangeTeamCheck(Handle:timer,any:client)//跳隊到sur
{
	if (client && IsClientInGame(client)&& GetClientTeam(client) == L4D_TEAM_SURVIVORS)
		MyPlugin_RebuildIndex();
}
