#define PLUGIN_VERSION "1.4"

#pragma semicolon 1

#include <sourcemod>
#include <left4downtown>
#undef REQUIRE_PLUGIN
#include <l4d_lib>
#define IN_ATTACK3		(1 << 25)
public Plugin:myinfo =
{
	name = "[L4D] Tank Attack Control",
	author = "vintik, raziEiL [disawar1], Harry Potter",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
}

enum Seq
{
	Null = 0,
	UpperHook = 38,
	RightHook = 41,
	LeftHook = 43,
	Throw = 46,
	OneOverhand, //47 - 1handed overhand (MOUSE2)
	Underhand, //48 - underhand (E)
	TwoOverhand //49 - 2handed overhand (R)
}

static		g_iCvarPunchControl, Float:g_fCvarPunchDelay, Float:g_fCvarThrowDelay, bool:g_bTankInGame, Seq:g_seqQueuedThrow[MAXPLAYERS+1],
			bool:g_bPunchBlock[MAXPLAYERS+1], bool:g_bThrowBlock[MAXPLAYERS+1];
static		bool:g_bCvar1v1Mode;

public OnPluginStart()
{
	new Handle:hCvarSurvLimit			= FindConVar("survivor_limit");
	new Handle:hCvarPunchDelay = FindConVar("z_tank_attack_interval");
	new Handle:hCvarThrowDelay = FindConVar("z_tank_throw_interval");

	new Handle:hCvarPunchControl = CreateConVar("tank_attack_punch_control", "0", "0: valve animation, 1: remove random MOUSE1 punches and bind them to MOUSE1+E/R buttons, 2: remove but dont bind.", _, true, 0.0, true, 2.0);

	g_iCvarPunchControl = GetConVarInt(hCvarPunchControl);
	g_fCvarPunchDelay = GetConVarFloat(hCvarPunchDelay);
	g_fCvarThrowDelay = GetConVarFloat(hCvarThrowDelay);
	g_bCvar1v1Mode	= GetConVarInt(hCvarSurvLimit) == 1 ? true : false;	
	
	HookConVarChange(hCvarPunchControl, TAC_OnPunchCvarChange);
	HookConVarChange(hCvarPunchDelay, TAC_OnPunchDelayCvarChange);
	HookConVarChange(hCvarThrowDelay, TAC_OnThrowDealyCvarChange);

	HookEvent("tank_spawn", TAC_ev_TankSpawn, EventHookMode_PostNoCopy);
	HookEvent("round_start", TAC_ev_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("entity_killed", TAC_ev_EntityKilled);
	HookEvent("tank_frustrated",		PD_ev_TankFrustrated);
}

public TAC_OnPunchCvarChange(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	g_iCvarPunchControl = GetConVarInt(convar_hndl);
}

public TAC_OnPunchDelayCvarChange(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	g_fCvarPunchDelay = GetConVarFloat(convar_hndl);
}

public TAC_OnThrowDealyCvarChange(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	g_fCvarThrowDelay = GetConVarFloat(convar_hndl);
}

public Action:TAC_ev_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bTankInGame)
		CreateTimer(10.0, TAC_t_Instruction);

	g_bTankInGame = true;
}

public Action:TAC_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bTankInGame = false;
}

public Action:TAC_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bTankInGame && IsPlayerTank(GetEventInt(event, "entindex_killed")))
		CreateTimer(4.0, TAC_t_FindAnyTank, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:TAC_t_FindAnyTank(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsInfectedAlive(i) && IsPlayerTank(i) && !IsIncapacitated(i))
			return;

	g_bTankInGame = false;
}

public Action:PD_ev_TankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bCvar1v1Mode){		
		CreateTimer(1.0,COLD_DOWN);
	}
}

public Action:COLD_DOWN(Handle:timer)
{
	g_bTankInGame = false;
}

FindTank() 
{
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i)&&IsInfected(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 5 && IsPlayerAlive(i))
			return i;
	}

	return -1;
}

