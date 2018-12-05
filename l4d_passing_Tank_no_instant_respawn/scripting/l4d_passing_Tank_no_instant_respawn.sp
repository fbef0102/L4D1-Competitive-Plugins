#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

new lastHumanTank = -1;

public Plugin:myinfo =
{
	name = "L4D passing Tank no instant respawn",
	author = "Visor, L4D1 port by Harry",
	description = "Passing control to AI tank will no longer be rewarded with an instant respawn",
	version = "0.3",
	url = "https://github.com/Attano/Equilibrium"
};

public OnPluginStart()
{
	HookEvent("tank_frustrated", OnTankFrustrated, EventHookMode_Post);
}

public OnTankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	new tank = GetClientOfUserId(GetEventInt(event, "userid"));//正在控制tank的玩家 並不是正在傳給的那個人
	if (!IsFakeClient(tank))
	{
		lastHumanTank = tank;
		CreateTimer(0.1, CheckForAITank, _, TIMER_FLAG_NO_MAPCHANGE);
		//CreateTimer(5.1, CheckForOtherPlayerTank,lastHumanTank, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:CheckForAITank(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsTank(i))
		{
			if (IsInfected(lastHumanTank)&&IsFakeClient(i))//Tank is AI
			{
				TeleportEntity(lastHumanTank,
				Float:{0.0, 0.0, 0.0}, // Teleport to map center
				NULL_VECTOR, 
				NULL_VECTOR);
				ForcePlayerSuicide(lastHumanTank);
				//PrintToChat(lastHumanTank,"No Instant Spawn!!");
			}
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}
/*
public Action:CheckForOtherPlayerTank(Handle:timer,any:client)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsTank(i))
		{
			if (IsInfected(lastHumanTank)&&!IsFakeClient(i)&& i!=client )//Tank is another player
			{
				ForcePlayerSuicide(client);
				//PrintToChat(client,"No Instant Spawn!!");
			}
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}
*/

bool:IsTank(client)
{
	return (IsInfected(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 5);
}

bool:IsInfected(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3);
}
