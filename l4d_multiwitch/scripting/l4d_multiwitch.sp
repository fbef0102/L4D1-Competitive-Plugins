#pragma semicolon 1

#include <sourcemod>
#include <l4d_direct>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))
#define EXTRA_FLOW 3000.0

new Handle:	hEnabled;
new bool:	bEnabled;

new Handle:	hSpawnFreq;
new Float:	fSpawnFreq;

native IsInReady();
native IsInPause();
native Is_Ready_Plugin_On();

new Handle:	hMaxWitchAllowed;
new MaxWitchAllowed;
static bool:RoundEnd,bool:hasleftstartarea;
new Handle:	hWitchSpawnTimer;
new Handle:g_hVsBossBuffer;

new Handle:wg_min_range;
new Float:minRangeSquared;
new i_Ent[5000] = -1;
new bool:i_Ent_killed[5000] = false;
new bool:g_EndMap;
#define NULL					-1

new Handle:hw_max_health;
new Handle:hw_cap_health;
new Handle:hw_perm_gain;
new Handle:hw_temp_gain;
new Handle:pain_pills_decay_rate;

public Plugin:myinfo =
{
	name = "L4D1 Multiwitch",
	author = "CanadaRox , l4d1 modify by Harry",
	description = "A plugin designed to support witch party",
	version = "2.3",
	url = "https://steamcommunity.com/id/fbef0102/"
};

public OnPluginStart()
{
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");
	
	hEnabled = CreateConVar("l4d_multiwitch_enabled", "1", "Enable multiple witch spawning");
	HookConVarChange(hEnabled, Enabled_Changed);
	bEnabled = GetConVarBool(hEnabled);

	hSpawnFreq = CreateConVar("l4d_multiwitch_spawnfreq", "30", "How many seconds before the next witch spawns");
	HookConVarChange(hSpawnFreq, Freq_Changed);
	fSpawnFreq = GetConVarFloat(hSpawnFreq);

	hMaxWitchAllowed = CreateConVar("l4d_multiwitch_maxspawn_limit", "30", "Max Witch Spawn limit, prevent server from too many entity crash");
	HookConVarChange(hMaxWitchAllowed, hMaxWitchAllowed_Changed);
	MaxWitchAllowed = GetConVarInt(hMaxWitchAllowed);
	
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", LeftStartAreaEvent, EventHookMode_PostNoCopy);
	
	RoundEnd = false;
	hasleftstartarea = false;
	hWitchSpawnTimer = CreateTimer(fSpawnFreq, WitchSpawn_Timer, _, TIMER_REPEAT);
	
	HookEvent("witch_spawn", WitchSpawn_Event);
	HookEvent("witch_harasser_set", OnWitchWokeup);
	HookEvent("witch_killed", Event_WitchKilled);
	
	wg_min_range = CreateConVar("wg_min_range", "500", "Glows will not show if a survivor is this close to the witch", FCVAR_NONE, true, 0.0);
	HookConVarChange(wg_min_range, MinRangeChange);
	new Float:tmp = GetConVarFloat(wg_min_range);
	minRangeSquared = tmp * tmp;
	g_EndMap = false;
	
	pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");

	hw_max_health = CreateConVar("hw_max_health", "100", "Max health that a survivor can have after gaining health", FCVAR_PLUGIN, true, 100.0);
	hw_cap_health = CreateConVar("hw_cap_health", "1", "Whether to cap the health survivors can gain from this plugin", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	hw_perm_gain = CreateConVar("hw_perm_gain", "5", "Amount of perm health to gain for killing a witch", FCVAR_PLUGIN, true, 0.0);
	hw_temp_gain = CreateConVar("hw_temp_gain", "10", "Amount of temp health to gain for killing a witch", FCVAR_PLUGIN, true, 0.0);
}

public OnPluginEnd()//Called when the plugin is about to be unloaded.
{
	g_EndMap = true;
	SetConVarInt(hEnabled, 0);
}

public LeftStartAreaEvent(Handle:event, String:name[], bool:dontBroadcast)
{
	if(!Is_Ready_Plugin_On())
	{
		hasleftstartarea = true;
	}
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	hasleftstartarea = false;
	RoundEnd = false;
	g_EndMap = false;
	
}

public RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	RoundEnd = true;
	g_EndMap = true;
}

public Enabled_Changed(Handle:convar, const String:oldValue[], const String:newValue[])
{
	bEnabled = GetConVarBool(hEnabled);
}

