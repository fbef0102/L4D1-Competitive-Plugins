#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

new Handle:OneShotSkeet;
new Handle:hCvarAnnounce;
new bool:g_bRoundEndAnnounce;
new bool:g_bShotCounted[MAXPLAYERS+1][MAXPLAYERS+1];
new bool:g_bIsPouncing[MAXPLAYERS+1];
new bool:g_bHasLandedPounce[MAXPLAYERS+1];
new String:datafilepath[256];
new timerDeath[MAXPLAYERS+1];
new Skeets[MAXPLAYERS+1];
new Kills[MAXPLAYERS+1];
new DeadStoped[MAXPLAYERS+1];
new g_iShotsDealt[MAXPLAYERS+1][MAXPLAYERS+1];
new g_damage[MAXPLAYERS+1][MAXPLAYERS+1];
new g_iDamageDealt[MAXPLAYERS+1][MAXPLAYERS+1];
new g_iLastHealth[MAXPLAYERS+1];
new g_iSurvivorLimit = 4;
new CvarAnnounce;
public Plugin:myinfo =
{
	name = "Skeet Announce Edition (Database)",
	description = "Announce dmg/skeet/frag/ds original from thrillkill/n0limit, fixed by JNC",
	author = "Autor: thrillkill - edited: JNC - improve: Harry",
	version = "2.0",
	url = "https://steamcommunity.com/id/AkemiHomuraGoddess/"
};
new String:g_sVocalize[41][] =
{
	"scenes/Biker/NiceShot01.vcd",
	"scenes/Biker/NiceShot02.vcd",
	"scenes/Biker/NiceShot03.vcd",
	"scenes/Biker/NiceShot04.vcd",
	"scenes/Biker/NiceShot07.vcd",
	"scenes/Biker/NiceShot08.vcd",
	"scenes/Biker/NiceShot09.vcd",
	"scenes/Biker/NiceShot10.vcd",
	"scenes/Manager/NiceShot01.vcd",
	"scenes/Manager/NiceShot02.vcd",
	"scenes/Manager/NiceShot03.vcd",
	"scenes/Manager/NiceShot04.vcd",
	"scenes/Manager/NiceShot05.vcd",
	"scenes/Manager/NiceShot07.vcd",
	"scenes/Manager/NiceShot08.vcd",
	"scenes/Manager/NiceShot09.vcd",
	"scenes/Manager/NiceShot10.vcd",
	"scenes/NamVet/NiceShot01.vcd",
	"scenes/NamVet/NiceShot02.vcd",
	"scenes/NamVet/NiceShot03.vcd",
	"scenes/NamVet/NiceShot04.vcd",
	"scenes/NamVet/NiceShot05.vcd",
	"scenes/NamVet/NiceShot06.vcd",
	"scenes/NamVet/NiceShot07.vcd",
	"scenes/NamVet/NiceShot08.vcd",
	"scenes/NamVet/NiceShot09.vcd",
	"scenes/NamVet/NiceShot13.vcd",
	"scenes/NamVet/NiceShot14.vcd",
	"scenes/TeenGirl/NiceShot01.vcd",
	"scenes/TeenGirl/NiceShot04.vcd",
	"scenes/TeenGirl/NiceShot05.vcd",
	"scenes/TeenGirl/NiceShot06.vcd",
	"scenes/TeenGirl/NiceShot07.vcd",
	"scenes/TeenGirl/NiceShot08.vcd",
	"scenes/TeenGirl/NiceShot11.vcd",
	"scenes/TeenGirl/NiceShot12.vcd",
	"scenes/TeenGirl/NiceShot13.vcd",
	"scenes/TeenGirl/NiceShot14.vcd",
	"scenes/TeenGirl/NiceShot15.vcd",
	"scenes/TeenGirl/NiceShot16.vcd",
	"scenes/TeenGirl/NiceShot17.vcd"
};

