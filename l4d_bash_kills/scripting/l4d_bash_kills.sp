#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>

#define BOOMER_ZOMBIE_CLASS     2

new bool:bLateLoad;
new Handle:cvar_bashKills;
new Handle:cvar_bashKillBoomerTimes;
static	bashKillClientBoomer[MAXPLAYERS + 1] = {0};

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
    cvar_bashKillBoomerTimes = CreateConVar("l4d_bash_kill_boomer_times", "3", "shove X times to kill boomer", FCVAR_PLUGIN);
	
    HookEvent("player_spawn", Event_Player_Spawn);
    HookEvent("player_shoved", OutSkilled);
    HookEvent("player_bot_replace", OnBotSwap);
    HookEvent("bot_player_replace", OnBotSwap);

    if ( bLateLoad ) {
        for ( new i = 1; i < MaxClients+1; i++ ) {
            if ( IsClientInGame(i) ) {
                SDKHook(i, SDKHook_OnTakeDamage, Hurt);
            }
        }
    }
}

public OnClientPutInServer( client ) {
    SDKHook(client, SDKHook_OnTakeDamage, Hurt);
    bashKillClientBoomer[client] = 0;
}

public Action:Event_Player_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{ 
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsSI(client))
	{
		bashKillClientBoomer[client] = 0;
	}

	return Plugin_Handled;
}
public Action:OutSkilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	new shovee = GetClientOfUserId(GetEventInt(event, "userid"));
	new shover = GetClientOfUserId(GetEventInt(event, "attacker"));	
	if(IsSI(shovee) && GetEntProp(shovee, Prop_Send, "m_zombieClass") == BOOMER_ZOMBIE_CLASS && IsSurvivor(shover))
	{
		bashKillClientBoomer[shovee] ++;
		if(bashKillClientBoomer[shovee]>=GetConVarInt(cvar_bashKillBoomerTimes))
		{
			new entPointHurt = CreateEntityByName("point_hurt");
			if(!entPointHurt) return;

			decl Float:victimPos[3], String:strDamage[16], String:strDamageTarget[16];
			
			GetClientEyePosition(shovee, victimPos);
			IntToString(250, strDamage, sizeof(strDamage));
			Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", shovee);

			DispatchKeyValue(shovee, "targetname", strDamageTarget);
			DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
			DispatchKeyValue(entPointHurt, "Damage", strDamage);
			DispatchKeyValue(entPointHurt, "DamageType", "128"); // DMG_GENERIC
			DispatchSpawn(entPointHurt);
			
			// Teleport, activate point_hurt
			TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(entPointHurt, "Hurt", shover);
			
			// Config, delete point_hurt
			DispatchKeyValue(entPointHurt, "classname", "point_hurt");
			DispatchKeyValue(shovee, "targetname", "null");
			RemoveEdict(entPointHurt);
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

public Action:OnBotSwap(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	new player = GetClientOfUserId(GetEventInt(event, "player"));
	if (IsClientIndex(bot) && IsClientIndex(player)) 
	{
		if (StrEqual(name, "player_bot_replace")) 
		{
			bashKillClientBoomer[bot] = bashKillClientBoomer[player];
			bashKillClientBoomer[player] = 0;
			
		}
		else 
		{
			bashKillClientBoomer[player] = bashKillClientBoomer[bot];
			bashKillClientBoomer[bot] = 0;
		}
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

bool:IsClientIndex(client)
{
	return (client > 0 && client <= MaxClients);
}