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
	new tank = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsFakeClient(tank))
	{
		lastHumanTank = tank;
		CreateTimer(0.1, CheckForAITank, _, TIMER_FLAG_NO_MAPCHANGE);
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
				PrintToChat(lastHumanTank,"\x04[TS] \x01Passing \x04Tank \x01to AI, \x03No Instant Spawn\x01!!");
			}
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

bool:IsTank(client)
{
	return (IsInfected(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 5);
}

bool:IsInfected(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3);
}