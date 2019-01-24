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
new Handle:g_hCvarColor;

new Handle:hTankProps       = INVALID_HANDLE;
new Handle:hTankPropsHit    = INVALID_HANDLE;
new i_Ent[5000] = -1;
new i_EntSpec[5000]= -1;
new g_iCvarColor[3];

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
	cvar_tankPropsGlowinterval = CreateConVar( "l4d_tank_props_glow_Refresh_interval", "0.01", "Props Glow Refresh time interval",FCVAR_PLUGIN);
	g_hCvarColor =	CreateConVar(	"l4d2_tank_prop_glow_color",		"255 0 0",			"Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", FCVAR_NOTIFY);
	
	HookConVarChange(cvar_tankProps, TankPropsChange);
	HookConVarChange(cvar_tankPropsGlow, TankPropsGlowChange);
	HookConVarChange(cvar_tankPropsGlowSpec, TankPropsGlowSpecChange);
	HookConVarChange(g_hCvarColor, ConVarChanged_Glow);
	
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
	GetColor(g_hCvarColor,g_iCvarColor);
	
	HookEvent("round_start", TankPropRoundReset);
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

public ConVarChanged_Glow( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
	GetColor(g_hCvarColor,g_iCvarColor);

	if(!tankSpawned) return;

	new entity;

	for ( new i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
		if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
			entity = i_Ent[GetArrayCell(hTankPropsHit, i)];
			if( IsValidEntRef(entity) )
			{
				SetEntityRenderColor (entity, g_iCvarColor[0],g_iCvarColor[1],g_iCvarColor[2],200 );
			}
			entity = i_EntSpec[GetArrayCell(hTankPropsHit, i)];
			if( IsValidEntRef(entity) )
			{
				SetEntityRenderColor (entity, g_iCvarColor[0],g_iCvarColor[1],g_iCvarColor[2],200 );
			}
		}
	}
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
	SetEntityRenderMode( i_Ent[entity], RENDER_GLOW );
	SetEntityRenderColor (i_Ent[entity], g_iCvarColor[0],g_iCvarColor[1],g_iCvarColor[2],200 );
		
	//DispatchKeyValueVector(i_Ent[entity], "origin", vPos);
	//DispatchKeyValueVector(i_Ent[entity], "angles", vAng);
	
	//SetVariantString("!activator");
	//AcceptEntityInput(i_Ent[entity], "SetParent", entity);

	CreateTimer(GetConVarFloat(cvar_tankPropsGlowinterval), KeepTankPropsGlow, entity, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}
public Action:KeepTankPropsGlow(Handle:timer, any:entity)
{
	if (!IsValidEntity(entity) || !tankSpawned)
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
			new Float:vPos[3];
			new Float:vAng[3];
			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
			GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
			TeleportEntity(i_Ent[entity], vPos, vAng, NULL_VECTOR);
		}
		
	}else
	{
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
	
	TeleportEntity(i_EntSpec[entity], vPos, vAng, NULL_VECTOR);
	DispatchSpawn(i_EntSpec[entity]);
	SetEntityRenderFx(i_EntSpec[entity], RENDERFX_FADE_FAST);

	
	//DispatchKeyValueVector(i_EntSpec[entity], "origin", vPos);
	//DispatchKeyValueVector(i_EntSpec[entity], "angles", vAng);
	
	//SetVariantString("!activator");
	//AcceptEntityInput(i_EntSpec[entity], "SetParent", entity);
	
	CreateTimer(GetConVarFloat(cvar_tankPropsGlowinterval), KeepTankPropsGlowSpectator, entity, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:KeepTankPropsGlowSpectator(Handle:timer, any:entity)
{
	if (!IsValidEntity(entity) || !tankSpawned)
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
			new Float:vPos[3];
			new Float:vAng[3];
			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
			GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
			TeleportEntity(i_EntSpec[entity], vPos, vAng, NULL_VECTOR);
		}
	}else
	{
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

bool:IsValidEntRef(entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE && entity!= -1 && IsValidEntity(entity) && IsValidEdict(entity))
		return true;
	return false;
}

public GetColor(Handle:hCvar,colorscvar[3])
{
	decl String:sTemp[12];
	GetConVarString(hCvar, sTemp, sizeof(sTemp));
	
	if( StrEqual(sTemp, "") )
	{
		colorscvar[0] = 0;
		colorscvar[1] = 0;
		colorscvar[2] = 0;
	}

	decl String:sColors[3][4];
	new color = ExplodeString(sTemp, " ", sColors, 3, 4);

	if( color != 3 )
	{
		colorscvar[0] = 0;
		colorscvar[1] = 0;
		colorscvar[2] = 0;
	}

	colorscvar[0] = StringToInt(sColors[0]);
	colorscvar[1] = StringToInt(sColors[1]);
	colorscvar[2] = StringToInt(sColors[2]);
}
