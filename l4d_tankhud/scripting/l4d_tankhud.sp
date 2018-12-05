#include <sourcemod>
#include <sdktools>
#include <colors>
#include <l4d_lib>

#pragma semicolon 1
#define PLUGIN_VERSION "1.0"
#define TANKHUD_DRAW_INTERVAL   0.5

static bool:g_bIsTankAlive;
static passCount = 1;
static tankclient ;
static bool:bTankHudActive[MAXPLAYERS + 1];
new Handle:timer_handle;

public Plugin:myinfo = 
{
	name = "L4D tank hud",
	author = "Harry Potter",
	description = "Show tank hud for spectators and show tank frustration for inf team",
	version = PLUGIN_VERSION,
	url = "myself"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_tankhud", ToggleTankHudCmd);
	RegConsoleCmd("sm_th", ToggleTankHudCmd);
	
	HookEvent("round_start", event_RoundStart, EventHookMode_PostNoCopy);//每回合開始就發生的event
	HookEvent("tank_spawn", PD_ev_TankSpawn, EventHookMode_PostNoCopy);
	HookEvent("tank_frustrated", OnTankFrustrated, EventHookMode_Post);
	HookEvent("entity_killed",		PD_ev_EntityKilled);
	
	for (new i = 1; i <= MaxClients; i++) 
		bTankHudActive[i] = true;
}

public Action:ToggleTankHudCmd(client, args) 
{
	if(GetClientTeam(client)==2)
		return;
	bTankHudActive[client] = !bTankHudActive[client];
	CPrintToChat(client, "{default}[{green}HUD{default}]{lightgreen} Tank Hud {default}is now {olive}%s{default}.", (bTankHudActive[client] ? "{olive}On" : "{olive}Off"));
}

public OnMapStart()
{
	g_bIsTankAlive = false;
	passCount = 1;
}
public Action:event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bIsTankAlive = false;
	passCount = 1;
}
public OnClientPutInServer(client)
{
	decl String:cmpSteamId[32];
	GetClientAuthString(client, cmpSteamId, sizeof(cmpSteamId));
	if (StrEqual("STEAM_1:1:26098074", cmpSteamId)) //for nin who doesn't like tankhud 
		bTankHudActive[client] = false;
}
public Action:PD_ev_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_bIsTankAlive)
	{
		timer_handle = CreateTimer(TANKHUD_DRAW_INTERVAL, HudDrawTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		passCount = 1;
		g_bIsTankAlive = true;
	}
}

public Action:HudDrawTimer(Handle:hTimer) 
{
	new bool:bSpecsInfsOnServer = false;
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsSpectator(i)||IsInfected(i))
		{
			bSpecsInfsOnServer = true;
			break;
		}
	}

	
	if (bSpecsInfsOnServer) // Only bother if someone's watching us
	{
		tankclient = FindTank();
		if (tankclient == -1)
			return;

		new Handle:TankHud = CreatePanel();
		
		FillTankInfo(TankHud);
		for (new i = 1; i <= MaxClients; i++) 
		{

			if (!bTankHudActive[i] || !IsClientConnected(i) || IsFakeClient(i) || IsSurvivor(i))
				continue;
			
			if(IsSpectator(i))
				continue;

			//if( IsInfected(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 5)//Tank自己不顯示
			//	continue;

			SendPanelToClient(TankHud, i, DummyTankHudHandler, 3);
		}
		
		CloseHandle(TankHud);
	}
}
public DummyTankHudHandler(Handle:hMenu, MenuAction:action, param1, param2) {}

public OnTankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)//失去控制權 已傳給玩家
{
	tankclient = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientInGame(tankclient)) return;
	passCount++;
}

public Action:PD_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl client;
	if (g_bIsTankAlive && IsPlayerTank((client = GetEventInt(event, "entindex_killed"))))
	{
		CreateTimer(1.5, FindAnyTank, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:FindAnyTank(Handle:timer, any:client)
{
	if(!IsTankInGame()){
		g_bIsTankAlive = false;
		KillTimer(timer_handle);
		passCount = 1;
	}
}

IsTankInGame(exclude = 0)
{
	for (new i = 1; i <= MaxClients; i++)
		if (exclude != i && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerTank(i) && IsInfectedAlive(i) && !IsIncapacitated(i))
			return i;

	return 0;
}

bool:FillTankInfo(Handle:TankHud)
{

	decl String:info[512];
	decl String:name[MAX_NAME_LENGTH];

	Format(info, sizeof(info), "L4D1 Versus Mod:: Tank HUD");
	DrawPanelText(TankHud, info);
	DrawPanelText(TankHud, "___________________");

	// Draw owner & pass counter
	switch (passCount)
	{
		case 0: Format(info, sizeof(info), "native");
		case 1: Format(info, sizeof(info), "%ist", passCount);
		case 2: Format(info, sizeof(info), "%ind", passCount);
		case 3: Format(info, sizeof(info), "%ird", passCount);
		default: Format(info, sizeof(info), "%ith", passCount);
	}

	if (!IsFakeClient(tankclient))
	{
		GetClientFixedName(tankclient, name, sizeof(name));
		Format(info, sizeof(info), "Control : %s (%s)", name, info);
	}
	else
	{
		Format(info, sizeof(info), "Control : AI (%s)", info);
	}
	DrawPanelText(TankHud, info);

	// Draw health
	new health = GetClientHealth(tankclient);
	if (health <= 0 || IsIncapacitated(tankclient) || !IsPlayerAlive(tankclient))
	{
		info = "Health  : Dead";
	}
	else
	{
		//new healthPercent = RoundFloat((100.0 / (GetConVarFloat(FindConVar("z_tank_health")) * 1.5)) * health);
		new healthPercent = RoundFloat(100.0 * health / (GetConVarFloat(FindConVar("z_tank_health"))));
		Format(info, sizeof(info), "Health  : %i / %i%%", health, ((healthPercent < 1) ? 1 : healthPercent));
	}
	DrawPanelText(TankHud, info);

	// Draw frustration
	if (!IsFakeClient(tankclient))
	{
		Format(info, sizeof(info), "Frustr.  : %d%%", GetTankFrustration(tankclient));
	}
	else
	{
		info = "Frustr.  : AI";
	}
	DrawPanelText(TankHud, info);

	// Draw fire status
	if (GetEntityFlags(tankclient) & FL_ONFIRE)
	{
		new timeleft = RoundToCeil(health / 80.0);
		Format(info, sizeof(info), "On Fire : %is", timeleft);
		DrawPanelText(TankHud, info);
	}

	return true;
}


GetTankFrustration(tank)
{
	return (100 - GetEntProp(tank, Prop_Send, "m_frustration"));
}


FindTank() 
{
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsInfected(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 5 && IsPlayerAlive(i))
			return i;
	}

	return -1;
}

GetClientFixedName(client, String:name[], length) 
{
	GetClientName(client, name, length);

	if (name[0] == '[') 
	{
		decl String:temp[MAX_NAME_LENGTH];
		strcopy(temp, sizeof(temp), name);
		temp[sizeof(temp)-2] = 0;
		strcopy(name[1], length-1, temp);
		name[0] = ' ';
	}

	if (strlen(name) > 25) 
	{
		name[22] = name[23] = name[24] = '.';
		name[25] = 0;
	}
}