public Freq_Changed(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (hWitchSpawnTimer != INVALID_HANDLE)
	{
		CloseHandle(hWitchSpawnTimer);
		hWitchSpawnTimer = INVALID_HANDLE;
		fSpawnFreq = GetConVarFloat(hSpawnFreq);
		if (fSpawnFreq >= 1.0)
		{
			hWitchSpawnTimer = CreateTimer(fSpawnFreq, WitchSpawn_Timer, _, TIMER_REPEAT);
		}
	}
}

public hMaxWitchAllowed_Changed(Handle:convar, const String:oldValue[], const String:newValue[])
{
	MaxWitchAllowed = GetConVarInt(hMaxWitchAllowed);
}

public Action:WitchSpawn_Timer(Handle:timer)
{
	if(!Is_Ready_Plugin_On()&&!hasleftstartarea)
	{
		return Plugin_Handled;
	}
	if(RoundEnd || IsInPause() || IsInReady())
	{
		return Plugin_Handled;
	}
	
	new iWitch = -1;
	new witchSpawnCount;
	while((iWitch = FindEntityByClassname(iWitch, "witch")) != -1)
	{
		witchSpawnCount++;
	}
	//PrintToChatAll("witchSpawnCount: %d - MaxWitchAllowed: %d",witchSpawnCount,MaxWitchAllowed);
	new SurCurrent = RoundToNearest(GetBossProximity() * 100.0);
	if (bEnabled  && witchSpawnCount < MaxWitchAllowed && SurCurrent < 100 )
	{
		for (new i = 1; i < MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				new flags = GetCommandFlags("z_spawn");
				SetCommandFlags("z_spawn", flags ^ FCVAR_CHEAT);
				FakeClientCommand(i, "z_spawn witch auto");
				SetCommandFlags("z_spawn", flags);
				return Plugin_Continue;
			}
		}
	}
	return Plugin_Continue;
}

stock Float:GetBossProximity()
{
	new Float:proximity = GetMaxSurvivorCompletion() + (GetConVarFloat(g_hVsBossBuffer) / L4DDirect_GetMapMaxFlowDistance());
	//LogMessage("L4DDirect_GetMapMaxFlowDistance() is %f and GetConVarFloat(g_hVsBossBuffer) is %f",L4DDirect_GetMapMaxFlowDistance(),GetConVarFloat(g_hVsBossBuffer));
	return proximity;
	//return MAX(proximity, 1.0);
}

stock Float:GetMaxSurvivorCompletion()
{
	new Float:flow = 0.0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			flow = MAX(flow, L4DDirect_GetFlowDistance(i));
			//LogMessage("flow is %f",flow);
		}
	}
	return (flow / L4DDirect_GetMapMaxFlowDistance());
}

public MinRangeChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new Float:v = StringToFloat(newValue);
	minRangeSquared = v*v;
}

public Action:OnPlayerRunCmd(client, &buttons)
{
	if (IsPlayerAlive(client) && GetClientTeam(client) == 2)
	{
		new psychonic = GetEntityCount();
		decl Float:clientOrigin[3];
		GetClientAbsOrigin(client, clientOrigin);
		decl Float:witchOrigin[3];
		decl String:buffer[32];
		for (new entity = MaxClients + 1; entity < psychonic; entity++)
		{
			if (IsValidEntity(entity)
					&& GetEntityClassname(entity, buffer, sizeof(buffer))
					&& StrEqual(buffer, "witch"))
			{
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", witchOrigin);
				if (GetVectorDistance(clientOrigin, witchOrigin, true) < minRangeSquared)
				{
					i_Ent_killed[entity] = true;
				}
			}
		}
	}
}

public WitchSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new WitchID = GetEventInt(event, "witchid");
	if (WitchID == NULL || !IsValidEntity(WitchID)) return;
	CreateWitchPropSpawner(WitchID);
	i_Ent_killed[WitchID] = false;
}