public OnPluginStart()
{
	OneShotSkeet = CreateConVar("skeet_announce_oneshot", "0", "Only count 'One Shot' skeet?", 262144, false, 0.0, false, 0.0);
	hCvarAnnounce = CreateConVar("top_skeetannounce", "1", "Announce skeet/shots in chatbox when someone skeets.", FCVAR_PLUGIN, true, 0.0);
	CvarAnnounce = GetConVarInt(hCvarAnnounce);
	HookConVarChange(hCvarAnnounce, ConVarChange_hCvarAnnounce);
	
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode:1);
	HookEvent("ability_use", Event_AbilityUse, EventHookMode:1);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode:1);
	HookEvent("round_start", Event_RoundStart, EventHookMode:1);
	HookEvent("round_end", Event_RoundEnd, EventHookMode:1);
	HookEvent("weapon_fire", weapon_fire, EventHookMode:1);
	HookEvent("player_bot_replace", Event_Replace, EventHookMode:1);
	HookEvent("bot_player_replace", Event_Replace, EventHookMode:1);
	HookEvent("player_shoved", Event_PlayerShoved, EventHookMode:1);
	HookEvent("lunge_pounce", Event_LungePounce, EventHookMode:1);
	BuildPath(PathType:0, datafilepath, 256, "data/%s", "skeet_database.txt");
	RegConsoleCmd("sm_skeets", Command_Stats, "Show your current statistics.", 0);
	RegConsoleCmd("sm_rank", Command_Rank, "Show your current rank.", 0);
	RegConsoleCmd("sm_top5", Command_Top, "Show TOP 5 players in statistics.", 0);
}
public ConVarChange_hCvarAnnounce(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	if (!StrEqual(oldValue, newValue))
		CvarAnnounce = StringToInt(newValue);
}
public Action:Command_Rank(client, args)
{
	ShowSkeetRank(client);
	return Plugin_Continue;
}

public Action:Command_Stats(client, args)
{
	PrintSkeetsToClient(client);
	return Plugin_Continue;
}

public Action:Command_Top(client, args)
{
	PrintTopSkeetersToClient(client);
	return Plugin_Continue;
}

public OnMapStart()
{
	PrecacheSound("player/orch_hit_Csharp_short.wav", true);
	ClearSkeetCounter();
}

public Action:Event_LungePounce(Handle:event, String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	g_bIsPouncing[attacker] = false;
	g_bHasLandedPounce[attacker] = true;
	return Plugin_Continue;
}

public Action:weapon_fire(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	for (new i=1;i <= MaxClients;++i)
	{
		g_bShotCounted[i][client] = false;
	}
	return Plugin_Continue;
}

public Action:Event_Replace(Handle:event, String:name[], bool:dontBroadcast)
{
	new player = GetClientOfUserId(GetEventInt(event, "player"));
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	Skeets[player] = 0;
	Skeets[bot] = 0;
	Kills[player] = 0;
	Kills[bot] = 0;
	return Plugin_Continue;
}

Vocalize(client)
{
	decl String:sTemp[64];
	GetEntPropString(client, PropType:1, "m_ModelName", sTemp, 64);
	new random;
	if (sTemp[1] == 'b')
	{
		random = GetRandomInt(0, 7);
		new entity = CreateEntityByName("instanced_scripted_scene", -1);
		DispatchKeyValue(entity, "SceneFile", g_sVocalize[random]);
		DispatchSpawn(entity);
		SetEntPropEnt(entity, PropType:1, "m_hOwner", client);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "Start", client, client, 0);
	}
	if (sTemp[1] == 'm')
	{
		random = GetRandomInt(8, 16);
	}
	if (sTemp[1] == 'n')
	{
		random = GetRandomInt(17, 27);
	}
	if (sTemp[1] == 't')
	{
		random = GetRandomInt(28, 40);
	}
}

