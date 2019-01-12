#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define TANK_ZOMBIE_CLASS   5
new bool:tankSpawned;

new iTankClient = -1;

new Handle:cvar_tankProps;
new Handle:cvar_tankPropsGlow;
new Handle:cvar_tankPropsGlowSpec;

new Handle:hTankProps       = INVALID_HANDLE;
new Handle:hTankPropsHit    = INVALID_HANDLE;
new i_Ent[5000] = -1;
new i_EntSpec[5000]= -1;

public Plugin:myinfo = {
    name        = "L4D2 Tank Props,l4d1 modify by Harry",
    author      = "Jahze & Harry Potter",
    version     = "1.4",
    description = "Stop tank props from fading whilst the tank is alive + add Hittable Glow",
	url = "https://steamcommunity.com/id/fbef0102/"
};

public OnPluginStart() {
    cvar_tankProps = CreateConVar("l4d_tank_props", "1", "Prevent tank props from fading whilst the tank is alive", FCVAR_PLUGIN);
    cvar_tankPropsGlow = CreateConVar("l4d_tank_props_glow", "1", "Show Hittable Glow for inf team whilst the tank is alive", FCVAR_PLUGIN);
	cvar_tankPropsGlowSpec = CreateConVar( "l4d2_tank_prop_glow_spectators", "1", "Spectators can see the glow too", FCVAR_PLUGIN);
	
	HookConVarChange(cvar_tankProps, TankPropsChange);
	HookConVarChange(cvar_tankPropsGlow, TankPropsGlowChange);
	HookConVarChange(cvar_tankPropsGlowSpec, TankPropsGlowSpecChange);
	
	PluginEnable();
}

public OnPluginEnd()//Called when the plugin is about to be unloaded.
{
    PluginDisable();
}

PluginEnable() {
	SetConVarBool(FindConVar("sv_tankpropfade"), false);
	
	hTankProps = CreateArray();
	hTankPropsHit = CreateArray();
    
    HookEvent("round_start", TankPropRoundReset);
    HookEvent("round_end", TankPropRoundReset);
    HookEvent("tank_spawn", TankPropTankSpawn);
	HookEvent("entity_killed", PD_ev_EntityKilled);
	
	if ( GetTankClient()) {
        UnhookTankProps();
        ClearArray(hTankPropsHit);
		
        HookTankProps();
		
		tankSpawned = true;
	}
}

PluginDisable() {
    SetConVarBool(FindConVar("sv_tankpropfade"), true);
    
    UnhookEvent("round_start", TankPropRoundReset);
    UnhookEvent("round_end", TankPropRoundReset);
    UnhookEvent("tank_spawn", TankPropTankSpawn);
	UnhookEvent("entity_killed",		PD_ev_EntityKilled);
	
	
	new entity;
	
	for ( new i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
		if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
			entity = i_Ent[GetArrayCell(hTankPropsHit, i)];
			if(IsValidEntRef(entity))
				RemoveEdict(entity);
			entity = i_EntSpec[GetArrayCell(hTankPropsHit, i)];
			if(IsValidEntRef(entity))
				RemoveEdict(entity);
		}
	}
	
    UnhookTankProps();
    ClearArray(hTankPropsHit);
	
    CloseHandle(hTankProps);
    CloseHandle(hTankPropsHit);
	tankSpawned = false;
}

public TankPropsChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 0 ) {
        PluginDisable();
    }
    else {
        PluginEnable();
    }
}

public TankPropsGlowChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if(StrEqual(newValue,oldValue)) return;
	
	if ( StringToInt(newValue) == 0 ) {
		new entity;
		for ( new i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
			if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
				entity = i_Ent[GetArrayCell(hTankPropsHit, i)];
				if(IsValidEntRef(entity))
					RemoveEdict(entity);
			}
		}
    }
	else
	{
		for ( new i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
			if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
				CreateTankPropGlow(GetArrayCell(hTankPropsHit, i));
			}
		}
	}
}

public TankPropsGlowSpecChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if(StrEqual(newValue,oldValue)) return;
	
	if ( StringToInt(newValue) == 0) {
		new entity;
		for ( new i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
			if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
				entity = i_EntSpec[GetArrayCell(hTankPropsHit, i)];
				if(IsValidEntRef(entity))
					RemoveEdict(entity);
			}
		}
    }
	else
	{
		for ( new i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
			if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
				CreateTankPropGlowSpectator(GetArrayCell(hTankPropsHit, i));
			}
		}
	}
}

public Action:TankPropRoundReset( Handle:event, const String:name[], bool:dontBroadcast ) {
    tankSpawned = false;
    
    UnhookTankProps();
    ClearArray(hTankPropsHit);
}

public Action:TankPropTankSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !tankSpawned ) {
        UnhookTankProps();
        ClearArray(hTankPropsHit);
        
        HookTankProps();
        
        tankSpawned = true;
    }    
}

public Action:PD_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (tankSpawned && GetEntProp((GetEventInt(event, "entindex_killed")), Prop_Send, "m_zombieClass") == 5)
	{
		CreateTimer(1.5, TankDeadCheck,_,TIMER_FLAG_NO_MAPCHANGE);
	}
}
public Action:TankDeadCheck( Handle:timer ) {

    if ( GetTankClient() == -1 ) {
        UnhookTankProps();
        CreateTimer(1.0, FadeTankProps);
        tankSpawned = false;
    }
}

public PropDamaged(victim, attacker, inflictor, Float:damage, damageType) {
    if ( attacker == GetTankClient() || FindValueInArray(hTankPropsHit, inflictor) != -1 ) {
        if ( FindValueInArray(hTankPropsHit, victim) == -1 ) {
            PushArrayCell(hTankPropsHit, victim);
			
			
			if(GetConVarInt(cvar_tankPropsGlow) == 1)
				CreateTankPropGlow(victim);
			if(GetConVarInt(cvar_tankPropsGlowSpec) == 1)
				CreateTankPropGlowSpectator(victim);
        }
    }
}

