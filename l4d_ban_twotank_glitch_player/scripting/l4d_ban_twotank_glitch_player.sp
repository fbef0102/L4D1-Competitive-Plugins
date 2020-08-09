#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法

#include <sourcemod>
#include <sdktools>

ConVar g_hCvarAllow, g_hCvarBanTime;
static int ZOMBIECLASS_TANK = 5;

public Plugin myinfo =
{
    name = "ban tank player glitch",
    author = "Harry Potter",
    description = "ban player who uses L4D / Split tank glitch",
    version = "1.0",
    url = "https://forums.alliedmods.net/showthread.php?t=326023"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	EngineVersion test = GetEngineVersion();
	
	if(test != Engine_Left4Dead)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success; 
}

public void OnPluginStart()
{
	g_hCvarAllow =	CreateConVar("sm_ban_tankplayer_allow",	"1", "0=Plugin off, 1=Plugin on.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarBanTime =	CreateConVar("sm_ban_tankplayer_ban_time",	"5", "Ban how many mins.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	AutoExecConfig(true, "l4d_ban_twotank_glitch_player");
}

public void OnClientDisconnect(int client)
{
	if(g_hCvarAllow.BoolValue)
	{
		if(client && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && IsPlayerTank(client))
		{
			int frus = GetFrustration(client);
			if(frus == 100)
			{
				PrintToChatAll("%N tries to use two tank glitch and leaves the game as alive tank player.",client);
				BanClient(client, g_hCvarBanTime.IntValue, BANFLAG_AUTHID, "use two tank glitch", "Nice Try! Dumbass!");
			}
		}
	}
}

bool IsPlayerTank (int client)
{
    return (GetEntProp(client, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK);
}

int GetFrustration(int tank_index)
{
	return GetEntProp(tank_index, Prop_Send, "m_frustration");
}
