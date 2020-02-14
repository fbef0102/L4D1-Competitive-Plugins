#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>

#define BOOMER_ZOMBIE_CLASS     2

new bool:bLateLoad;
new Handle:cvar_bashKills;

public Plugin:myinfo =
{
    name        = "L4D Bash Kills",
    author      = "Jahze,Harry Potter",
    version     = "1.1",
    description = "Stop special infected getting bashed to death,L4D1 port by Harry"
}

public APLRes:AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax) {
    bLateLoad = late;
    return APLRes_Success;
}

public OnPluginStart() {
    cvar_bashKills = CreateConVar("l4d_no_bash_kills", "1", "Prevent special infected from getting bashed to death", FCVAR_PLUGIN);

    if ( bLateLoad ) {
        for ( new i = 1; i < MaxClients+1; i++ ) {
            if ( IsClientInGame(i) ) {
                SDKHook(i, SDKHook_OnTakeDamage, Hurt);
            }
        }
    }
}

public Action:Hurt( victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3] ) {
	if ( !GetConVarBool(cvar_bashKills) || !IsSI(victim) ) {
		return Plugin_Continue;
    }
    //PrintToChatAll("damage is %d ,damageType is %d,weapon is %d",damage, damageType,weapon);
	if ( damage == 250.0 && damageType && weapon == -1 && IsSurvivor(attacker) ){
		if(GetEntProp(victim, Prop_Send, "m_zombieClass") == BOOMER_ZOMBIE_CLASS)
		{
			decl String:victimname[128];
			GetClientName(victim,victimname,128);
			decl String:attackername[128];
			GetClientName(attacker,attackername,128);
			CPrintToChatAll("[{olive}TS{default}] {olive}%N{default} shoves-kill {red}%N{default}'s Boomer",attacker,victim);
			return Plugin_Continue;
		}
		return Plugin_Handled;
    }
	return Plugin_Continue;
}

bool:IsSI( client ) {
    if ( !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) ) {
        return false;
    }
    
    return true;
}

bool:IsSurvivor( client ) {
    if ( client < 1
    || !IsClientConnected(client)
    || !IsClientInGame(client)
    || GetClientTeam(client) != 2
    || !IsPlayerAlive(client) ) {
        return false;
    }
    
    return true;
}