CreateTankPropGlow(entity)
{
	decl String:sModelName[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	
	new Float:vPos[3];
	new Float:vAng[3];
		
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
	
	i_Ent[entity] = CreateEntityByName("prop_glowing_object");
	
	DispatchKeyValue(i_Ent[entity], "model", sModelName);
	DispatchKeyValue(i_Ent[entity], "StartGlowing", "1");
	//DispatchKeyValue(i_Ent[entity], "StartDisabled", "1");
	DispatchKeyValue(i_Ent[entity], "targetname", "propglow");
	
	DispatchKeyValue(i_Ent[entity], "GlowForTeam", "3");

	/* GlowForTeam =  -1:ALL  , 0:NONE , 1:SPECTATOR  , 2:SURVIVOR , 3:INFECTED */
	
	DispatchKeyValue(i_Ent[entity], "fadescale", "1");
	DispatchKeyValue(i_Ent[entity], "fademindist", "3000");
	DispatchKeyValue(i_Ent[entity], "fademaxdist", "3200");
	
	TeleportEntity(i_Ent[entity], vPos, vAng, NULL_VECTOR);
	DispatchSpawn(i_Ent[entity]);
	SetEntityRenderFx(i_Ent[entity], RENDERFX_FADE_FAST);
	
	DispatchKeyValueVector(i_Ent[entity], "origin", vPos);
	DispatchKeyValueVector(i_Ent[entity], "angles", vAng);
	
	SetVariantString("!activator");
	AcceptEntityInput(i_Ent[entity], "SetParent", entity);

	
}

CreateTankPropGlowSpectator(entity)
{
	decl String:sModelName[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	
	new Float:vPos[3];
	new Float:vAng[3];
		
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
	
	i_EntSpec[entity] = CreateEntityByName("prop_glowing_object");
	
	DispatchKeyValue(i_EntSpec[entity], "model", sModelName);
	DispatchKeyValue(i_EntSpec[entity], "StartGlowing", "1");
	DispatchKeyValue(i_EntSpec[entity], "StartDisabled", "1");
	DispatchKeyValue(i_EntSpec[entity], "targetname", "propglow");
	
	DispatchKeyValue(i_EntSpec[entity], "GlowForTeam", "1");
	
	DispatchKeyValue(i_EntSpec[entity], "fadescale", "1");
	DispatchKeyValue(i_EntSpec[entity], "fademindist", "3000");
	DispatchKeyValue(i_EntSpec[entity], "fademaxdist", "3200");
	
	TeleportEntity(i_EntSpec[entity], vPos, vAng, NULL_VECTOR);
	DispatchSpawn(i_EntSpec[entity]);
	SetEntityRenderFx(i_EntSpec[entity], RENDERFX_FADE_FAST);

	
	DispatchKeyValueVector(i_EntSpec[entity], "origin", vPos);
	DispatchKeyValueVector(i_EntSpec[entity], "angles", vAng);
	
	SetVariantString("!activator");
	AcceptEntityInput(i_EntSpec[entity], "SetParent", entity);
}

public Action:FadeTankProps( Handle:timer ) {
    for ( new i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
        if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
            RemoveEdict(GetArrayCell(hTankPropsHit, i));
        }
    }
    
    ClearArray(hTankPropsHit);
}

bool:IsTankProp( iEntity ) {
    if ( !IsValidEdict(iEntity) ) {
        return false;
    }
	
    decl String:className[64];
    GetEdictClassname(iEntity, className, sizeof(className));
    if ( StrEqual(className, "prop_physics") ) {
        if ( GetEntProp(iEntity, Prop_Send, "m_hasTankGlow", 1) ) {
            return true;
        }
    }
    else if ( StrEqual(className, "prop_car_alarm") ) {
        return true;
    }
	
	
	return false;
}

HookTankProps() {
    new iEntCount = GetMaxEntities();
    
    for ( new i = 1; i <= iEntCount; i++ ) {
        if ( IsTankProp(i) ) {
			SDKHook(i, SDKHook_OnTakeDamagePost, PropDamaged);
			PushArrayCell(hTankProps, i);
		}
    }
}

public OnAwakened(const String:output[],  caller,  activator, Float:delay)
{
	SetEntPropEnt(caller, Prop_Data, "m_hPhysicsAttacker", activator);
	SetEntPropFloat(caller, Prop_Data, "m_flLastPhysicsInfluenceTime", GetGameTime());
}

UnhookTankProps() {
    for ( new i = 0; i < GetArraySize(hTankProps); i++ ) {
        SDKUnhook(GetArrayCell(hTankProps, i), SDKHook_OnTakeDamagePost, PropDamaged);
    }
    
    ClearArray(hTankProps);
}

GetTankClient() {
    if ( iTankClient == -1 || !IsTank(iTankClient) ) {
        iTankClient = FindTank();
    }
    
    return iTankClient;
}

FindTank() {
    for ( new i = 1; i <= MaxClients; i++ ) {
        if ( IsTank(i) ) {
            return i;
        }
    }
    
    return -1;
}

bool:IsTank( client ) {
    if ( client < 0
    || !IsClientConnected(client)
    || !IsClientInGame(client)
    || GetClientTeam(client) != 3
    || !IsPlayerAlive(client) ) {
        return false;
    }
    
    new playerClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    
    if ( playerClass == TANK_ZOMBIE_CLASS ) {
        return true;
    }
    
    return false;
}

bool:IsValidEntRef(entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE && entity!= -1 && IsValidEntity(entity) && IsValidEdict(entity))
		return true;
	return false;
}
