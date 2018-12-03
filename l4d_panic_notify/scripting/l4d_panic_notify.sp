#include <sourcemod>
#include <sdktools>
#include <colors>
#include <l4d_direct>
#include <l4d_lib>

//Left4Dead Version: v1036
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
				CPrintToChatAll("{green}[提示] {olive}%N {default}啟動了 {lightgreen}最後救援", client); 
				alreadytrigger = true;
			}	
		}
		else
		{
			CPrintToChatAll("{green}[提示] {olive}%N {default}啟動了 {lightgreen}最後救援", client); 
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
			{CPrintToChatAll("{green}[提示] {olive}%N {default}觸發了 {lightgreen}升降梯屍潮事件", client); alreadytrigger = true;}
		else if (StrEqual(targetname, "button_safedoor_PANIC") && StrEqual(mapbuf, "l4d_vs_smalltown03_ranchhouse"))
			{CPrintToChatAll("{green}[提示] {olive}%N {default}觸發了 {lightgreen}喪鐘屍潮事件", client); alreadytrigger = true;}
		else if (iEntid == 1197 && StrEqual(mapbuf, "l4d_vs_city17_04")) 
			{CPrintToChatAll("{green}[提示] {olive}%N {default}觸發了 {lightgreen}City 17屍潮事件", client);  alreadytrigger = true;} 
		else if (StrEqual(targetname, "van_button") && StrEqual(mapbuf, "l4d_jsarena02_alley"))
			{CPrintToChatAll("{green}[提示] {olive}%N {default}觸發了 {lightgreen}貨車屍潮事件", client); alreadytrigger = true;}
		else if (StrEqual(targetname, "tower_window_0_button") && StrEqual(mapbuf, "l4d_ihm02_manor"))
			{CPrintToChatAll("{green}[提示] {olive}%N {default}觸發了 {lightgreen}I Hate Mountains屍潮事件", client); alreadytrigger = true;}
		else if (StrEqual(targetname, "finale_start") && StrEqual(mapbuf, "l4d_dbd_new_dawn"))
			{CPrintToChatAll("{green}[提示] {olive}%N {default}啟動了 {lightgreen}最後救援", client); alreadytrigger = true;}			
		else{
			#if DEBUG
				CPrintToChatAll("{green}[提示] {lightgreen}按鈕事件", client); 
			#endif
		}
	}
	else if (StrEqual(st_entname,"prop_door_rotating"))
	{
		decl String:mapbuf[32];GetCurrentMap(mapbuf, sizeof(mapbuf));
		if (iEntid == 62 && StrEqual(mapbuf, "l4d_vs_city17_02"))
			{CPrintToChatAll("{green}[提示] {olive}%N {default}觸發了 {lightgreen}警報門屍潮事件", client);  alreadytrigger = true;}
		else if (iEntid == 754 &&StrEqual(mapbuf, "l4d_vs_deadflagblues02_library"))
			{CPrintToChatAll("{green}[提示] {olive}%N {default}觸發了 {lightgreen}警報門屍潮事件", client);  alreadytrigger = true;}
		else if (iEntid == 205 &&StrEqual(mapbuf, "l4d_vs_farm02_traintunnel"))
			{CPrintToChatAll("{green}[提示] {olive}%N {default}觸發了 {lightgreen}警報門屍潮事件", client); alreadytrigger = true;}
		else if (iEntid == 621 &&StrEqual(mapbuf, "l4d_jsarena01_town"))
			{CPrintToChatAll("{green}[提示] {olive}%N {default}觸發了 {lightgreen}警報門屍潮事件", client); alreadytrigger = true;}
	}
}

public Event_create_panic_event(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId( GetEventInt(event, "userid") );
	#if DEBUG
		PrintToChatAll("Panic Event: %N",client);
	#endif
	if(client&&IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client))
		CPrintToChatAll("{green}[提示] {olive}%N {default}觸發了 {lightgreen}屍潮事件", client);
	else
		if(!resuce_start)
		{
			decl String:mapbuf[32];
			GetCurrentMap(mapbuf, sizeof(mapbuf));
			if(StrEqual(mapbuf, "l4d_river02_barge"))
			{
				CPrintToChatAll("{green}[提示] {olive}烏鴉 {lightgreen}屍潮事件", client); 
				return ;
			}
			else if(StrEqual(mapbuf, "l4d_deathaboard04_ship"))
			{
				CPrintToChatAll("{green}[提示] {olive}Deadth Aboard {lightgreen}屍潮事件", client); 
				return;
			}
			else if(IsFinalMap())
			{
				#if DEBUG
					CPrintToChatAll("{green}[提示] {lightgreen}屍潮事件", client); 
				#endif
			}
		}
}

public Action:Event_Finale_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(IsFinalMap()){
		resuce_start = true;
		CPrintToChatAll("{green}[提示] {lightgreen}救援開始"); 
	}
}