CreateWitchPropSpawner(WitchID)
{
	new Float:vPos[3];
	new Float:vAng[3];
	
	//new String:teamnumber[8];
	//IntToString( team, teamnumber, 8 );
		
	GetEntPropVector(WitchID, Prop_Data, "m_vecOrigin", vPos);
	GetEntPropVector(WitchID, Prop_Send, "m_angRotation", vAng);
	
	i_Ent[WitchID] = CreateEntityByName("prop_glowing_object");
	
	DispatchKeyValue(i_Ent[WitchID], "model", "models/infected/witch.mdl");
	DispatchKeyValue(i_Ent[WitchID], "StartGlowing", "1");
	DispatchKeyValue(i_Ent[WitchID], "StartDisabled", "1");
	DispatchKeyValue(i_Ent[WitchID], "targetname", "witchglow");
	
	//DispatchKeyValue(i_Ent[WitchID], "MinAnimTime", "5");
	//DispatchKeyValue(i_Ent[WitchID], "MaxAnimTime", "10");
	
	DispatchKeyValue(i_Ent[WitchID], "GlowForTeam", "2");

	/* GlowForTeam =  -1:ALL  , 0:NONE , 1:SPECTATOR  , 2:SURVIVOR , 3:INFECTED */
	
	DispatchKeyValue(i_Ent[WitchID], "fadescale", "1");
	DispatchKeyValue(i_Ent[WitchID], "fademindist", "3000");
	DispatchKeyValue(i_Ent[WitchID], "fademaxdist", "3200");
	
	vPos[2] = vPos[2] - 5.0; // Fix position
	
	TeleportEntity(i_Ent[WitchID], vPos, vAng, NULL_VECTOR);
	DispatchSpawn(i_Ent[WitchID]);
	SetEntityRenderFx(i_Ent[WitchID], RENDERFX_FADE_FAST);
	
	CreateTimer(0.5, m_SequencePos, WitchID, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	SetEntPropFloat(i_Ent[WitchID], Prop_Send, "m_flPlaybackRate", 1.0); 
}
public Action:m_SequencePos(Handle:timer, any:entity)
{
	if (!IsValidEntity(entity) || g_EndMap == true || i_Ent_killed[entity])
	{
		if (IsValidEdict(i_Ent[entity]))
		{
			RemoveEdict(i_Ent[entity]);
		}
		i_Ent_killed[entity] = true;
		return Plugin_Stop;
	}
	if (IsValidEntity(entity))
	{
		if (IsValidEdict(i_Ent[entity]))
		{
			decl String:targetname[128];
			GetEntPropString(i_Ent[entity], Prop_Data, "m_iName", targetname, sizeof(targetname));
			if(!StrEqual(targetname, "witchglow"))
			{
				RemoveEdict(i_Ent[entity]);
				return Plugin_Stop;
			}
			new Float:vPos[3];
			new Float:vAng[3];
			decl m_nSequence;
			m_nSequence = GetEntProp(entity, Prop_Send, "m_nSequence");
			if(m_nSequence<=0)
			{
				RemoveEdict(i_Ent[entity]);
				return Plugin_Stop;
			}
			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
			GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
			TeleportEntity(i_Ent[entity], vPos, vAng, NULL_VECTOR);
			SetEntProp(i_Ent[entity], Prop_Send, "m_nSequence", m_nSequence); 
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

public Action:OnWitchWokeup(Handle:event, const String:name[], bool:dontBroadcast)
{
	new WitchID = GetEventInt(event, "witchid");
	if (WitchID == NULL) return;
	if(IsValidEntity(WitchID)&&!i_Ent_killed[WitchID])
	{
		if (IsValidEdict(i_Ent[WitchID]))
		{
			RemoveEdict(i_Ent[WitchID]);
		}	
		i_Ent_killed[WitchID] = true;
	}
}

public Event_WitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	new WitchID = GetEventInt(event, "witchid");
	if (WitchID == NULL) return;
	if(IsValidEntity(WitchID)&&!i_Ent_killed[WitchID])
	{
		if (IsValidEdict(i_Ent[WitchID]))
		{
			RemoveEdict(i_Ent[WitchID]);
		}	
		i_Ent_killed[WitchID] = true;
	}
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsPlayerIncap(client))
	{
		IncreaseHealth(client);
	}
}

public OnMapEnd()
{
	g_EndMap = true;
}

public OnMapStart()
{
	g_EndMap = false;
}

IncreaseHealth(client)
{
	new bool:capped = GetConVarBool(hw_cap_health);
	new targetHealth = GetSurvivorPermHealth(client) + GetConVarInt(hw_perm_gain);
	new Float:targetTemp = GetSurvivorTempHealth(client) + GetConVarInt(hw_temp_gain);

	if (capped)
	{
		new maxHealth = GetConVarInt(hw_max_health);
		targetHealth = MIN(targetHealth, maxHealth);

		new Float:totalHealth = targetHealth + targetTemp;
		totalHealth = MIN(totalHealth, float(maxHealth));
		targetTemp = totalHealth - targetHealth;
	}

	SetSurvivorPermHealth(client, targetHealth);
	SetSurvivorTempHealth(client, targetTemp);
}

stock GetSurvivorPermHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock SetSurvivorPermHealth(client, health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}

stock Float:GetSurvivorTempHealth(client)
{
	new Float:tmp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(pain_pills_decay_rate));
	return tmp > 0 ? tmp : 0.0;
}

stock SetSurvivorTempHealth(client, Float:newOverheal)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal);
}

stock bool:IsPlayerIncap(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}
