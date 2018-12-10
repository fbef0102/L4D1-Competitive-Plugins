#pragma semicolon 1
#include <sourcemod>
#include "colors.inc"

//#define clamp(%0, %1, %2) ( ((%0) < (%1)) ? (%1) : ( ((%0) > (%2)) ? (%2) : (%0) ) )
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

public Plugin:myinfo = 
{
	name = "LerpTracker",
	author = "ProdigySim (archer edit),l4d1 modify by Harry",
	description = "Keep track of players' lerp settings",
	version = "1.0",
	url = "https://bitbucket.org/ProdigySim/misc-sourcemod-plugins"
};

/* Global Vars */
new Float:g_fCurrentLerps[MAXPLAYERS+1];

/* My CVars */
new Handle:hLogLerp;
new Handle:hAnnounceLerp;
new Handle:hFixLerpValue;
new Handle:hMaxLerpValue;

/* Valve CVars */
new Handle:hMinUpdateRate;
new Handle:hMaxUpdateRate;
new Handle:hMinInterpRatio;
new Handle:hMaxInterpRatio;
//what even?
new Handle:hPrintLerpStyle;

static Handle:cVarMinLerp;
static Handle:cVarMaxLerp;

// psychonic made me do it

#define ShouldFixLerp() (GetConVarBool(hFixLerpValue))

#define ShouldAnnounceLerpChanges() (GetConVarBool(hAnnounceLerp))

#define DefaultLerpStyle() (GetConVarBool(hPrintLerpStyle))

#define ShouldLogLerpChanges() (GetConVarBool(hLogLerp))

#define ShouldLogInitialLerp() (GetConVarInt(hLogLerp) == 1)

#define IsCurrentLerpValid(%0) (g_fCurrentLerps[(%0)] >= 0.0)

#define InvalidateCurrentLerp(%0) (g_fCurrentLerps[(%0)] = -1.0)

#define GetCurrentLerp(%0) (g_fCurrentLerps[(%0)])
#define SetCurrentLerp(%0,%1) (g_fCurrentLerps[(%0)] = (%1))
native Is_Ready_Plugin_On();
static bool:blerpdetect[MAXPLAYERS + 1];
static ClientTeam[MAXPLAYERS + 1];
static bool:roundstart;
#define COLDDOWN_DELAY 6.0

public OnPluginStart()
{
	hMinUpdateRate = FindConVar("sv_minupdaterate");
	hMaxUpdateRate = FindConVar("sv_maxupdaterate");
	hMinInterpRatio = FindConVar("sv_client_min_interp_ratio");
	hMaxInterpRatio= FindConVar("sv_client_max_interp_ratio");
	hLogLerp = CreateConVar("sm_log_lerp", "1", "Log changes to client lerp. 1=Log initial lerp and changes 2=Log changes only", FCVAR_PLUGIN);
	hAnnounceLerp = CreateConVar("sm_announce_lerp", "1", "Announce changes to client lerp. 1=Announce initial lerp and changes 2=Announce changes only", FCVAR_PLUGIN);
	hFixLerpValue = CreateConVar("sm_fixlerp", "1", "Fix Lerp values clamping incorrectly when interp_ratio 0 is allowed", FCVAR_PLUGIN);
	hMaxLerpValue = CreateConVar("sm_max_interp", "0.1", "Kick players whose settings breach this Hard upper-limit for player lerps.", FCVAR_PLUGIN);
	hPrintLerpStyle = CreateConVar("sm_lerpstyle", "1", "Display Style, 0 = default, 1 = team based", FCVAR_PLUGIN);
	cVarMinLerp = CreateConVar("sm_min_lerp", "0.000", "Minimum allowed lerp value", FCVAR_PLUGIN);
	cVarMaxLerp = CreateConVar("sm_max_lerp", "0.067", "Maximum allowed lerp value, 超過踢到旁觀", FCVAR_PLUGIN);
	
	RegConsoleCmd("sm_lerps", Lerps_Cmd, "List the Lerps of inf/sur players in game", FCVAR_PLUGIN);
	RegConsoleCmd("sm_lerpss", Lerpss_Cmd, "List the Lerps of spec players in game", FCVAR_PLUGIN);
	
	HookEvent("player_team", OnTeamChange);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	
	ScanAllPlayersLerp();
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	CreateTimer(3.0, roundstart_true,_, _);
}
public Action:roundstart_true(Handle:timer, any:client)
{
	roundstart = true;
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	roundstart = false;
}