public Action:Event_PlayerHurt(Handle:event, String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!victim || !IsClientInGame(victim))
	{
		return Plugin_Continue;
	}
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new damage = GetEventInt(event, "dmg_health");
	if (IsValidClient(attacker) && GetClientTeam(attacker) == 2)
	{
		if (IsPlayerHunter(victim))
		{
			if (!g_bShotCounted[victim][attacker])
			{
				g_iShotsDealt[victim][attacker]++;
				g_bShotCounted[victim][attacker] = true;
			}
			new remaining_health = GetEventInt(event, "health");
			if (0 >= remaining_health)
			{
				return Plugin_Continue;
			}
			g_iLastHealth[victim] = remaining_health;
			g_iDamageDealt[victim][attacker] += damage;
		}
	}
	return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:event, String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!victim || !IsClientInGame(victim))
	{
		return Plugin_Continue;
	}
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (!IsClientInGame(attacker) || !attacker)
	{
		if (GetClientTeam(victim) == 3)
		{
			ClearDamage(victim);
		}
		return Plugin_Continue;
	}
	if (GetClientTeam(attacker) == 2 && GetClientTeam(victim) == 3)
	{
		new zombieclass = GetEntProp(victim, PropType:0, "m_zombieClass", 4);
		if (zombieclass == 5)
		{
			return Plugin_Continue;
		}
		new lasthealth = g_iLastHealth[victim];
		g_iDamageDealt[victim][attacker] += lasthealth ;
		if (zombieclass == 3 && g_bIsPouncing[victim] == true)
		{
			decl assisters[g_iSurvivorLimit][2];
			new assister_count;
			new shots = g_iShotsDealt[victim][attacker];
			for (new i=1;i <= MaxClients;++i)
			{
				if (!(attacker == i))
				{
					if (g_iDamageDealt[victim][i] > 0 && IsClientInGame(i))
					{
						assisters[assister_count][0] = i;
						assisters[assister_count][1] = g_iDamageDealt[victim][i];
						assister_count++;
					}
				}
			}
			if (assister_count)
			{
			}
			else
			{
				if (!IsFakeClient(victim))
				{
					if (!IsFakeClient(attacker))
					{
						new mode = GetConVarInt(OneShotSkeet);
						if (mode == 1)
						{
							if (shots == 1)
							{
								Statistic(attacker);
								PrintTopSkeeters();
								Skeeted(attacker);
								Vocalize(attacker);
								Skeets[attacker]++;
								Kills[attacker]++;
							}
						}
						else
						{
							Statistic(attacker);
							PrintTopSkeeters();
							Skeeted(attacker);
							Vocalize(attacker);
							Skeets[attacker]++;
							Kills[attacker]++;
						}
						if (shots == 1)
						{
							if(CvarAnnounce == 1)
							{
								PrintToChatAll("\x01[\x04SM\x01] %N skeeted %N in 1 shot.", attacker, victim);
							}
						}
						else
						{
							if(CvarAnnounce == 1)
							{
								PrintToChatAll("\x01[\x04SM\x01] %N skeeted %N in %i shots.", attacker, victim,shots);
							}
						}
					}
				}
			}
		}
		else
		{
			Kills[attacker]++;
		}
	}
	if (GetClientTeam(victim) == 3)
	{
		ClearDamage(victim);
	}
	return Plugin_Continue;
}

public Action:Event_AbilityUse(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsClientInGame(client) && IsPlayerHunter(client))
	{
		g_bIsPouncing[client] = true;
		CreateTimer(0.1, Timer_GroundedCheck, client, 1);
	}
	return Plugin_Continue;
}

public Action:Timer_GroundedCheck(Handle:timer, any:client)
{
	if ((isClient(client) && IsGrounded(client)) || !IsValidAliveClient(client))
	{
		g_bIsPouncing[client] = false;
		remove_damage(client);
		KillTimer(timer, false);
	}
	return Plugin_Continue;
}

