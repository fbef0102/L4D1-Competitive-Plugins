#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

forward void OnClientSpeaking(int client);

public Extension __ext_voice = 
{
	name = "VoiceHook",
	file = "VoiceHook.ext",
	autoload = 1,
	required = 1,
}

int ClientSpeakingList[MAXPLAYERS+1] = {-1, ...};
bool ClientSpeakingTime[MAXPLAYERS+1];

ConVar va_default_speaklist;
ConVar va_svalltalk;
ConVar va_spectator_speaklist;
Handle g_hSpeakingList;

char SpeakingPlayers[3][512];
int team;
#define UPDATESPEAKING_TIME_INTERVAL 0.5

public Plugin myinfo = 
{
	name = "SpeakingList",
	author = "Accelerator & HarryPotter",
	description = "Voice Announce. Print To Center Message who Speaking. With cookies",
	version = "1.8",
	url = "https://steamcommunity.com/id/fbef0102/"
}

public void OnPluginStart()
{	
	g_hSpeakingList = RegClientCookie("speaking-list", "SpeakList", CookieAccess_Protected);
	
	va_spectator_speaklist = CreateConVar("va_spectator_speaklist", "1", "Enable speaklist for spectators default? [1-Enable/0-Disable]", 0, true, 0.0, true, 1.0);
	va_default_speaklist = CreateConVar("va_default_speaklist", "1", "Enable speaklist when sv_alltalk on? [1-Enable/0-Disable]", 0, true, 0.0, true, 1.0);
	va_svalltalk = FindConVar("sv_alltalk");
	
	RegConsoleCmd("sm_speaklist", Command_SpeakList, "Player Enable or Disable speaklist");
	
	CreateTimer(UPDATESPEAKING_TIME_INTERVAL, UpdateSpeaking, _, TIMER_REPEAT);
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client))
	{
		if (AreClientCookiesCached(client))
		{
			char cookie[2];
			GetClientCookie(client, g_hSpeakingList, cookie, sizeof(cookie));
			ClientSpeakingList[client] = StringToInt(cookie);
			
			if (ClientSpeakingList[client] == 0)
				ClientSpeakingList[client] = GetConVarInt(va_spectator_speaklist);
		}
	}
}

public void OnClientDisconnect(int client)
{
	ClientSpeakingList[client] = -1;
}

public Action Command_SpeakList(int client, int args)
{
	if (!client || !IsClientInGame(client) || GetClientTeam(client)!=1 )
		return Plugin_Continue;
	
	if (ClientSpeakingList[client] == 1)
	{
		ClientSpeakingList[client] = -1;
		if (AreClientCookiesCached(client))
		{
			SetClientCookie(client, g_hSpeakingList, "-1");
		}
		PrintToChat(client, "%T","SpeakingList1",client);
	}
	else
	{
		ClientSpeakingList[client] = 1;
		if (AreClientCookiesCached(client))
		{
			SetClientCookie(client, g_hSpeakingList, "1");
		}
		PrintToChat(client, "%T","SpeakingList2",client);
	}
	return Plugin_Continue;
}

public void OnClientSpeaking(int client)
{
	ClientSpeakingTime[client] = true;
}

public Action UpdateSpeaking(Handle timer)
{
	int iCount;
	for(int i = 0; i < 3; i++)
		SpeakingPlayers[i][0] = '\0';

	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (ClientSpeakingTime[i])
		{
			if (!IsClientInGame(i)||IsFakeClient(i)) continue;
			if (GetClientListeningFlags(i) & VOICE_MUTED) continue; //該玩家被靜音
			
			team = GetClientTeam(i)-1;
			if (team < 0 || team > 2) continue;
			
			Format(SpeakingPlayers[team], sizeof(SpeakingPlayers[]), "%s%N\n", SpeakingPlayers[team], i);
			iCount++;
		}
		ClientSpeakingTime[i] = false;
	}
	
	int svalltalk = GetConVarInt(va_svalltalk);
	if(SpeakingPlayers[0][0] != '\0')
		Format(SpeakingPlayers[0], sizeof(SpeakingPlayers[]), "Spectator MIC:\n%s",SpeakingPlayers[0]);
	if(SpeakingPlayers[1][0] != '\0')
		Format(SpeakingPlayers[1], sizeof(SpeakingPlayers[]), "Survivor MIC:\n%s", SpeakingPlayers[1]);
	if(SpeakingPlayers[2][0] != '\0')
		Format(SpeakingPlayers[2], sizeof(SpeakingPlayers[]), "Infected MIC:\n%s", SpeakingPlayers[2]);
	if (iCount > 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i)&&!IsFakeClient(i)&&ClientSpeakingList[i]>0)
			{
				if ( (GetClientTeam(i) == 1 && svalltalk == 0)
				|| (GetConVarInt(va_default_speaklist) == 1 && svalltalk == 1) )//旁觀玩家+alltalk 0 or alltalk 1
				{
					PrintCenterText(i, "%s%s%s",SpeakingPlayers[0],SpeakingPlayers[1],SpeakingPlayers[2]);
				}
			}
		}
	}
}