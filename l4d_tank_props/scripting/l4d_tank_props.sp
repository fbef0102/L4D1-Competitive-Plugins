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
new Handle:cvar_tankPropsGlowinterval;

new Handle:hTankProps       = INVALID_HANDLE;
new Handle:hTankPropsHit    = INVALID_HANDLE;
new i_Ent[5000] = -1;
new i_EntSpec[5000]= -1;
new bool:g_EndMap;

public Plugin:myinfo = {
    name        = "L4D2 Tank Props,l4d1 port by Harry",
    author      = "Jahze",
    version     = "1.2",
    description = "Stop tank props from fading whilst the tank is alive"
};

public OnPluginStart() {
    cvar_tankProps = CreateConVar("l4d_tank_props", "1", "Prevent tank props from fading whilst the tank is alive", FCVAR_PLUGIN);
    cvar_tankPropsGlow = CreateConVar("l4d_tank_props_glow", "1", "Show Hittable Glow for inf team whilst the tank is alive", FCVAR_PLUGIN);
	cvar_tankPropsGlowinterval = CreateConVar( "l4d_tank_props_glow_Refresh_interval", "0.5", "Props Glow Refresh time interval",FCVAR_PLUGIN);
	cvar_tankPropsGlowSpec = CreateConVar(	"l4d2_tank_prop_glow_spectators",	"1",	"Spectators can see the glow too", FCVAR_PLUGIN);
	
	HookConVarChange(cvar_tankProps, TankPropsChange);
	HookConVarChange(cvar_tankPropsGlow, TankPropsGlowChange);
	
	
    PluginEnable();
}

PluginEnable() {
	g_EndMap = false;
	SetConVarBool(FindConVar("sv_tankpropfade"), false);
    
    hTankProps = CreateArray();
    hTankPropsHit = CreateArray();
    
    HookEvent("round_start", TankPropRoundReset);
    HookEvent("round_end", TankPropRoundReset);
    HookEvent("tank_spawn", TankPropTankSpawn);
    HookEvent("player_death", TankPropTankKilled);
}

PluginDisable() {
	g_EndMap = true;
    SetConVarBool(FindConVar("sv_tankpropfade"), true);
    
    CloseHandle(hTankProps);
    CloseHandle(hTankPropsHit);
    
    UnhookEvent("round_start", TankPropRoundReset);
    UnhookEvent("round_end", TankPropRoundReset);
    UnhookEvent("tank_spawn", TankPropTankSpawn);
    UnhookEvent("player_death", TankPropTankKilled);
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
    if ( StringToInt(newValue) == 0 ) {
        if(tankSpawned)
			g_EndMap = true;
    }
	else{
		g_EndMap = false;
	}
}
public TankPropsInterval( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 0 ) {
        if(tankSpawned)
			g_EndMap = true;
    }
	else{
		g_EndMap = false;
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

public Action:TankPropTankKilled( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !tankSpawned ) {
        return;
    }
    
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if ( client != iTankClient ) {
        return;
    }
    
    CreateTimer(0.5, TankDeadCheck);
}

public Action:TankDeadCheck( Handle:timer ) {
    if ( GetTankClient() == -1 ) {
        UnhookTankProps();
        CreateTimer(5.0, FadeTankProps);
        tankSpawned = false;
    }
}

