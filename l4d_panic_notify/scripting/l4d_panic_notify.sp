#include <sourcemod>
#include <sdktools>
#include <colors>
#include <l4d_direct>
#include <l4d_lib>

//Left4Dead Version: v1037
#pragma semicolon 1
#define PLUGIN_VERSION "1.5"
#define DEBUG 0
static bool:resuce_start,bool:alreadytrigger;
static finaltriggernum;
public Plugin:myinfo = 
{
	name = "L4D panic notify",
	author = "Harry Potter",
	description = "Show who triggers the panic horde",
	version = PLUGIN_VERSION,
	url = "myself"
}

public OnPluginStart()
{
	HookEvent("create_panic_event", Event_create_panic_event);
	HookEvent("round_start", Event_Round_Start);
	HookEvent("player_use", Event_PlayerUse);
	HookEvent("finale_start", Event_Finale_Start);
}

public Event_Round_Start(Handle:event, String:name[], bool:dontBroadcast)
{
	resuce_start = false;
	alreadytrigger = false;
	finaltriggernum = 0;
}

public Event_PlayerUse (Handle:event, const String:name[], bool:dontBroadcast)
{
	if(alreadytrigger) return;
	
	new client = GetClientOfUserId( GetEventInt(event, "userid") );
	new iEntid=GetEventInt(event,"targetid");
	new String:st_entname[32];
	GetEdictClassname(iEntid,st_entname,32);
	#if DEBUG
		PrintToChatAll("client = %N, iEntid = %i",client,iEntid);
		PrintToChatAll("edict classname = %s",st_entname);
	#endif
	
	if (StrEqual(st_entname,"trigger_finale"))
	{
		decl String:mapbuf[32];GetCurrentMap(mapbuf, sizeof(mapbuf));
		if(StrEqual(mapbuf, "l4d_jsarena04_arena"))
		{
			finaltriggernum++;
			if(finaltriggernum == 2)
			{
				for (new i = 1; i < MaxClients; i++)
					if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
						CPrintToChat(i,"{green}[TS] %N {default}started {lightgreen}Final Rescue", client); 
				alreadytrigger = true;
			}	
		}
		else
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
					CPrintToChat(i,"{green}[TS] {olive}%N {default}started {lightgreen}Final Rescue", client); 
			alreadytrigger = true;
		}
	}
	else if (StrEqual(st_entname,"func_button"))
	{
		decl String:mapbuf[32];
		decl String:targetname[128];
		GetEntPropString(iEntid, Prop_Data, "m_iName", targetname, sizeof(targetname));
		#if DEBUG
			PrintToChatAll("targetname = %s",targetname);
		#endif
		GetCurrentMap(mapbuf, sizeof(mapbuf));
		if(StrEqual(targetname, "washer_lift_button2") && StrEqual(mapbuf, "l4d_vs_hospital03_sewers"))
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
					CPrintToChat(i,"{green}[TS] {olive}%N {default}triggered {lightgreen}lift horde event", client); 
			alreadytrigger = true;
		}
		else if (StrEqual(targetname, "button_safedoor_PANIC") && StrEqual(mapbuf, "l4d_vs_smalltown03_ranchhouse"))
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
					CPrintToChat(i,"{green}[TS] {olive}%N {default}triggered {lightgreen}church horde event", client); 
			alreadytrigger = true;
		}
		else if (iEntid == 1197 && StrEqual(mapbuf, "l4d_vs_city17_04")) 
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
					CPrintToChat(i,"{green}[TS] {olive}%N {default}triggered {lightgreen}City 17 horde event", client);  
			alreadytrigger = true;
		} 
		else if (StrEqual(targetname, "van_button") && StrEqual(mapbuf, "l4d_jsarena02_alley"))
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
					CPrintToChat(i,"{green}[TS] {olive}%N {default}triggered {lightgreen}The Arena of the Dead horde event", client); 
			alreadytrigger = true;
		}
		else if (StrEqual(targetname, "tower_window_0_button") && StrEqual(mapbuf, "l4d_ihm02_manor"))
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
					CPrintToChat(i,"{green}[TS] {olive}%N {default}triggered {lightgreen}I Hate Mountains horde event", client); 
			alreadytrigger = true;
		}
		else if (StrEqual(targetname, "finale_start") && StrEqual(mapbuf, "l4d_dbd_new_dawn"))
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
					CPrintToChat(i,"{green}[TS] {olive}%N {default}started {lightgreen}Final Rescue", client); 
			alreadytrigger = true;
		}			
		else{
			#if DEBUG
				CPrintToChatAll("{green}[TS] {lightgreen}horde event", client); 
			#endif
		}
	}
	else if (StrEqual(st_entname,"prop_door_rotating"))
	{
		decl String:mapbuf[32];GetCurrentMap(mapbuf, sizeof(mapbuf));
		if (iEntid == 62 && StrEqual(mapbuf, "l4d_vs_city17_02"))
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
					CPrintToChat(i,"{green}[TS] {olive}%N {default}triggered {lightgreen}horde alert", client);  
			alreadytrigger = true;
		}
		else if (iEntid == 754 &&StrEqual(mapbuf, "l4d_vs_deadflagblues02_library"))
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
					CPrintToChat(i,"{green}[TS] {olive}%N {default}triggered {lightgreen}horde alert", client);  
			alreadytrigger = true;
		}
		else if (iEntid == 205 &&StrEqual(mapbuf, "l4d_vs_farm02_traintunnel"))
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
					CPrintToChat(i,"{green}[TS] {olive}%N {default}triggered {lightgreen}horde alert", client); 
			alreadytrigger = true;
		}
		else if (iEntid == 621 &&StrEqual(mapbuf, "l4d_jsarena01_town"))
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
					CPrintToChat(i,"{green}[TS] {olive}%N {default}triggered {lightgreen}horde alert", client); 
			alreadytrigger = true;
		}
	}
}

public Event_create_panic_event(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId( GetEventInt(event, "userid") );
	#if DEBUG
		PrintToChatAll("Panic Event: %N",client);
	#endif
	if(client&&IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client))
	{	for (new i = 1; i < MaxClients; i++)
			if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
				CPrintToChat(i,"{green}[TS] {olive}%N {default}triggered {lightgreen}a horde event", client);
	}
	else
		if(!resuce_start)
		{
			decl String:mapbuf[32];
			GetCurrentMap(mapbuf, sizeof(mapbuf));
			if(StrEqual(mapbuf, "l4d_river02_barge"))
			{
				for (new i = 1; i < MaxClients; i++)
					if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
						CPrintToChat(i,"{green}[TS] {olive}crow {lightgreen}horde event"); 
				return ;
			}
			else if(StrEqual(mapbuf, "l4d_deathaboard04_ship"))
			{
				for (new i = 1; i < MaxClients; i++)
					if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 2))
						CPrintToChat(i,"{green}[TS] {olive}Deadth Aboard {lightgreen}horde event"); 
				return;
			}
			else if(IsFinalMap())
			{
				#if DEBUG
					CPrintToChatAll("{green}[TS] {lightgreen}a horde event"); 
				#endif
			}
		}
}

public Action:Event_Finale_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(IsFinalMap()){
		resuce_start = true;
		CPrintToChatAll("{green}[TS] {lightgreen}Rescue Started"); 
	}
}