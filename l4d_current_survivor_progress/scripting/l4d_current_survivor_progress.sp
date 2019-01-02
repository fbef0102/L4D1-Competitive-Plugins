#pragma semicolon 1

#include <sourcemod>
#include <l4d_direct>
#include <colors>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

new Handle:g_hVsBossBuffer;
new SurCurrent = 0;

public Plugin:myinfo =
{
    name = "L4D1 Survivor Progress",
    author = "CanadaRox, Visor, L4D1 port by harry",
    description = "Print survivor progress in flow percents ",
    version = "2.2",
    url = "https://github.com/Attano/ProMod"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("GetSurCurrent",Native_SurCurrent);
	return APLRes_Success;
}

public Native_SurCurrent(Handle:plugin, numParams) {
	SurCurrent = RoundToNearest(GetBossProximity() * 100.0);
	return SurCurrent;
}


public OnPluginStart()
{
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");

	RegConsoleCmd("sm_cur", CurrentCmd);
	RegConsoleCmd("sm_current", CurrentCmd);
	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", LeftStartAreaEvent, EventHookMode_PostNoCopy);
}
public RoundStartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(5.0, SaveSurCurrent);
}

public Action:SaveSurCurrent(Handle:timer)
{
	SurCurrent = RoundToNearest(GetBossProximity() * 100.0);
}

public LeftStartAreaEvent(Handle:event, String:name[], bool:dontBroadcast)
{
	CPrintToChatAll("{default}[{olive}TS{default}] {blue}Current{default}: {green}%d%%", SurCurrent);
}

public Action:CurrentCmd(client, args)
{
	SurCurrent = RoundToNearest(GetBossProximity() * 100.0);
	SurCurrent = SurCurrent>=100 ? 100 : SurCurrent;
	new iTeam = GetClientTeam(client);
	for (new i = 1; i < MaxClients+1; i++) {//打這指令的整隊都看得到
		if (IsClientConnected(i) && IsClientInGame(i)&& GetClientTeam(i) == iTeam) 
			CPrintToChat(i, "{default}[{olive}TS{default}] {blue}Current{default}: {green}%d%%{default}", SurCurrent);
	}
	
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