public PropDamaged(victim, attacker, inflictor, Float:damage, damageType) {
    if ( attacker == GetTankClient() || FindValueInArray(hTankPropsHit, inflictor) != -1 ) {
        if ( FindValueInArray(hTankPropsHit, victim) == -1 ) {
            PushArrayCell(hTankPropsHit, victim);
			
			//prop glow for inf team
			new g_infs = 0,g_specs=0;
			
			for( new j = 1; j <= MaxClients; j++ )
			{
				if (IsClientConnected(j) && IsClientInGame(j) && !IsFakeClient(j))
				{
					if(GetClientTeam(j)==3)
						g_infs++;
					else if (GetClientTeam(j)==1)
						g_specs++;
				}
			}
			
			if(GetConVarInt(cvar_tankPropsGlow) == 1)
			{
				if(g_infs>0)
					CreateTankPropGlow(victim);
				if(g_specs>0 && GetConVarInt(cvar_tankPropsGlowSpec) == 1)
					CreateTankPropGlowSpectator(victim);
			}
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
	DispatchKeyValue(i_Ent[entity], "StartDisabled", "1");
	DispatchKeyValue(i_Ent[entity], "targetname", "propglow");
	
	DispatchKeyValue(i_Ent[entity], "GlowForTeam", "3");

	/* GlowForTeam =  -1:ALL  , 0:NONE , 1:SPECTATOR  , 2:SURVIVOR , 3:INFECTED */
	
	DispatchKeyValue(i_Ent[entity], "fadescale", "1");
	DispatchKeyValue(i_Ent[entity], "fademindist", "3000");
	DispatchKeyValue(i_Ent[entity], "fademaxdist", "3200");
	
	vPos[2] = vPos[2] - 5.0; // Fix position
	
	TeleportEntity(i_Ent[entity], vPos, vAng, NULL_VECTOR);
	DispatchSpawn(i_Ent[entity]);
	SetEntityRenderFx(i_Ent[entity], RENDERFX_FADE_FAST);
	
	CreateTimer(GetConVarFloat(cvar_tankPropsGlowinterval), KeepTankPropsGlow, entity, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:KeepTankPropsGlow(Handle:timer, any:entity)
{
	if (!IsValidEntity(entity) || !tankSpawned || g_EndMap == true)
	{
		if (IsValidEdict(i_Ent[entity]))
		{
			RemoveEdict(i_Ent[entity]);
		}
		return Plugin_Stop;
	}
	
	if (IsValidEntity(entity))
	{
		if (IsValidEdict(i_Ent[entity]))
		{
			decl String:targetname[128];
			GetEntPropString(i_Ent[entity], Prop_Data, "m_iName", targetname, sizeof(targetname));
			//PrintToChatAll("targetname :%s",targetname);
			if(!StrEqual(targetname, "propglow"))
			{
				RemoveEdict(i_Ent[entity]);
				return Plugin_Stop;
			}
			new Float:vPos[3];
			new Float:vAng[3];
			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
			GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
			TeleportEntity(i_Ent[entity], vPos, vAng, NULL_VECTOR);
		} else
		{
			return Plugin_Stop;
		}
		
	}else
	{
		if (IsValidEdict(i_Ent[entity]))
		{
			RemoveEdict(i_Ent[entity]);
		}
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
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
	
	vPos[2] = vPos[2] - 5.0; // Fix position
	
	TeleportEntity(i_EntSpec[entity], vPos, vAng, NULL_VECTOR);
	DispatchSpawn(i_EntSpec[entity]);
	SetEntityRenderFx(i_EntSpec[entity], RENDERFX_FADE_FAST);
	
	CreateTimer(GetConVarFloat(cvar_tankPropsGlowinterval), KeepTankPropsGlowSpectator, entity, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	SetEntPropFloat(i_EntSpec[entity], Prop_Send, "m_flPlaybackRate", 1.0); 
}

public Action:KeepTankPropsGlowSpectator(Handle:timer, any:entity)
{
	if (!IsValidEntity(entity) || !tankSpawned || g_EndMap == true)
	{
		if (IsValidEdict(i_EntSpec[entity]))
		{
			RemoveEdict(i_EntSpec[entity]);
		}
		return Plugin_Stop;
	}
	
	if (IsValidEntity(entity))
	{
		if (IsValidEdict(i_EntSpec[entity]))
		{
			decl String:targetname[128];
			GetEntPropString(i_EntSpec[entity], Prop_Data, "m_iName", targetname, sizeof(targetname));
			if(!StrEqual(targetname, "propglow"))
			{
				RemoveEdict(i_EntSpec[entity]);
				return Plugin_Stop;
			}
			new Float:vPos[3];
			new Float:vAng[3];
			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
			GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
			TeleportEntity(i_EntSpec[entity], vPos, vAng, NULL_VECTOR);
		} else
		{
			return Plugin_Stop;
		}
		
	}else
	{
		if (IsValidEdict(i_EntSpec[entity]))
		{
			RemoveEdict(i_EntSpec[entity]);
		}
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
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

public OnMapEnd()
{
	g_EndMap = true;
}

public OnMapStart()
{
	g_EndMap = false;
}