public Action:TAC_t_Instruction(Handle:timer)
{
	new i = FindTank();
	if(i == -1)
		return;
	if (g_iCvarPunchControl == 1){
		//PrintToChat(i,"\n\x01[\x04拳頭\x01] (\x05MOUSE1\x01) right hook\n(\x05E+MOUSE1\x01) left hook\n(\x05R+MOUSE1\x01) uppercut");
		//PrintToChat(i,"\n\x01[\x04拳頭\x01] (\x05MOUSE1\x01) 右鉤拳\n(\x05E+MOUSE1\x01) 左鉤拳\n(\x05R+MOUSE1\x01) 上鉤拳");
		//PrintToChat(i,"\x01[\x04石頭\x01] (\x05MOUSE2\x01) one handed overhand\n(\x05E+MOUSE2\x01) underhand\n(\x05R+MOUSE2\x01) two handed overhand");
		//PrintToChat(i,"\x01[\x04石頭\x01] (\x05MOUSE2\x01) 一手丟石\n(\x05E+MOUSE2\x01) 落阱下石\n(\x05R+MOUSE2\x01) 兩手過頭");
		return;
	}
	else
		PrintToChat(i,"\x01[\x04石頭變化\x01] (\x05MOUSE2\x01) 一飛衝天\n(\x05E\x01) 落井下石\n(\x05R\x01) 兩手遮天");
}

public Action:OnPlayerRunCmd(client, &buttons)
{
	if (!g_bTankInGame || !buttons || GetClientTeam(client) != 3 || IsFakeClient(client) || !IsPlayerTank(client) || !IsInfectedAlive(client))
		return Plugin_Continue;
	
	if (!g_bThrowBlock[client]){
		if(buttons & IN_ATTACK2)
		{
			g_seqQueuedThrow[client] = OneOverhand;
		}
		else if (buttons & IN_USE)
		{
			g_seqQueuedThrow[client] = Underhand;
			buttons |= IN_ATTACK2;
		}
		else if (buttons & IN_RELOAD)
		{
			g_seqQueuedThrow[client] = TwoOverhand;
			buttons |= IN_ATTACK2;
		}
	}
	else if (g_iCvarPunchControl && (buttons & IN_ATTACK) && !g_bPunchBlock[client]){

		if (g_iCvarPunchControl == 1){

			if (buttons & IN_USE)
				g_seqQueuedThrow[client] = LeftHook;
			else if (buttons & IN_RELOAD)
				g_seqQueuedThrow[client] = UpperHook;
			else
				g_seqQueuedThrow[client] = RightHook;
		}
		else
			g_seqQueuedThrow[client] = RightHook;
	}	
	
	return Plugin_Continue;
}

public Action:L4D_OnSelectTankAttack(client, &sequence)
{
	if (g_seqQueuedThrow[client] != Null){

		if (sequence > _:Throw){ // throw

			if (g_seqQueuedThrow[client] > Throw){

				if (!g_bThrowBlock[client]){

					g_bThrowBlock[client] = true;
					CreateTimer(g_fCvarThrowDelay, TAC_t_UnlockThrowControl, client);
				}

				sequence = _:g_seqQueuedThrow[client];
				return Plugin_Handled;
			}
		}
		else if (g_iCvarPunchControl && g_seqQueuedThrow[client] < Throw){ // punch

			if (!g_bPunchBlock[client]){

				g_bPunchBlock[client] = true;
				CreateTimer(g_fCvarPunchDelay, TAC_t_UnlockPunchControl, client);
			}

			sequence = _:g_seqQueuedThrow[client];
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action:TAC_t_UnlockThrowControl(Handle:timer, any:client)
{
	g_bThrowBlock[client] = false;
}

public Action:TAC_t_UnlockPunchControl(Handle:timer, any:client)
{
	g_bPunchBlock[client] = false;
}
