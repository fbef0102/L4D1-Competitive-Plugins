#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d_weapon_stocks>

new g_PlayerSecondaryWeapons[MAXPLAYERS + 1];
new g_PlayerSecondaryCount[MAXPLAYERS + 1];
new g_PlayerPrimaryWeapons[MAXPLAYERS + 1];
#define MAXENTITIES 2048

public Plugin:myinfo =
{
	name        = "L4D Drop Secondary",
	author      = "Jahze, Visor,l4d1 modify by Harry",
	version     = "2.3",
	description = "Survivor players will drop their secondary weapon when they die",
	url         = "https://github.com/Attano/Equilibrium"
};

public OnPluginStart() 
{
	HookEvent("round_start", EventHook:OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_use", OnPlayerUse, EventHookMode_Post);
	HookEvent("player_bot_replace", OnBotSwap);
	HookEvent("bot_player_replace", OnBotSwap);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
}

public OnRoundStart() 
{
	for (new i = 0; i <= MAXPLAYERS; i++) 
	{
		g_PlayerSecondaryWeapons[i] = -1;
		g_PlayerSecondaryCount[i] = -1;
		g_PlayerPrimaryWeapons[i] = -1;
	}
}

public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsSurvivor(client))
	{
		new weapon = GetPlayerWeaponSlot(client, _:L4DWeaponSlot_Secondary);
		
		new pistolcount = SecondaryPistolCount(weapon);
		if (pistolcount>0)
		{
			g_PlayerSecondaryWeapons[client] = weapon;
			if(pistolcount == 1)
			{
				g_PlayerSecondaryWeapons[client] = weapon;
				g_PlayerSecondaryCount[client] = 1;
			}
			else
			{
				g_PlayerSecondaryWeapons[client] = weapon;
				g_PlayerSecondaryCount[client] = 2;
			}
			
			//PrintToChatAll("client:%N - %d",client,g_PlayerSecondaryWeapons[client]);
		}
	}
	return Plugin_Continue;
}

public Action:OnPlayerUse(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsSurvivor(client)) 
	{
		new weapon = GetPlayerWeaponSlot(client, _:L4DWeaponSlot_Secondary);
		
		new pistolcount = SecondaryPistolCount(weapon);
		if (pistolcount>0)
		{
			g_PlayerSecondaryWeapons[client] = weapon;
			if(pistolcount == 1)
			{
				g_PlayerSecondaryWeapons[client] = weapon;
				g_PlayerSecondaryCount[client] = 1;
			}
			else
			{
				g_PlayerSecondaryWeapons[client] = weapon;
				g_PlayerSecondaryCount[client] = 2;
			}
			
			//PrintToChatAll("client:%N - %d",client,g_PlayerSecondaryWeapons[client]);
		}
		
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
			g_PlayerSecondaryWeapons[bot] = g_PlayerSecondaryWeapons[player];
			g_PlayerSecondaryWeapons[player] = -1;
			g_PlayerSecondaryCount[bot] = g_PlayerSecondaryCount[player];
			g_PlayerSecondaryCount[player] = -1;
			
		}
		else 
		{
			g_PlayerSecondaryWeapons[player] = g_PlayerSecondaryWeapons[bot];
			g_PlayerSecondaryWeapons[bot] = -1;
			g_PlayerSecondaryCount[player] = g_PlayerSecondaryCount[bot];
			g_PlayerSecondaryCount[bot] = -1;
		}
	}
	return Plugin_Continue;
}

public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsSurvivor(client)) 
	{
		new weapon = g_PlayerSecondaryWeapons[client];
		new weaponcount = g_PlayerSecondaryCount[client];
		SetEntPropEnt(weapon, Prop_Data, "m_hOwner",client);
		//PrintToChatAll("client:%d - weapon:%d - weaponcount:%d GetWeaponOwner(weapon):%d",client,weapon,weaponcount,GetWeaponOwner(weapon));
		if(IdentifyWeapon(weapon) != WEPID_NONE && client == GetWeaponOwner(weapon) )
		{
			//PrintToChatAll("spawn pistol");
			if(weaponcount==1)
			{
				SDKHooks_DropWeapon(client, weapon);
			}
			else
			{
				//PrintToChatAll("double");
				SDKHooks_DropWeapon(client, weapon);
			}	
		}
		
		
	}
	return Plugin_Continue;
}

SecondaryPistolCount(weapon)
{
	new WeaponId:wepid = IdentifyWeapon(weapon);
	//PrintToChatAll("wepid:%d WEPID_PISTOL:%d",wepid,WEPID_PISTOL);
	if(wepid == WEPID_PISTOL)
	{
		if(GetEntProp(weapon, Prop_Send, "m_isDualWielding"))
			return 2;
		else
			return 1;
	}
	return -1;
}

GetWeaponOwner(weapon)
{
	return GetEntPropEnt(weapon, Prop_Data, "m_hOwner");
}

bool:IsClientIndex(client)
{
	return (client > 0 && client <= MaxClients);
}

bool:IsSurvivor(client)
{
	return (IsClientIndex(client) && IsClientInGame(client) && GetClientTeam(client) == 2);
}

stock bool:SafelyRemoveEdict(entity)
{
	if (entity == INVALID_ENT_REFERENCE || entity < 0 || entity > MAXENTITIES || !IsValidEntity(entity))
	{
		return false;
	}

	// Try and use the entity's kill input first.  If that doesn't work, fall back on SafelyRemoveEdict.
	// AFAIK, we should always try to use Kill, as I've noticed problems when calling SafelyRemoveEdict (ents sticking around after deletion).
	// This could be down to my own idiocy, but ... still.
	if(!AcceptEntityInput(entity, "Kill"))
	{
		SafelyRemoveEdict(entity);
	}

	return true;
}