public Action:Event_PlayerShoved(Handle:event, String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!victim || !IsClientInGame(victim))
	{
		return Plugin_Continue;
	}
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
	{
		return Plugin_Continue;
	}
	new zombieclass = GetEntProp(victim, PropType:0, "m_zombieClass", 4);
	if (zombieclass == 3 && g_bIsPouncing[victim])
	{
		if (IsFakeClient(victim))
		{
			return Plugin_Continue;
		}
		g_bIsPouncing[victim] = false;
		g_bHasLandedPounce[attacker] = false;
		new Handle:pack;
		CreateDataTimer(0.2, Timer_DeadstopCheck, pack, 0);
		WritePackCell(pack, attacker);
		WritePackCell(pack, victim);
	}
	return Plugin_Continue;
}

public Action:Timer_DeadstopCheck(Handle:timer, Handle:pack)
{
	ResetPack(pack, false);
	new attacker = ReadPackCell(pack);
	if (!g_bHasLandedPounce[attacker])
	{
		new victim = ReadPackCell(pack);
		if (!IsFakeClient(victim))
		{
			if (IsClientInGame(victim) && IsClientInGame(attacker))
			{
				DeadStoped[attacker]++;
				if (!IsFakeClient(attacker))
				{
					if(CvarAnnounce == 1)
					{
						PrintToChat(attacker, "\x01[\x04SM\x01] \x03You \x01DeadStoped \x04%N", victim);
					}
				}
				if (!IsFakeClient(victim))
				{
					if(CvarAnnounce == 1)
					{
						PrintToChat(victim, "\x01[\x04SM\x01] \x03You \x01were deadstopped by \x04%N", attacker);
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

remove_damage(client)
{
	for (new i=1;GetMaxClients() >= i;++i)
	{
		g_damage[client][i] = 0;
	}
}

bool:IsGrounded(client)
{
	return GetEntProp(client, PropType:1, "m_fFlags", 4) & 1 > 0;
}

Statistic(client)
{
	new String:clientname[32];
	GetClientName(client, clientname, 32);
	ReplaceString(clientname, 32, "'", "", true);
	ReplaceString(clientname, 32, "<", "", true);
	ReplaceString(clientname, 32, "{", "", true);
	ReplaceString(clientname, 32, "}", "", true);
	ReplaceString(clientname, 32, "\n", "", true);
	ReplaceString(clientname, 32, "\"", "", true);
	new String:clientauth[32];
	GetClientAuthString(client, clientauth, 32);
	new Handle:Data = CreateKeyValues("skeetdata", "", "");
	new count;
	new skeet;
	FileToKeyValues(Data, datafilepath);
	KvJumpToKey(Data, "data", true);
	if (!KvJumpToKey(Data, clientauth, false))
	{
		KvGoBack(Data);
		KvJumpToKey(Data, "info", true);
		count = KvGetNum(Data, "count", 0);
		count++;
		KvSetNum(Data, "count", count);
		KvGoBack(Data);
		KvJumpToKey(Data, "data", true);
		KvJumpToKey(Data, clientauth, true);
	}
	skeet = KvGetNum(Data, "skeet", 0);
	skeet++;
	KvSetNum(Data, "skeet", skeet);
	KvSetString(Data, "name", clientname);
	KvRewind(Data);
	KeyValuesToFile(Data, datafilepath);
	CloseHandle(Data);
	if(CvarAnnounce == 1)
	{
		PrintToChat(client, "\x01[\x04SM\x01] \x03You \x04have \x01%d skeets", skeet);
	}
}

ClearDamage(client)
{
	for (new i=1;i <= MaxClients;++i)
	{
		g_iDamageDealt[client][i] = 0;
		g_iShotsDealt[client][i] = 0;
	}
}

bool:IsValidClient(client)
{
	if (client < 1 || client > MaxClients)
	{
		return false;
	}
	if (!IsValidEntity(client))
	{
		return false;
	}
	return true;
}

ClearSkeetCounter()
{
	for (new i=1;i <= MaxClients;++i)
	{
		Skeets[i] = 0;
		Kills[i] = 0;
		DeadStoped[i] = 0;
	}
}

public Action:Event_RoundEnd(Handle:hEvent, String:strName[], bool:DontBroadcast)
{
	for (new i=1;i <= MaxClients;++i)
	{
		ClearDamage(i);
	}
	if (!g_bRoundEndAnnounce)
	{
		if(CvarAnnounce == 1)
			PrintStats();
		g_bRoundEndAnnounce = true;
	}
	return Plugin_Continue;
}

PrintStats()
{
	new survivor_index = -1;
	new survivor_clients[8];
	new client;
	for (client=1;client <= MaxClients;++client)
	{
		if (!IsClientInGame(client) || GetClientTeam(client) == 2 || IsFakeClient(client))
		{
		}
		else
		{
			survivor_index++;
			survivor_clients[survivor_index] = client;
		}
	}
	SortCustom1D(survivor_clients, 8, SortByDamageDesc, Handle:0);
	PrintToChatAll("\x01------------------------------");
	decl frags;
	decl skeetscount;
	decl shoved;
	for (new i=0;i <= survivor_index;++i)
	{
		client = survivor_clients[i];
		frags = Kills[client];
		skeetscount = Skeets[client];
		shoved = DeadStoped[client];
		PrintToChatAll("\x04%N \x03(Frags: \x01%i \x03| Skeets: \x01%i \x03| Deadstops: \x01%i\x03)", client, frags, skeetscount, shoved);
	}
	PrintToChatAll("\x01------------------------------");
}

public SortByDamageDesc(elem1, elem2, array[], Handle:hndl)
{
	if (Kills[elem1] > Kills[elem2])
	{
		return -1;
	}
	if (Kills[elem2] > Kills[elem1])
	{
		return 1;
	}
	if (elem1 > elem2)
	{
		return -1;
	}
	if (elem2 > elem1)
	{
		return 1;
	}
	return 0;
}

public Action:Event_RoundStart(Handle:hEvent, String:strName[], bool:DontBroadcast)
{
	ClearSkeetCounter();
	g_bRoundEndAnnounce = false;
	return Plugin_Continue;
}

Skeeted(client)
{
	CreateTimer(0.1, Award, client, 2);
	timerDeath[client] = 200;
}

public Action:Award(Handle:timer, any:client)
{
	if (client < any:0 && !IsClientInGame(client))
	{
		return Action:4;
	}
	timerDeath[client] += -20;
	if (timerDeath[client] > 101)
	{
		EmitSoundToAll("player/orch_hit_Csharp_short.wav", client, 3, 140, 0, 1.0, timerDeath[client], -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		switch (timerDeath[client])
		{
			case 120:
			{
				CreateTimer(1.1, Award, client, 2);
			}
			case 140:
			{
				CreateTimer(0.8, Award, client, 2);
			}
			case 160:
			{
				CreateTimer(0.5, Award, client, 2);
			}
			case 180:
			{
				CreateTimer(0.3, Award, client, 2);
			}
			default:
			{
				CreateTimer(1.3, Award, client, 2);
			}
		}
	}
	return Action:4;
}

bool:IsPlayerHunter(client)
{
	if (GetEntProp(client, PropType:0, "m_zombieClass", 4) == 3)
	{
		return true;
	}
	return false;
}

bool:IsValidAliveClient(client)
{
	if (client <= 0)
	{
		return false;
	}
	if (client > MaxClients)
	{
		return false;
	}
	if (!IsClientInGame(client))
	{
		return false;
	}
	if (!IsPlayerAlive(client))
	{
		return false;
	}
	return true;
}

public bool:isClient(client)
{
	return IsClientConnected(client) && IsClientInGame(client);
}

public bool:isAcceptableWeapon(String:weapon[])
{
	if (StrEqual(weapon, "weapon_autoshotgun", true) || StrEqual(weapon, "weapon_pumpshotgun", true) || StrEqual(weapon, "weapon_smg", true) || StrEqual(weapon, "weapon_rifle", true) || StrEqual(weapon, "weapon_hunting_rifle", true) || StrEqual(weapon, "weapon_pistol", true))
	{
		return true;
	}
	return false;
}

public Action:Command_Say(client, args)
{
	if (args < 1)
	{
		return Plugin_Continue;
	}
	decl String:text[16];
	GetCmdArg(1, text, 15);
	if (StrContains(text, "!skeets", true))
	{
		if (StrContains(text, "/skeets", true))
		{
			if (StrContains(text, "!top10", true))
			{
				if (StrContains(text, "!rank", true))
				{
					return Plugin_Continue;
				}
				ShowSkeetRank(client);
				return Plugin_Continue;
			}
			PrintTopSkeetersToClient(client);
			return Plugin_Continue;
		}
		PrintSkeetsToClient(client);
		return Plugin_Continue;
	}
	PrintSkeetsToClient(client);
	return Plugin_Continue;
}

PrintTopSkeetersToClient(client)
{
	if (!IsDedicatedServer())
	{
		if (!client)
		{
			client = 1;
		}
	}
	new Handle:Data = CreateKeyValues("skeetdata", "", "");
	new count;
	if (!FileToKeyValues(Data, datafilepath))
	{
		return;
	}
	KvJumpToKey(Data, "info", false);
	count = KvGetNum(Data, "count", 0);
	new String:names[count][32];
	new skeets[count][2];
	new totalskeets=0;
	KvGoBack(Data);
	KvJumpToKey(Data, "data", false);
	KvGotoFirstSubKey(Data, true);
	for (new i=0;i<count;++i)
	{
		KvGetString(Data, "name", names[i], 32, "Unnamed");
		skeets[i][0] = i;
		skeets[i][1] = KvGetNum(Data, "skeet", 0);
		totalskeets += skeets[i][1];
		KvGotoNextKey(Data, true);
	}
	CloseHandle(Data);
	SortCustom2D(skeets, count, Sort_Function, Handle:0);
	new Handle:Panel = CreatePanel(Handle:0);
	new oneshot = GetConVarInt(OneShotSkeet);
	if (oneshot == 1)
	{
		SetPanelTitle(Panel, "            5 Best One Shot Skeeters            ", false);
	}
	else
	{
		SetPanelTitle(Panel, "            Top 5 Skeeters                     ", false);
	}
	DrawPanelText(Panel, "\n ");
	new String:text[256];
	if (totalskeets)
	{
		if (count > 5)
		{
			count = 5;
		}
		for (new i=0;i<count;++i)
		{
			Format(text, 255, "%d skeets - %s", skeets[i][1], names[skeets[i][0]]);
			DrawPanelItem(Panel, text);
		}
		DrawPanelText(Panel, "\n ");
		Format(text, 255, "Total %d skeets on the server.", totalskeets);
		DrawPanelText(Panel, text);
	}
	else
	{
		Format(text, 255, "There are no skeets on this server yet.");
	}
	SendPanelToClient(Panel, client, TopSkeetPanelHandler, 5);
	CloseHandle(Panel);
	return;
}

PrintTopSkeeters()
{
	new Handle:Data = CreateKeyValues("skeetdata", "", "");
	new count;
	if (!FileToKeyValues(Data, datafilepath))
	{
		return;
	}
	KvJumpToKey(Data, "info", false);
	count = KvGetNum(Data, "count", 0);
	new String:names[count][32];
	new skeets[count][2];
	new totalskeets=0;
	KvGoBack(Data);
	KvJumpToKey(Data, "data", false);
	KvGotoFirstSubKey(Data, true);
	for (new i=0;i<count;++i)
	{
		KvGetString(Data, "name", names[i], 32, "Unnamed");
		skeets[i][0] = i;
		skeets[i][1] = KvGetNum(Data, "skeet", 0);
		totalskeets += skeets[i][1];
		KvGotoNextKey(Data, true);
	}
	CloseHandle(Data);
	SortCustom2D(skeets, count, Sort_Function, Handle:0);
	new Handle:Panel = CreatePanel(Handle:0);
	new oneshot = GetConVarInt(OneShotSkeet);
	if (oneshot == 1)
	{
		SetPanelTitle(Panel, "            5 Best One Shot skeeters            ", false);
	}
	else
	{
		SetPanelTitle(Panel, "            Top 5 Skeeters                     ", false);
	}
	DrawPanelText(Panel, "\n ");
	new String:text[256];
	if (totalskeets)
	{
		if (count > 5)
		{
			count = 5;
		}
		for (new i=0;i<count;++i)
		{
			Format(text, 255, "%d skeets - %s", skeets[i][1], names[skeets[i][0]]);
			DrawPanelItem(Panel, text);
		}
		DrawPanelText(Panel, "\n ");
		Format(text, 255, "Total %d skeets on the server.", totalskeets);
		DrawPanelText(Panel, text);
	}
	else
	{
		Format(text, 255, "There are no skeets on this server yet.");
	}
	for (new i=1;i<=MaxClients;++i)
	{	
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			SendPanelToClient(Panel, i, TopSkeetPanelHandler, 5);
		}
	}
	CloseHandle(Panel);
	return;
}

PrintSkeetsToClient(client)
{
	if (!IsDedicatedServer())
	{
		if (!client)
		{
			client = 1;
		}
	}
	new Handle:Data = CreateKeyValues("skeetdata", "", "");
	new skeet;
	if (!FileToKeyValues(Data, datafilepath))
	{
		PrintToChat(client, "\x03There is no \x01data.");
		return;
	}
	new String:auth[32];
	GetClientAuthString(client, auth, 32);
	KvJumpToKey(Data, "data", false);
	KvJumpToKey(Data, auth, false);
	skeet = KvGetNum(Data, "skeet", 0);
	CloseHandle(Data);
	if (skeet == 1)
	{
		PrintToChat(client, "\x04You \x03only \x011 skeet.");
	}
	if (skeet < 1)
	{
		PrintToChat(client, "\x03You \x01don't have skeets.");
	}
	else
	{
		PrintToChat(client, "\x04You \x03have \x01%d skeets.", skeet);
	}
	return;
}

ShowSkeetRank(client)
{
	if (!IsDedicatedServer())
	{
		if (!client)
		{
			client = 1;
		}
	}
	new Handle:Data = CreateKeyValues("skeetdata", "", "");
	new count;
	if (!FileToKeyValues(Data, datafilepath))
	{
		return;
	}
	KvJumpToKey(Data, "info", false);
	count = KvGetNum(Data, "count", 0);
	KvGoBack(Data);
	KvJumpToKey(Data, "data", false);
	new skeet;
	new String:auth[32];
	GetClientAuthString(client, auth, 32);
	if (KvJumpToKey(Data, auth, false))
	{
		skeet = KvGetNum(Data, "skeet", 0);
	}
	else
	{
		skeet = 0;
	}
	new place = TopTo(skeet);
	PrintToChat(client, "Skeet Ranking: %d/%d", place, count);
	CloseHandle(Data);
	return;
}

TopTo(skeeti)
{
	new Handle:Data = CreateKeyValues("skeetdata", "", "");
	new count;
	if (!FileToKeyValues(Data, datafilepath))
	{
		return 0;
	}
	KvJumpToKey(Data, "info", false);
	count = KvGetNum(Data, "count", 0);
	new skeet[count];
	KvGoBack(Data);
	KvJumpToKey(Data, "data", false);
	KvGotoFirstSubKey(Data, true);
	new total;
	for (new i=0;i < count;++i)
	{
		skeet[i] = KvGetNum(Data, "skeet", 0);
		if (skeet[i] >= skeeti)
		{
			total++;
		}
		KvGotoNextKey(Data, true);
	}
	CloseHandle(Data);
	return total;
}

public Sort_Function(array1[], array2[], completearray[][], Handle:hndl)
{
	if (array1[1] > array2[1])
	{
		return -1;
	}
	if (array1[1] == array2[1])
	{
		return 0;
	}
	return 1;
}

public TopSkeetPanelHandler(Handle:menu, MenuAction:action, param1, param2)
{
	return 0;
}