public OnClientDisconnect_Post(client)
{
	InvalidateCurrentLerp(client);
}

/* Lerp calculation adapted from hl2sdk's CGameServerClients::OnClientSettingsChanged */
public OnClientSettingsChanged(client)
{
	if(IsValidEntity(client) &&  !IsFakeClient(client)&& blerpdetect[client])
	{
		ProcessPlayerLerp(client);
	}
}

public OnTeamChange(Handle:event, String:name[], bool:dontBroadcast)
{
	//if (GetEventInt(event, "team") != 1)
	//{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (client > 0 && client < MaxClients+1)
		{
			if (IsClientInGame(client) && !IsFakeClient(client))
			{
				CreateTimer(1.0, OnTeamChangeDelay, client, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
    //}
}

public OnClientPutInServer(client)
{
	blerpdetect[client] = false;
	CreateTimer(COLDDOWN_DELAY, COLDOWN,client, TIMER_FLAG_NO_MAPCHANGE);
	ClientTeam[client] = 0;
}

public Action:COLDOWN(Handle:timer, any:client)
{
	blerpdetect[client] = true;
	if (client && IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client) && GetClientTeam(client) != 1 && blerpdetect[client])
	{
		ClientTeam[client] = GetClientTeam(client);
		ProcessPlayerLerp(client,true);
	}
}

public Action:OnTeamChangeDelay(Handle:timer, any:client)
{
	new iTeam;
	if(!(client && IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client)))
		return Plugin_Continue;
	else
		iTeam = GetClientTeam(client);
	if (blerpdetect[client] && ClientTeam[client] != iTeam)
	{
		ClientTeam[client] = iTeam;
		if(iTeam != 1)
			ProcessPlayerLerp(client,true);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}


public Action:Lerps_Cmd(client, args)
{
	if(!DefaultLerpStyle())
	{
		new lerpcnt;
		
		for(new rclient=1; rclient <= MaxClients; rclient++)
		{
			if(IsClientInGame(rclient) && !IsFakeClient(rclient) && GetClientTeam(rclient) != 1)
			{
				ReplyToCommand(client, "%02d. %N Lerp: %.01f", ++lerpcnt, rclient, (GetCurrentLerp(rclient)*1000));
			}
		}
	}
	else
	{
		new survivorCount = 0;
		new infectedCount = 0;
		//new bool:survivorPrinted = false;
		//new bool:infectedPrinted
		
		
		for(new rclient=1; rclient <= MaxClients; rclient++)
		{
			if(IsClientInGame(rclient) && !IsFakeClient(rclient))
			{
				if (GetClientTeam(rclient) == 2) survivorCount = 1;
				if (GetClientTeam(rclient) == 3) infectedCount = 1;
			}
		}
		
		if (survivorCount == 1 || infectedCount == 1) CPrintToChat(client, "{blue}{green}______________________________");
		
		for(new rclient=1; rclient <= MaxClients; rclient++)
		{
			if(IsClientInGame(rclient) && !IsFakeClient(rclient) && GetClientTeam(rclient) == 2)
			{
				CPrintToChat(client, "{blue}%N {default}@ {green}%.01f", rclient, (GetCurrentLerp(rclient)*1000));				
			}			
		}
		//if (survivorCount == 1 && infectedCount == 1) CPrintToChat(client, "{blue}{default} ");
		for(new rclient=1; rclient <= MaxClients; rclient++)
		{
			
			/*if (survivorCount == 1 && infectedCount == 1 && !survivorPrinted)
			{
				survivorPrinted = true;
				survivorCount++;
				infectedCount++;
				CPrintToChat(client, "{default}seperator");				
			}*/
			if(IsClientInGame(rclient) && !IsFakeClient(rclient) && GetClientTeam(rclient) == 3)
			{
				CPrintToChat(client, "{red}%N {default}@ {green}%.01f", rclient, (GetCurrentLerp(rclient)*1000));
				//CPrintToChat(client, "{blue}TEST {green}%i", survivorCount);
			}
		}
		if (survivorCount == 1 || infectedCount == 1) CPrintToChat(client, "{blue}{green}______________________________");
		//PrintToChat(client, "%i", survivorCount);
	}
	return Plugin_Handled;
}

public Action:Lerpss_Cmd(client, args)
{
	new rclient;
	if(!DefaultLerpStyle())
	{
		new lerpcnt;
		for(rclient=1; rclient <= MaxClients; rclient++)
		{
			if(IsClientInGame(rclient) && !IsFakeClient(rclient) && GetClientTeam(rclient) == 1)
			{
				ReplyToCommand(client, "%02d. %N Lerp: %.01f", ++lerpcnt, rclient, (GetCurrentLerp(rclient)*1000));
			}
		}
	}
	else
	{
		new bool:specPrinted = false;
		//new bool:survivorPrinted = false;
		//new bool:infectedPrinted
		
		
		for(rclient=1; rclient <= MaxClients; rclient++)
		{
			if(IsClientInGame(rclient) && !IsFakeClient(rclient) && GetClientTeam(rclient) == 1)
			{
				specPrinted = true;
				break;
			}
		}
		
		if (specPrinted) CPrintToChat(client, "{blue}{green}______________________________");
		
		for(rclient=1; rclient <= MaxClients; rclient++)
		{
			if(IsClientInGame(rclient) && !IsFakeClient(rclient) && GetClientTeam(rclient) == 1)
			{
				CPrintToChat(client, "{lightgreen}%N {default}@ {green}%.01f", rclient, (GetCurrentLerp(rclient)*1000));				
			}			
		}
		if (specPrinted) CPrintToChat(client, "{blue}{green}______________________________");
	}
	return Plugin_Handled;
}

ScanAllPlayersLerp()
{
	for(new client=1; client <= MaxClients; client++)
	{
		InvalidateCurrentLerp(client);
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			ProcessPlayerLerp(client);
		}
	}
}

ProcessPlayerLerp(client,bool:teamchange = false)
{	
	new Float:m_fLerpTime = GetEntPropFloat(client, Prop_Data, "m_fLerpTime");
	new iTeam = GetClientTeam(client);
	if(ShouldFixLerp())
	{
		m_fLerpTime = GetLerpTime(client);
		SetEntPropFloat(client, Prop_Data, "m_fLerpTime", m_fLerpTime);
	}
	
	if(IsCurrentLerpValid(client))
	{
		if(m_fLerpTime != GetCurrentLerp(client))
		{
			if(ShouldAnnounceLerpChanges())
			{
				if (iTeam == 2)
					CPrintToChatAll("<{olive}Lerp{default}> {blue}%N{green}'s Lerp改變 {olive}%.01f {green}成 {olive}%.01f", client, GetCurrentLerp(client)*1000, m_fLerpTime*1000);
				else if (iTeam == 3)
					CPrintToChatAll("<{olive}Lerp{default}> {red}%N{green}'s Lerp改變 {olive}%.01f {green}成 {olive}%.01f", client, GetCurrentLerp(client)*1000, m_fLerpTime*1000);
			}
		}
	}
	
	new Float:max=GetConVarFloat(hMaxLerpValue);
	if(m_fLerpTime > max)
	{
		if (iTeam != 1)
		{
			KickClient(client, "Lerp %.01f exceeds server max of %.01f", m_fLerpTime*1000, max*1000);
			CPrintToChatAll("<{olive}Lerp{default}> %N kicked for lerp too high. %.01f > %.01f", client, m_fLerpTime*1000, max*1000);
		}
		if(ShouldLogLerpChanges())
		{
			LogMessage("Kicked %L for having lerp %.01f (max: %.01f)", client, m_fLerpTime*1000, max*1000);
		}
	}
	else
	{
		SetCurrentLerp(client, m_fLerpTime);
	}
	
	if ( ((FloatCompare(m_fLerpTime, GetConVarFloat(cVarMinLerp)) == -1) || (FloatCompare(m_fLerpTime, GetConVarFloat(cVarMaxLerp)) == 1)) && Is_Ready_Plugin_On() && GetClientTeam(client) != 1) {
		
		//PrintToChatAll("<{olive}Lerp{default}> %N's lerp changed to %.01f", client, m_fLerpTime*1000);
		CPrintToChatAll("<{olive}Lerp{default}> {lightgreen}%N{default}'s Lerp {olive}%.01f{default} 被移至旁觀!", client, m_fLerpTime*1000);
		ChangeClientTeam(client, 1);
		CPrintToChat(client, "{blue}{default}[{green}提示{default}] Illegal lerp value (min: {olive}%.01f{default}, max: {olive}%.01f{default})",
					GetConVarFloat(cVarMinLerp)*1000, GetConVarFloat(cVarMaxLerp)*1000);
		// nothing else to do
		return;
	}
	if(teamchange&&roundstart)
	{
		if(iTeam == 2)
			CPrintToChatAll("<{olive}Lerp{default}> {blue}%N {default}@{blue} %.01f",client,m_fLerpTime*1000);
		else if (iTeam == 3)
			CPrintToChatAll("<{olive}Lerp{default}> {red}%N {default}@{red} %.01f",client,m_fLerpTime*1000);
	}
}



stock Float:GetLerpTime(client)
{
	decl String:buf[64], Float:lerpTime;
	
#define QUICKGETCVARVALUE(%0) (GetClientInfo(client, (%0), buf, sizeof(buf)) ? buf : "")
	
	new updateRate = StringToInt( QUICKGETCVARVALUE("cl_updaterate") );
	updateRate = RoundFloat(clamp(float(updateRate), GetConVarFloat(hMinUpdateRate), GetConVarFloat(hMaxUpdateRate)));
	
	/*new bool:useInterpolation = StringToInt( QUICKGETCVARVALUE("cl_interpolate") ) != 0;
	if ( useInterpolation )
	{*/
	new Float:flLerpRatio = StringToFloat( QUICKGETCVARVALUE("cl_interp_ratio") );
	/*if ( flLerpRatio == 0 )
		flLerpRatio = 1.0;*/
	new Float:flLerpAmount = StringToFloat( QUICKGETCVARVALUE("cl_interp") );

	
	if ( hMinInterpRatio != INVALID_HANDLE && hMaxInterpRatio != INVALID_HANDLE && GetConVarFloat(hMinInterpRatio) != -1.0 )
	{
		flLerpRatio = clamp( flLerpRatio, GetConVarFloat(hMinInterpRatio), GetConVarFloat(hMaxInterpRatio) );
	}
	else
	{
		/*if ( flLerpRatio == 0 )
			flLerpRatio = 1.0;*/
	}
	lerpTime = MAX( flLerpAmount, flLerpRatio / updateRate );
	/*}
	else
	{
		lerpTime = 0.0;
	}*/
	
#undef QUICKGETCVARVALUE
	return lerpTime;
}

stock Float:clamp(Float:yes, Float:low, Float:high)
{
	return yes > high ? high : (yes < low ? low : yes);
}
