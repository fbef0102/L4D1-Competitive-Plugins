/* L4D Competitive Stats
 * by Griffin & Philogl
*/

/* Notes
	mini reference
	L4D1 m_zombieClass:
		boomer = 2
		smoker = 1
		hunter = 3
		tank  = 5
		common = 0?
		witch = 4?
	infected_killed = common/witch kills

	The Visceral: most wallkicks in one life
	Africa Boomer: Longest distance walked after spawning to land a boom
	Miracle Shot: Longest shot fired to kill a hunter

	8/13/2012
	Colorize other messages
	Cvarize urrthing
	Maintain stats on disconnect
	Campaign totals (this is gon' be a bitch)
	g_bIsWitch -> g_iAccumulatedWitchDamage[MAXENTITIES] for witch tracking, 
	witch tracking timer to check if a witch has despawned, activate on startle event or whatever
	versus_round_restarttimer for final map print
	**fixed** HP / number of shots to skeet doesnt get reset when the SI gets killed by other SI/witch

another delay overall MVPs:
And the overall campaign MVPs are...
*drumroll*
philogl and Griffin!
MVP - Campaign: Philogl (50 common, 27% tank damage, 6 skeets (6 full/0 team), 2 FF)
MVP - Campaign: Griffin(50 common, 27% tank damage, 6 skeets (6 full/0 team), 2 FF)
*/


public Plugin:myinfo =
{
	name = "L4D Competitive Stats",
	author = "Griffin & Philogl, Harry Potter",
	description = "Basic competitive stat tracking on a per map basis, 特感殺手, 清屍狂人, Skeet, 黑槍之王, 推推小王子, 抖M受",
	version = "1.4"
};

#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include include/sdkhooks.inc

#define MAXENTITIES 2048
#define SAYTEXT_MAXLENGTH 192
#define HIGHCHAR "*"
#define LOWCHAR "_"
#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define FLAG_SPECTATOR (1 << TEAM_SPECTATOR)
#define FLAG_SURVIVOR (1 << TEAM_SURVIVOR)
#define FLAG_INFECTED (1 << TEAM_INFECTED)
#define SM_REPLY_TO_CHAT ReplySource:1
#define MIN_DP_RATIO 0.8 // % of maximum DP damage to consider a DP, maybe make this a cvar?
#define BOOMER_STAGGER_TIME 4.0 // Amount of time after a boomer has been meleed that we consider the meleer the person who
								// shut down the boomer, this is just a guess value...

#define GetModifierChar(%0,%1) (%0 == lows_highs[%1][1] ? HIGHCHAR:%0 == lows_highs[%1][0] ? LOWCHAR:"")
#define GetModifierCharReversed(%0,%1) (%0 == lows_highs[%1][0] ? HIGHCHAR:%0 == lows_highs[%1][1] ? LOWCHAR:"")
#define IsSpectator(%0) (GetClientTeam(%0) == TEAM_SPECTATOR)
#define IsSurvivor(%0) (GetClientTeam(%0) == TEAM_SURVIVOR)
#define IsInfected(%0) (GetClientTeam(%0) == TEAM_INFECTED)
#define IsWitch(%0) (g_bIsWitch[%0])
#define IsPouncing(%0) (g_bIsPouncing[%0])
#define IsIncapped(%0) (GetEntProp(%0, Prop_Send, "m_isIncapacitated") > 0)
#define IsBoomed(%0) ((GetEntPropFloat(%0, Prop_Send, "m_vomitStart") + 20.1) > GetGameTime())
//harry
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define ROCK_CHECK_TIME         0.34    // how long to wait after rock entity is destroyed before checking for skeet/eat (high to avoid lag issues)
#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
//harry end//
enum _:ZOMBIECLASS
{
	ZC_SMOKER = 1,
	ZC_BOOMER,
	ZC_HUNTER,
	ZC_WITCH,
	ZC_TANK
}

enum _:STATS
{
	FullSkeets,
	TeamSkeets,
	SkeetAssists,
	Deadstops,
	PouncesEaten,
	DPsEaten,
	CIKills,
	SIKills,
	FF,
	SIDamage,
	CIDamageTaken,
	SIDamageTaken,
	BoomerShutdowns,
	BoomAttempts,
	BoomSuccesses,
	BoomedSurvivorsByVomit,
	BoomedSurvivorsByProxy,
	PouncesLanded,
	DPsLanded,
	Skeeted,
	Deadstopped,
	DamageDealtAsSI,
	STATS_MAX
}

// Cvar related
//new				g_iMaxPlayerZombies							= 4;
new				g_iSurvivorLimit							= 4;
new				g_iMinDPDamage								= 10;
new				g_iWitchHealth								= 1000;	// Default
//new		Handle:	g_hCvarMaxPlayerZombies						= INVALID_HANDLE;
new		Handle:	g_hCvarSurvivorLimit						= INVALID_HANDLE;
new		Handle:	g_hCvarMaxPounceBonusDamage					= INVALID_HANDLE;
new		Handle:	g_hCvarWitchHealth							= INVALID_HANDLE;

// Global state
new		bool:	g_bShouldAnnounceWitchDamage				= false;
new		bool:	g_bHasRoundEnded							= false;
new		Handle:	g_hBoomerShoveTimer							= INVALID_HANDLE;

// Player/Entity state
new				g_iAccumulatedWitchDamage;							// Current witch health = witch health - accumulated
new				g_iBoomerClient;									// Client of last player to be boomer (or current boomer)
new				g_iBoomerKiller;									// Client who shot the boomer
new				g_iBoomerShover;									// Client who shoved the boomer
new				g_iLastHealth[MAXPLAYERS + 1];
new		bool:	g_bHasBoomLanded;
new		bool:	g_bStatsCooldown[MAXPLAYERS + 1];					// Prevent spam of stats command (potential DoS vector I think)
new		bool:	g_bHasLandedPounce[MAXPLAYERS + 1];					// Used to determine if a deadstop was 'pierced'
new		bool:	g_bIsWitch[MAXENTITIES];							// Membership testing for fast witch checking
new		bool:	g_bIsPouncing[MAXPLAYERS + 1];
new		bool:	g_bShotCounted[MAXPLAYERS + 1][MAXPLAYERS +1];		// Victim - Attacker, used by playerhurt and weaponfired

// Map Stats, array for each player for easy trie storage
new				g_iMapStats[MAXPLAYERS + 1][STATS_MAX];

// Player temp stats
new				g_iWitchDamage[MAXPLAYERS + 1];
new				g_iDamageDealt[MAXPLAYERS + 1][MAXPLAYERS + 1];			// Victim - Attacker
new				g_iShotsDealt[MAXPLAYERS + 1][MAXPLAYERS + 1];			// Victim - Attacker, count # of shots (not pellets)
new 	bool:	isroundreallyend;

//harry
native IsInReady();
new     Handle:         g_hTrieEntityCreated                                = INVALID_HANDLE;   // getting classname of entity created
// trie values: OnEntityCreated classname
enum strOEC
{
    OEC_WITCH,
    OEC_TANKROCK,
    OEC_TRIGGER,
    OEC_CARALARM,
    OEC_CARGLASS
};

// rocks
new                     g_iTankRock             [MAXPLAYERS + 1];                               // rock entity per tank
new                     g_iRocksBeingThrown     [10];                                           // 10 tanks max simultanously throwing rocks should be ok (this stores the tank client)
new                     g_iRocksBeingThrownCount                            = 0;                // so we can do a push/pop type check for who is throwing a created rock
enum strRockData
{
    rckDamage,
    rckTank,
    rckSkeeter
};

new     Handle:         g_hRockTrie                                         = INVALID_HANDLE;   // tank rock tracking
new     Handle:         g_hForwardRockSkeeted                               = INVALID_HANDLE;
new     Handle:         g_hForwardRockEaten                                 = INVALID_HANDLE;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
   g_hForwardRockSkeeted =     CreateGlobalForward("OnTankRockSkeeted", ET_Ignore, Param_Cell, Param_Cell );
   g_hForwardRockEaten =       CreateGlobalForward("OnTankRockEaten", ET_Ignore, Param_Cell, Param_Cell );
}
//harry end//
public OnPluginStart()
{
	if (GetMaxEntities() > MAXENTITIES)
	{
		LogError("Plugin needs to be recompiled with a new MAXENTITIES value of %d. Current value is %d. Witch tracking is unreliable!",
			GetMaxEntities(), MAXENTITIES);
	}

	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		SDKHook(client, SDKHook_OnTakeDamage, PlayerHook_OnTakeDamagePre);
	}

	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);

	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_shoved", Event_PlayerShoved);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("infected_death", Event_InfectedDeath);
	HookEvent("weapon_fire", Event_WeaponFire);
	// Witch tracking
	HookEvent("player_incapacitated", Event_PlayerIncapacitated);
	HookEvent("infected_hurt", Event_InfectedHurt);
	HookEvent("witch_killed", Event_WitchKilled);
	HookEvent("witch_spawn", Event_WitchSpawn);
	// Pounce tracking
	HookEvent("ability_use", Event_AbilityUse);
	HookEvent("lunge_pounce", Event_LungePounce);
	// Boomer tracking
	HookEvent("player_now_it", Event_PlayerBoomed);

	//g_hCvarMaxPlayerZombies = FindConVar("z_max_player_zombies");
	g_hCvarSurvivorLimit = FindConVar("survivor_limit");
	g_hCvarMaxPounceBonusDamage = FindConVar("z_hunter_max_pounce_bonus_damage");
	g_hCvarWitchHealth = FindConVar("z_witch_health");

	//HookConVarChange(g_hCvarMaxPlayerZombies, Cvar_MaxPlayerZombies);
	HookConVarChange(g_hCvarSurvivorLimit, Cvar_SurvivorLimit);
	HookConVarChange(g_hCvarMaxPounceBonusDamage, Cvar_MaxPounceBonusDamage);
	HookConVarChange(g_hCvarWitchHealth, Cvar_WitchHealth);

	//g_iMaxPlayerZombies = GetConVarInt(g_hCvarMaxPlayerZombies);
	g_iSurvivorLimit = GetConVarInt(g_hCvarSurvivorLimit);
	g_iWitchHealth = GetConVarInt(g_hCvarWitchHealth);
	CalculateMinDPDamage(GetConVarFloat(g_hCvarMaxPounceBonusDamage));

	// RegConsoleCmd("sm_stats", Command_Stats, "Prints the client's stats for the current round");
	
	RegConsoleCmd("mvp", Command_Mvp);
	
	//harry
	g_hTrieEntityCreated = CreateTrie();
	SetTrieValue(g_hTrieEntityCreated, "tank_rock", OEC_TANKROCK);
	g_hRockTrie = CreateTrie();
}
public Action:Command_Mvp(client, args)
{
	new iTeam = GetClientTeam(client);
	PrintMVPAndTeamStats(iTeam);
}
public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, PlayerHook_OnTakeDamagePre);
}

public OnMapStart()
{
	g_bHasRoundEnded = false;
	ClearMapStats();
	isroundreallyend = false;
}


public Action:Timer_DelayedStatsPrint(Handle:timer)
{
	PrintMVPAndTeamStats(0);
	//PrintConsoleStats();
}

/*
MVP - SI: Philogl (2932 dmg[99%], 53 kills [100%]) Your SI rank: #4 (3 dmg [1%], 0 kills [0%])
MVP - CI: Philogl (232 common [90%]) Your CI rank: #4 (1 kills [0%])
*/

public PrintMVPAndTeamStats(team)
{
	decl survivor_clients[g_iSurvivorLimit];
	decl i;
	new survivor_count = 0;
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsSurvivor(i)) continue;
		if(g_iSurvivorLimit > survivor_count)
			survivor_clients[survivor_count++] = i;
	}
	if(survivor_count == 0)
		return;
	decl sortable[survivor_count][2];
	decl client, val;
	new total, totalkills, percent;

	// --------------------------- SI Damage ---------------------------
	for (i = 0; i < survivor_count; i++)
	{
		client = survivor_clients[i];
		val = g_iMapStats[client][SIDamage];
		sortable[i][0] = client;
		sortable[i][1] = val;
		total += val;
		totalkills += g_iMapStats[client][SIKills];
	}
	if (total == 0 || totalkills == 0)
	{
		//CPrintToChatAll("{green}★{default} SI:{blue} N/A{default}");
	}
	else
	{
		SortCustom2D(sortable, survivor_count, ClientValue2DSortDesc);
		client = sortable[0][0];
		val = sortable[0][1];
		percent = RoundFloat((float(val) / float(total)) * 100.0);
		new kills = g_iMapStats[client][SIKills];
		// This string (colors, etc) is stolen wholesale from Tabun's L4D2 MVP plugin, credit to him
		if(team == 0)
			CPrintToChatAll("{green}★{default} SI:{blue} %N{default} ({olive}%d{default} dmg [{green}%d%%%%{default}], {olive}%d{default} kills [{green}%d%%%%{default}])",client, val, percent, kills,RoundFloat((float(kills) / float(totalkills)) * 100.0));
		else
			for (new j = 1; j <= MaxClients; j++)
				if (IsClientConnected(j) && IsClientInGame(j)&& !IsFakeClient(j) && GetClientTeam(j) == team)
					CPrintToChat(j,"{green}★{default} SI:{blue} %N{default} ({olive}%d{default} dmg [{green}%d%%%%{default}], {olive}%d{default} kills [{green}%d%%%%{default}])",client, val, percent, kills,RoundFloat((float(kills) / float(totalkills)) * 100.0));
		

		// Print individual reports for each survivor that isn't the MVP
		/*
		for (i = 1; i < survivor_count; i++)
		{
			client = sortable[i][0];
			val = sortable[i][1];
			kills = g_iMapStats[client][SIKills];
			percent = RoundFloat((float(val) / float(total)) * 100.0);
			PrintToChat(client, "\x01You - SI: \x05#%d\x01 (\x05%d\x01 dmg [\x04%d%%\x01], \x05%d\x01 kills [\x04%d%%\x01]", i + 1, val, percent, kills,RoundFloat((float(kills) / float(totalkills)) * 100.0));
		}*/
	}

	// --------------------------- CI Kills ---------------------------
	total = 0;
	for (i = 0; i < survivor_count; i++)
	{
		client = survivor_clients[i];
		val = g_iMapStats[client][CIKills];
		sortable[i][0] = client;
		sortable[i][1] = val;
		total += val;
	}
	if (total == 0)
	{
		//CPrintToChatAll("{green}★{default} CI: {blue}N/A{default}");
	}
	else
	{
		SortCustom2D(sortable, survivor_count, ClientValue2DSortDesc);
		client = sortable[0][0];
		val = sortable[0][1];
		percent = RoundFloat((float(val) / float(total)) * 100.0);
		// Again, credit to Tabun
		
		if(team == 0)
			CPrintToChatAll("{green}★{default} CI: {blue}%N{default} ({olive}%d{default} common [{green}%d%%%%{default}])",client, val, percent);
		else
			for (new j = 1; j <= MaxClients; j++)
				if (IsClientConnected(j) && IsClientInGame(j)&& !IsFakeClient(j) && GetClientTeam(j) == team)
					CPrintToChat(j,"{green}★{default} CI: {blue}%N{default} ({olive}%d{default} common [{green}%d%%%%{default}])",client, val, percent);
		/*
		for (i = 1; i < survivor_count; i++)
		{
			client = sortable[i][0];
			val = sortable[i][1];
			percent = RoundFloat((float(val) / float(total)) * 100.0);
			PrintToChat(client, "\x01You - CI: \x05#%d\x01 (\x05%d\x01 common [\x04%d%%\x01])",i + 1, val, percent);
		}*/
	}
	// --------------------------- 黑槍之王 MVP ---------------------------
	new MVP_damage = 0,MVP_client = 0;
	total = 0;
	for (i = 0; i < survivor_count; i++)
	{
		client = survivor_clients[i];
		if(g_iMapStats[client][FF] > MVP_damage)
		{
			MVP_damage = g_iMapStats[client][FF];
			MVP_client = client;
		}
		total += g_iMapStats[client][FF];
	}
	if (MVP_damage == 0)
	{
		//CPrintToChatAll("{green}★{default} FF: {blue}N/A{default}");
	}
	else
	{
		percent = RoundFloat((float(MVP_damage) / float(total)) * 100.0);
		if(team == 0)
			CPrintToChatAll("{green}★{default} FF: {blue}%N{default} ({olive}%d{default} dmg [{green}%d%%%%{default}])",MVP_client, MVP_damage, percent);
		else
			for (new j = 1; j <= MaxClients; j++)
				if (IsClientConnected(j) && IsClientInGame(j)&& !IsFakeClient(j) && GetClientTeam(j) == team)
					CPrintToChat(j,"{green}★{default} FF: {blue}%N{default} ({olive}%d{default} dmg [{green}%d%%%%{default}])",MVP_client, MVP_damage, percent);

	}
	
	// --------------------------- Skeet MVP ---------------------------
	new MVP_skeetkills = 0,MVP_fullskeetkills=0,MVP_teamskeetkills=0;
	MVP_client = 0;
	total = 0;
	new fullskeetkills_total = 0, teamskeetkills_total = 0;
	new fullskeetkills_percent,teamskeetkills_percent;
	for (i = 0; i < survivor_count; i++)
	{
		client = survivor_clients[i];
		if(g_iMapStats[client][FullSkeets] + g_iMapStats[client][TeamSkeets] >  MVP_skeetkills)
		{
			MVP_fullskeetkills = g_iMapStats[client][FullSkeets];
			MVP_teamskeetkills = g_iMapStats[client][TeamSkeets];
			MVP_skeetkills = g_iMapStats[client][FullSkeets] + g_iMapStats[client][TeamSkeets];
			MVP_client = client;
		}
		fullskeetkills_total += g_iMapStats[client][FullSkeets];
		teamskeetkills_total += g_iMapStats[client][TeamSkeets];
	}
	if (MVP_skeetkills == 0)
	{
		//CPrintToChatAll("{green}★{default} Skeet: {blue}N/A{default}");
	}
	else
	{
		if(fullskeetkills_total != 0)
			fullskeetkills_percent = RoundFloat((float(MVP_fullskeetkills) / float(fullskeetkills_total)) * 100.0);
		else 
			fullskeetkills_percent = 0;
		if(teamskeetkills_total != 0)
			teamskeetkills_percent = RoundFloat((float(MVP_teamskeetkills) / float(teamskeetkills_total)) * 100.0);
		else
			teamskeetkills_percent = 0;
		if(team == 0)
			CPrintToChatAll("{green}★{default} Skeet: {blue}%N{default} ({olive}%d{default} Full Skeets [{green}%d%%%%{default}], {olive}%d{default} Team Skeets [{green}%d%%%%{default}])",MVP_client, MVP_fullskeetkills,fullskeetkills_percent,MVP_teamskeetkills, teamskeetkills_percent);
		else
			for (new j = 1; j <= MaxClients; j++)
				if (IsClientConnected(j) && IsClientInGame(j)&& !IsFakeClient(j) && GetClientTeam(j) == team)
					CPrintToChat(j,"{green}★{default} Skeet: {blue}%N{default} ({olive}%d{default} Full Skeets [{green}%d%%%%{default}], {olive}%d{default} Team Skeets [{green}%d%%%%{default}])",MVP_client, MVP_fullskeetkills,fullskeetkills_percent,MVP_teamskeetkills, teamskeetkills_percent);
	}
	
	// --------------------------- 推推小王子 MVP ---------------------------
	
	new MVP_deadstop = 0;
	MVP_client = 0;
	total = 0;
	for (i = 0; i < survivor_count; i++)
	{
		client = survivor_clients[i];
		if(g_iMapStats[client][Deadstops] >  MVP_deadstop)
		{
			MVP_deadstop = g_iMapStats[client][Deadstops];
			MVP_client = client;
		}
		total += g_iMapStats[client][Deadstops];
	}
	if (MVP_deadstop == 0)
	{
		//CPrintToChatAll("{green}★{default} Deadstops: {blue}N/A{default}");
	}
	else
	{
		if(GetConVarInt(FindConVar("versus_shove_hunter_fov_pouncing")) != 0)
		{
			percent = RoundFloat((float(MVP_deadstop) / float(total)) * 100.0);
			if(team == 0)
				CPrintToChatAll("{green}★{default} Deadstops: {blue}%N{default} ({olive}%d{default} times [{green}%d%%%%{default}])",MVP_client, MVP_deadstop,percent);
			else
				for (new j = 1; j <= MaxClients; j++)
					if (IsClientConnected(j) && IsClientInGame(j)&& !IsFakeClient(j) && GetClientTeam(j) == team)
						CPrintToChat(j,"{green}★{default} Deadstops: {blue}%N{default} ({olive}%d{default} times [{green}%d%%%%{default}])",MVP_client, MVP_deadstop,percent);
		}
	}
	/*
	// --------------------------- 抖M受 MVP ---------------------------
	
	new MVP_SIDamageTaken = 0,MVP_CIDamageTaken=0;
	MVP_damage=0;
	MVP_client = 0;
	new SIDamageTaken_total = 0, CIDamageTaken_total = 0;
	new SIDamageTaken_percent,CIDamageTaken_percent;
	for (i = 0; i < survivor_count; i++)
	{
		client = survivor_clients[i];
		if(g_iMapStats[client][SIDamageTaken] + g_iMapStats[client][CIDamageTaken] >  MVP_damage)
		{
			MVP_SIDamageTaken = g_iMapStats[client][SIDamageTaken];
			MVP_CIDamageTaken = g_iMapStats[client][CIDamageTaken];
			MVP_damage = g_iMapStats[client][SIDamageTaken] + g_iMapStats[client][CIDamageTaken];
			MVP_client = client;
		}
		SIDamageTaken_total += g_iMapStats[client][SIDamageTaken];
		CIDamageTaken_total += g_iMapStats[client][CIDamageTaken];
	}
	if (MVP_damage == 0)
	{
		//CPrintToChatAll("{default}[{olive}TS{default}] MVP: {blue}N/A{default}");
	}
	else
	{
		if(SIDamageTaken_total != 0)
			SIDamageTaken_percent = RoundFloat((float(MVP_SIDamageTaken) / float(SIDamageTaken_total)) * 100.0);
		else
			SIDamageTaken_percent = 0;
		if(CIDamageTaken_total != 0)
			CIDamageTaken_percent = RoundFloat((float(MVP_CIDamageTaken) / float(CIDamageTaken_total)) * 100.0);
		else
			CIDamageTaken_percent = 0;
		if(team == 0)
			CPrintToChatAll("{default}[{olive}TS{default}] MVP: {blue}%N{default} ({olive}%d{default} si [{green}%d%%%%{default}], {olive}%d{default} common [{green}%d%%%%{default}])",MVP_client, MVP_SIDamageTaken,SIDamageTaken_percent,MVP_CIDamageTaken, CIDamageTaken_percent);
		else
			for (new j = 1; j <= MaxClients; j++)
				if (IsClientConnected(j) && IsClientInGame(j)&& !IsFakeClient(j) && GetClientTeam(j) == team)
					CPrintToChat(j,"{default}[{olive}TS{default}] MVP: {blue}%N{default} ({olive}%d{default} si [{green}%d%%%%{default}], {olive}%d{default} common [{green}%d%%%%{default}])",MVP_client, MVP_SIDamageTaken,SIDamageTaken_percent,MVP_CIDamageTaken, CIDamageTaken_percent);
		
	}
	*/
	// --------------------------- Team Stats ---------------------------
	/*
	new skeets, fullskeets, teamskeets, deadstops, pounce_eats, dp_eats;
	new successful_booms, shutdown_booms, vomited_survivors, proxied_survivors;
	new dmg_from_si, dmg_from_ci, dmg_from_ff;

	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		if (IsSurvivor(i))
		{
			fullskeets += g_iMapStats[i][FullSkeets];
			teamskeets += g_iMapStats[i][TeamSkeets];
			skeets += g_iMapStats[i][FullSkeets] + g_iMapStats[i][TeamSkeets];
			deadstops += g_iMapStats[i][Deadstops];
			pounce_eats += g_iMapStats[i][PouncesEaten];
			dp_eats += g_iMapStats[i][DPsEaten];
			shutdown_booms += g_iMapStats[i][BoomerShutdowns];
			dmg_from_si += g_iMapStats[i][SIDamageTaken];
			dmg_from_ci += g_iMapStats[i][CIDamageTaken];
			dmg_from_ff += g_iMapStats[i][FF];
		}
		else if (IsInfected(i))
		{
			successful_booms += g_iMapStats[i][BoomSuccesses];
			vomited_survivors += g_iMapStats[i][BoomedSurvivorsByVomit];
			proxied_survivors += g_iMapStats[i][BoomedSurvivorsByProxy];
		}
	}
	*/
/*
TEAM - Hunters: 40% (4/10) shutdown (3 skeets, 1 DS, 2 DPs landed)
TEAM - Boomers: 20% (1/5) shutdown (4 vomited, 3 proxied)
TEAM - Damage: 173 from SI, 97 from common, 23 from FF
*/

	/*
	if ((skeets + deadstops + pounce_eats) == 0)
	{
		//CPrintToChatAll("{default}TEAM - Hunters: {green}N/A{default}");
	}
	else
	{
		
		CPrintToChatAll("{default}TEAM - Hunters: {green}%d%%%%{default} ({olive}%d{default}/{olive}%d{default}) shutdown (\x05%d{default} skeet%s,{olive}%d{default} DS, {olive}%d{default} DP%s landed)",
			RoundFloat((float(skeets + deadstops) / float(skeets + deadstops + pounce_eats)) * 100.0),
			(skeets + deadstops), (skeets + deadstops + pounce_eats),
			skeets, skeets == 1 ? "":"s", deadstops, dp_eats, dp_eats == 1 ? "":"s");
		
	}

	if ((successful_booms + shutdown_booms) == 0)
	{
		//CPrintToChatAll("{default}TEAM - Boomers: {green}N/A{default}");
	}
	else
	{
		
		CPrintToChatAll("{default}TEAM - Boomers: {green}%d%%%%{default} ({olive}%d{default}/{olive}%d{default}) shutdown (\x05%d{default} vomited, {olive}%d{default} proxied)",
			RoundFloat((float(shutdown_booms) / float(successful_booms + shutdown_booms)) * 100.0),
			shutdown_booms, (shutdown_booms + successful_booms), vomited_survivors, proxied_survivors);
		
	}

	if ((dmg_from_si + dmg_from_ci + dmg_from_ff) == 0)
	{
		//CPrintToChatAll("{default}TEAM - Damage: {green}N/A{default}");
	}
	else
	{
		//CPrintToChatAll("{default}TEAM - Damage: {olive}%d{default} from {lightgreen}SI{default}, {olive}%d{default} from {lightgreen}common{default}, {olive}%d{default} from {lightgreen}FF{default}",dmg_from_si, dmg_from_ci, dmg_from_ff);
	}
	*/
}

// Spectators: Print survivor stats & infected stats
// Survivors: Print survivor stats
// Infected: Print infected stats
/*
public PrintConsoleStats()
{
	CreateTimer(0.1, Timer_PrintSurvivorStatsHeader);
	CreateTimer(0.2, Timer_PrintSurvivorStatsBody);
	CreateTimer(0.3, Timer_PrintSurvivorStatsFooter);
	CreateTimer(0.4, Timer_PrintInfectedStatsHeader);
	CreateTimer(0.5, Timer_PrintInfectedStatsBody);
	CreateTimer(0.6, Timer_PrintInfectedStatsFooter);
}

public Action:Timer_PrintSurvivorStatsHeader(Handle:timer)
{
	new const maxlength = 1024;
	decl String:buf[maxlength];
	Format(buf, maxlength, "\n|----------------------------------------------- SURVIVOR STATS -----------------------------------------------|\n");
	Format(buf, maxlength, "%s| NAME                 | SIK  | SID    | CI   | DS  | Skeets         | SA  | BS  | FF   | DFC  | Pounces Eaten |\n", buf);
	Format(buf, maxlength, "%s|----------------------|------|--------|------|-----|----------------|-----|-----|------|------|---------------|", buf);
	PrintToTeamConsole(FLAG_SPECTATOR | FLAG_SURVIVOR, buf);
}

public Action:Timer_PrintSurvivorStatsBody(Handle:timer)
{
	decl i, j, val;
	decl lows_highs[STATS_MAX][2];
	// Initialize lows_highs
	for (i = 0; i < STATS_MAX; i++)
	{
		lows_highs[i][0] = 9999999;
		lows_highs[i][1] = -1;
	}

	// Calculate actual lows_highs values
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsSurvivor(i)) continue;
		for (j = 0; j < STATS_MAX; j++)
		{
			if (j == TeamSkeets) continue;
			else if (j == FullSkeets)
			{ // Store the total skeets value in fullskeets, just for checking lows_highs
				val = g_iMapStats[i][FullSkeets] + g_iMapStats[i][TeamSkeets];
			}
			else
			{
				val = g_iMapStats[i][j];
			}
			if (val < lows_highs[j][0]) lows_highs[j][0] = val;
			if (val > lows_highs[j][1]) lows_highs[j][1] = val;
		}
	}

	new const max_name_len = 20;
	new const s_len = 15;
	decl String:name[MAX_NAME_LENGTH];
	decl String:sikills[s_len], String:sidamage[s_len], String:cikills[s_len], String:deadstops[s_len];
	decl String:skeets[s_len], String:skeetassists[s_len], String:boomershutdowns[s_len];
	decl String:ff[s_len], String:cidamage[s_len], String:pounceseaten[s_len];

	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsSurvivor(i)) continue;
		GetClientName(i, name, sizeof(name));
		name[max_name_len] = 0;
		val = g_iMapStats[i][SIKills];
		Format(sikills, s_len, "%s%d", GetModifierChar(val, SIKills), val);

		val = g_iMapStats[i][SIDamage];
		Format(sidamage, s_len, "%s%d", GetModifierChar(val, SIDamage), val);

		val = g_iMapStats[i][CIKills];
		Format(cikills, s_len, "%s%d", GetModifierChar(val, CIKills), val);

		val = g_iMapStats[i][Deadstops];
		Format(deadstops, s_len, "%s%d", GetModifierChar(val, Deadstops), val);

		val = g_iMapStats[i][FullSkeets] + g_iMapStats[i][TeamSkeets];
		Format(skeets, s_len, "%s%d (%dF/%dT)", GetModifierChar(val, FullSkeets), val,
													g_iMapStats[i][FullSkeets], g_iMapStats[i][TeamSkeets]);

		val = g_iMapStats[i][SkeetAssists];
		Format(skeetassists, s_len, "%s%d", GetModifierChar(val, SkeetAssists), val);

		val = g_iMapStats[i][BoomerShutdowns];
		Format(boomershutdowns, s_len, "%s%d", GetModifierChar(val, BoomerShutdowns), val);

		val = g_iMapStats[i][FF];
		Format(ff, s_len, "%s%d", GetModifierCharReversed(val, FF), val);

		val = g_iMapStats[i][CIDamageTaken];
		Format(cidamage, s_len, "%s%d", GetModifierCharReversed(val, CIDamageTaken), val);

		val = g_iMapStats[i][PouncesEaten];
		Format(pounceseaten, s_len, "%s%d (%d DPs)", GetModifierCharReversed(val, PouncesEaten), val, g_iMapStats[i][DPsEaten]);

		PrintToTeamConsole(FLAG_SPECTATOR | FLAG_SURVIVOR,
			"| %20s | %4s | %6s | %4s | %3s | %14s | %3s | %3s | %4s | %4s | %13s |",
			name,
			sikills,
			sidamage,
			cikills,
			deadstops,
			skeets,
			skeetassists,
			boomershutdowns,
			ff,
			cidamage,
			pounceseaten);
	}
}

public Action:Timer_PrintSurvivorStatsFooter(Handle:timer)
{
	new const maxlength = 1024;
	decl String:buf[maxlength];
	Format(buf, maxlength, "\nLegend:\n");
	Format(buf, maxlength, "%s  %s = Best  %s = Worst\n", buf, HIGHCHAR, LOWCHAR);
	Format(buf, maxlength, "%s  SIK     - Special Infected killed\n", buf);
	Format(buf, maxlength, "%s  SID     - Damage dealt to Special Infected\n", buf);
	Format(buf, maxlength, "%s  CI      - Common infected killed\n", buf);
	Format(buf, maxlength, "%s  DS      - Deadstops landed\n", buf);
	Format(buf, maxlength, "%s  Skeets  - Total number of skeets (# full skeets/# team skeets)\n", buf);
	Format(buf, maxlength, "%s  SA      - Skeets assisted\n", buf);
	Format(buf, maxlength, "%s  BS      - Boomer shutdowns\n", buf);
	Format(buf, maxlength, "%s  FF      - Friendly Fire\n", buf);
	Format(buf, maxlength, "%s  DFC     - Damage from common infected\n", buf);
	PrintToTeamConsole(FLAG_SPECTATOR | FLAG_SURVIVOR, buf);
}

public Action:Timer_PrintInfectedStatsHeader(Handle:timer)
{
	new const maxlength = 1024;
	decl String:buf[maxlength];
	Format(buf, maxlength, "\n|----------------------------------- INFECTED STATS -----------------------------------|\n");
	Format(buf, maxlength, "%s| NAME                 | Dmg   | Pounce Success            | Boomer Success            |\n", buf);
	Format(buf, maxlength, "%s|----------------------|-------|---------------------------|---------------------------|", buf);
//| Name | *1291 | *100% (10L (2DP)/10S/10D) | *100% (10A/13F/10V/10P) |
	PrintToTeamConsole(FLAG_SPECTATOR | FLAG_INFECTED, buf);
}

public Action:Timer_PrintInfectedStatsBody(Handle:timer)
{
	new dmg_low = 99999999;
	new dmg_high = -1;
	new pounces_low = 99999999;
	new pounces_high = -1;
	new booms_low = 99999999;
	new booms_high = -1;

	decl val, i;
	new bool:has_printed;

	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsInfected(i) || IsFakeClient(i)) continue;
		val = g_iMapStats[i][DamageDealtAsSI];
		if (val < dmg_low) dmg_low = val;
		if (val > dmg_high) dmg_high = val;

		val = g_iMapStats[i][PouncesLanded];
		if (val < pounces_low) pounces_low = val;
		if (val > pounces_high) pounces_high = val;

		val = g_iMapStats[i][BoomSuccesses];
		if (val < booms_low) booms_low = val;
		if (val > booms_high) booms_high = val;
	}

	new const max_name_len = 20;
	new const s_len = 30;
	decl String:name[MAX_NAME_LENGTH];
	decl String:dmg[s_len], String:pounce_success[s_len], String:boomer_success[s_len];

	for (i = 1; i <= MaxClients; i++)
	{
		// No infected bot stats...
		if (!IsClientInGame(i) || !IsInfected(i) || IsFakeClient(i)) continue;
		GetClientName(i, name, sizeof(name));
		name[max_name_len] = 0;

		val = g_iMapStats[i][DamageDealtAsSI];
		Format(dmg, s_len, "%s%d",
			val == dmg_high ? HIGHCHAR:val == dmg_low ? LOWCHAR:"",
			val);

		val = g_iMapStats[i][PouncesLanded];
		Format(pounce_success, s_len, "%s%d/%d (%d DPs/%d S/%d DS)",
			val == pounces_high ? HIGHCHAR:val == pounces_low ? LOWCHAR:"",
			val,
			val + g_iMapStats[i][Skeeted] + g_iMapStats[i][Deadstopped],
			g_iMapStats[i][DPsLanded],
			g_iMapStats[i][Skeeted],
			g_iMapStats[i][Deadstopped]);

		val = g_iMapStats[i][BoomSuccesses];
		Format(boomer_success, s_len, "%s%d/%d (%d Vomit/%d Proxy)",
			val == booms_high ? HIGHCHAR:val == booms_low ? LOWCHAR:"",
			val,
			g_iMapStats[i][BoomAttempts],
			g_iMapStats[i][BoomedSurvivorsByVomit],
			g_iMapStats[i][BoomedSurvivorsByProxy]);

		PrintToTeamConsole(FLAG_SPECTATOR | FLAG_INFECTED,
			"| %20s | %5s | %25s | %25s |",
			name,
			dmg,
			pounce_success,
			boomer_success);

		has_printed = true;
	}

	if (!has_printed)
	{
		PrintToTeamConsole(FLAG_SPECTATOR | FLAG_INFECTED, "No infected found.");
	}
}

public Action:Timer_PrintInfectedStatsFooter(Handle:timer)
{
	new const maxlength = 1024;
	decl String:buf[maxlength];
	Format(buf, maxlength, "\nLegend:\n");
	Format(buf, maxlength, "%s   Dmg              - Damage dealt to non-incapped survivors\n", buf);
	Format(buf, maxlength, "%s   Pounce Success   - DP = Damage Pounce, S = Skeeted, DS = Deadstop\n", buf);
	PrintToTeamConsole(FLAG_SPECTATOR | FLAG_INFECTED, buf);
}
*/
/*
public Action:Command_Stats(client, args)
{
	if (g_bStatsCooldown[client]) return Plugin_Handled;
	g_bStatsCooldown[client] = true;
	decl String:name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	if (StrEqual(name, "Griffin"))
	{
		PrintMVPAndTeamStats();
		PrintConsoleStats();
	}
	else
	{
		ReplyToCommand(client, "[SM] This command is currently disabled, stats will print automatically at the end of the round.");
	}
	// PrintToChatAll("[DEBUG] Printing stats to all!\n");
	// PrintStatsToAll();

	// if (GetCmdReplySource() == SM_REPLY_TO_CHAT) PrintToChat(client, "[SM] Check console for output.\n");

	CreateTimer(1.0, Timer_StatsCooldown, client);
	return Plugin_Handled;
}
*/

public Action:Timer_StatsCooldown(Handle:timer, any:client)
{
	g_bStatsCooldown[client] = false;
	return Plugin_Stop;
}
/*
public Cvar_MaxPlayerZombies(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iMaxPlayerZombies = StringToInt(newValue);
}*/

public Cvar_SurvivorLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iSurvivorLimit = StringToInt(newValue);
}

public Cvar_MaxPounceBonusDamage(Handle:convar, const String:oldValue[], const String:newValue[])
{
	CalculateMinDPDamage(StringToFloat(newValue));
}

CalculateMinDPDamage(Float:bonus_pounce_damage)
{
	// Max pounce damage = bonus pounce damage + 1
	g_iMinDPDamage = RoundToFloor((bonus_pounce_damage + 1.0) * MIN_DP_RATIO);
}

public Cvar_WitchHealth(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iWitchHealth = StringToInt(newValue);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_iRocksBeingThrownCount = 0;
	isroundreallyend = false;
	g_bHasRoundEnded = false;
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(isroundreallyend)
		return;
	isroundreallyend = true;
	// In case witch is avoided
	g_iAccumulatedWitchDamage = 0;
	ResetWitchTracking();
	if (g_bHasRoundEnded) return;
	g_bHasRoundEnded = true;
	CreateTimer(7.5, Timer_DelayedStatsPrint);
	for (new i = 1; i <= MaxClients; i++)
	{
		// if (IsClientInGame(i) && IsSurvivor(i))
		// {
			// buf = GetStatString(i);
			// PrintToChat(i, "Round ended.");
		// }
		ClearDamage(i);
		g_iWitchDamage[i] = 0;
	}
}

public Action:PlayerHook_OnTakeDamagePre(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	// Non incapped survivor victim
	if (!victim ||
		victim > MaxClients ||
		!IsClientInGame(victim) ||
		!IsSurvivor(victim) ||
		IsIncapped(victim)
		) return;

	g_iLastHealth[victim] = GetClientHealth(victim);
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHasRoundEnded||IsInReady()) return;
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));

	if (victim == 0 ||
		!IsClientInGame(victim)
		) return;

	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (!attacker)
	{
		// Damage from common
		if (!IsCommonInfected(GetEventInt(event, "attackerentid")) || IsIncapped(victim)) return;
		new damage = g_iLastHealth[victim] - GetEventInt(event, "health");
		if (damage < 0 || damage > 2)
		{
			//PrintToChatAll("[DEBUG] Invalid common damage value of %d detected for %N. Tell Griffin what happened!",
			//	damage,
			//	victim);
			damage = 1;
		}
		g_iMapStats[victim][CIDamageTaken] += damage;

		if (IsBoomed(victim) &&
			g_iBoomerClient &&
			IsClientInGame(g_iBoomerClient) &&
			!IsFakeClient(g_iBoomerClient))
		{
			g_iMapStats[g_iBoomerClient][DamageDealtAsSI] += damage;
		}
		return;
	}
	else if (!IsClientInGame(attacker)) return;

	new damage = GetEventInt(event, "dmg_health");

	if (IsSurvivor(attacker))
	{
		// FF (don't log incapped damage, doesn't matter)
		if (IsSurvivor(victim))
		{
			g_iMapStats[attacker][FF] += damage;
		}
		// Hot survivor on infected action, baby
		else if (IsInfected(victim))
		{
			new zombieclass = GetEntProp(victim, Prop_Send, "m_zombieClass");
			if (zombieclass == ZC_TANK) return; // We don't care about tank damage

			if (!g_bShotCounted[victim][attacker])
			{
				g_iShotsDealt[victim][attacker]++;
				g_bShotCounted[victim][attacker] = true;
			}

			new remaining_health = GetEventInt(event, "health");

			// Let player_death handle remainder damage (avoid overkill damage)
			if (remaining_health <= 0) return;

			//配合G擊槍改Hunter傷害
			if (zombieclass == ZC_HUNTER)
			{
				decl String:weapon[16];
				GetEventString(event, "weapon", weapon, sizeof(weapon));	
				if (StrEqual(weapon, "hunting_rifle"))
				{
					new newdmg; 
					switch (GetEventInt(event, "hitgroup"))
					{
						case 2:
						{
							newdmg = RoundToNearest(damage*2.8);
						}
						case 3:
						{
							newdmg = RoundToNearest(damage*1.8);				
						}	
						default:
						{
						}
					}
					new OldHealth = GetEventInt(event,"health");
					new originalhealth = OldHealth + damage;
					if(originalhealth - newdmg <= 0)
					{
						damage = originalhealth;
						remaining_health = 0;
					} 
					else
					{
						damage = newdmg;
						remaining_health = originalhealth - newdmg;
					}
				}
			}
			// remainder health will be awarded as damage on kill
			g_iLastHealth[victim] = remaining_health;

			g_iMapStats[attacker][SIDamage] += damage;
			g_iDamageDealt[victim][attacker] += damage;

			if (zombieclass == ZC_BOOMER)
			{ /* Boomer Shit Here */ }
		}
	}
	if (IsInfected(attacker) && IsSurvivor(victim) && !IsIncapped(victim))
	{
		g_iMapStats[victim][SIDamageTaken] += damage;
		g_iMapStats[attacker][DamageDealtAsSI] += damage;
	}
	
	if ( IS_VALID_INFECTED(attacker) )
    {
        new zombieclass = GetEntProp(attacker, Prop_Send, "m_zombieClass");
        
        switch ( zombieclass )
        {
           case ZC_TANK:
            {
                new String: weapon[10];
                GetEventString(event, "weapon", weapon, sizeof(weapon));
                
                if ( StrEqual(weapon, "tank_rock") )
                {
                    // find rock entity through tank
					if(g_iTankRock[attacker])
					{
						// remember that the rock wasn't shot
                        decl String:rock_key[10];
                        FormatEx(rock_key, sizeof(rock_key), "%x", g_iTankRock[attacker]);
                        new rock_array[3];
                        rock_array[rckDamage] = -1;
                        SetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array), true);
                    }
					
					if(IS_VALID_SURVIVOR(victim))
                    {
                        HandleRockEaten( attacker, victim );
                    }
                }
                
                return;
            }
		}
	}
}

public Event_PlayerShoved(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHasRoundEnded) return;
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (victim == 0 ||
		!IsClientInGame(victim) ||
		!IsInfected(victim)
		) return;

	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (attacker == 0 ||				// World dmg?
		!IsClientInGame(attacker) ||	// Unsure
		!IsSurvivor(attacker)
		) return;
	
	new zombieclass = GetEntProp(victim, Prop_Send, "m_zombieClass");

	if (zombieclass == ZC_BOOMER) 
	{
		if (g_hBoomerShoveTimer != INVALID_HANDLE)
		{
			KillTimer(g_hBoomerShoveTimer);
			if (!g_iBoomerShover || !IsClientInGame(g_iBoomerShover)) g_iBoomerShover = attacker;
		}
		else
		{
			g_iBoomerShover = attacker;
		}
		g_hBoomerShoveTimer = CreateTimer(BOOMER_STAGGER_TIME, Timer_BoomerShove);
	}
	else if (zombieclass == ZC_HUNTER && IsPouncing(victim))
	{ // DEADSTOP

		// Groundtouch timer will do this for us, but
		// this prevents multiple deadstops being counted incorrectly
		g_bIsPouncing[victim] = false;
		// Delayed check to see if the pounce actually landed due to bug where player_shoved gets fired but pounce lands anyways
		g_bHasLandedPounce[attacker] = false;
		
		
		if(GetConVarInt(FindConVar("versus_shove_hunter_fov_pouncing")) != 0)
		{
			new Handle:pack;
			CreateDataTimer(0.2, Timer_DeadstopCheck, pack);
			WritePackCell(pack, attacker);
			WritePackCell(pack, victim);
		}
	}
}

public Action:Timer_DeadstopCheck(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new attacker = ReadPackCell(pack);
	if (!g_bHasLandedPounce[attacker])
	{
		new victim = ReadPackCell(pack);
		// TODO: Add tracking for number of times a person was deadstopped (along with other pounce stats)
		g_iMapStats[attacker][Deadstops]++;
		if (IsClientInGame(victim) && IsClientInGame(attacker))
		{
			CPrintToChat(attacker, "{default}[{olive}TS{default}] You deadstopped{red} %N{default}.", victim);
			if (!IsFakeClient(victim))
			{
				g_iMapStats[victim][Deadstopped]++;
				CPrintToChat(victim, "{default}[{olive}TS{default}] You were deadstopped by{blue} %N{default}.", attacker);
			}
		}
	}
}

public Action:Timer_BoomerShove(Handle:timer)
{
	// PrintToChatAll("[DEBUG] BoomerShove timer expired, credit for boomer shutdown is available to anyone at this point!");
	g_hBoomerShoveTimer = INVALID_HANDLE;
	g_iBoomerShover = 0;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client == 0 || !IsClientInGame(client)) return;

	if (IsInfected(client))
	{
		new zombieclass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (zombieclass == ZC_TANK) return;

		if (zombieclass == ZC_BOOMER)
		{
			// Fresh boomer spawning (if g_iBoomerClient is set and an AI boomer spawns, it's a boomer going AI)
			if (!IsFakeClient(client) || !g_iBoomerClient)
			{
				g_bHasBoomLanded = false;
				g_iBoomerClient = client;
				g_iBoomerShover = 0;
				g_iBoomerKiller = 0;
			}
			if (!IsFakeClient(client))
			{
				g_iMapStats[client][BoomAttempts]++;
			}
			if (g_hBoomerShoveTimer != INVALID_HANDLE)
			{
				KillTimer(g_hBoomerShoveTimer);
				g_hBoomerShoveTimer = INVALID_HANDLE;
			}
		}

		g_iLastHealth[client] = GetClientHealth(client);
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHasRoundEnded) return;
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));

	if (victim == 0 ||
		!IsClientInGame(victim)
		) return;

	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (attacker == 0)
	{ // Check for a witch-related death (black & white survivor failing or no-incap configs e.g. 1v1)
		if (IsInfected(victim)) ClearDamage(victim);
		if (!IsWitch(GetEventInt(event, "attackerentid")) ||
			!g_bShouldAnnounceWitchDamage					// Prevent double print on incap -> death by witch
			) return;
		
		new health = g_iWitchHealth - g_iAccumulatedWitchDamage;
		if (health < 0) health = 0;
		
		if (IsSurvivor(victim))
		{
			CPrintToChatAll("{default}[{olive}TS{default}] {red}Witch {default}had{green} %d{default} health remaining.", health);
			CPrintToChatAll("{default}[{olive}TS{default}] {blue}%N {default}was killed by {green}Witch.", victim);
			/*for (new i = 1; i <= MaxClients; i++)
			{
				if (g_iWitchDamage[i] > 0 && IsClientInGame(i))
				{
					CPrintToChat(i, "{default}[{olive}TS{default}] You dealt{green} %d{default} damage to the{red} witch{default}.", g_iWitchDamage[i]);
				}
			}*/
			g_iAccumulatedWitchDamage = 0;
			g_bShouldAnnounceWitchDamage = false;
		}
		return;
	}

	if (!IsClientInGame(attacker))
	{
		if (IsInfected(victim)) ClearDamage(victim);
		return;
	}

	if (IsSurvivor(attacker) && IsInfected(victim))
	{
		new zombieclass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if (zombieclass == ZC_TANK) return; // We don't care about tank damage
	
		g_iMapStats[attacker][SIKills]++;
		new lasthealth = g_iLastHealth[victim];
		g_iMapStats[attacker][SIDamage] += lasthealth;
		g_iDamageDealt[victim][attacker] += lasthealth;
		if (zombieclass == ZC_BOOMER)
		{
			// Only happens on mid map plugin load when a boomer is up
			if (!g_iBoomerClient) g_iBoomerClient = victim;

			CreateTimer(0.2, Timer_BoomerKilledCheck, victim);
			g_iBoomerKiller = attacker;
		}
		else if (zombieclass == ZC_HUNTER && IsPouncing(victim))
		{ // Skeet!
			if (!IsFakeClient(victim))
			{
				g_iMapStats[victim][Skeeted]++;
			}
			decl assisters[g_iSurvivorLimit][2];
			new assister_count, i;
			new damage = g_iDamageDealt[victim][attacker];
			new shots = g_iShotsDealt[victim][attacker];
			new String:plural[1] = "s";
			if (shots == 1) plural[0] = 0;
			for (i = 1; i <= MaxClients; i++)
			{
				if (i == attacker) continue;
				if (g_iDamageDealt[victim][i] > 0 && IsClientInGame(i))
				{
					g_iMapStats[i][SkeetAssists]++;
					assisters[assister_count][0] = i;
					assisters[assister_count][1] = g_iDamageDealt[victim][i];
					assister_count++;
				}
			}
			if (assister_count)
			{
				// Sort by damage, descending
				SortCustom2D(assisters, assister_count, ClientValue2DSortDesc);
				decl String:assister_string[256];
				decl String:buf[MAX_NAME_LENGTH + 8];
				new assist_shots = g_iShotsDealt[victim][assisters[0][0]];
				// Construct assisters string
				Format(assister_string, sizeof(assister_string), "\x05%N \x01(\x04%d\x01/\x04%d \x01shot%s)",assisters[0][0],assisters[0][1],g_iShotsDealt[victim][assisters[0][0]],assist_shots == 1 ? "":"s");
				for (i = 1; i < assister_count; i++)
				{
					assist_shots = g_iShotsDealt[victim][assisters[i][0]];
					Format(buf, sizeof(buf), ",\x05 %N \x01(\x04%d\x01/\x04%d \x01shot%s)",
						assisters[i][0],
						assisters[i][1],
						assist_shots,
						assist_shots == 1 ? "":"s");
					StrCat(assister_string, sizeof(assister_string), buf);
				}
				
				// Print to assisters
				for (i = 0; i < assister_count; i++)
				{
					CPrintToChat(assisters[i][0], "{default}[{olive}TS{default}]{olive} %N {default}teamskeeted{red} %N{default} for{green} %d {default}damage in{green} %d {default}shot%s.",attacker, victim, damage, shots, plural);
					CPrintToChat(assisters[i][0], "{blue}{default}|| Assisted by: %s.", assister_string);
					//new Handle:h_Pack;
					//CreateDataTimer(0.1,COLD_DOWN,h_Pack);
					//WritePackCell(h_Pack, assisters[i][0]);
					//WritePackString(h_Pack, assister_string);
				}
				// Print to victim
				//new Handle:h_Pack_2;
				CPrintToChat(victim, "{default}[{olive}TS{default}] You were teamskeeted by{blue} %N{default} for{green} %d{default} damage in{green} %d{default} shot%s.", attacker, damage, shots, plural);
				CPrintToChat(victim, "{blue}{default}|| Assisted by: %s.", assister_string);
				//CreateDataTimer(0.1,COLD_DOWN,h_Pack_2);
				//WritePackCell(h_Pack_2, victim);
				//WritePackString(h_Pack_2, assister_string);
				
				// Finally print to attacker
				//new Handle:h_Pack_3;
				CPrintToChat(attacker, "{default}[{olive}TS{default}] You teamskeeted{red} %N{default} for{green} %d{default} damage in{green} %d{default} shot%s.", victim, damage, shots, plural);
				CPrintToChat(attacker, "{blue}{default}|| Assisted by: %s.", assister_string);
				//CreateDataTimer(0.1,COLD_DOWN,h_Pack_3);
				//WritePackCell(h_Pack_3, attacker);
				//WritePackString(h_Pack_3, assister_string);

				g_iMapStats[attacker][TeamSkeets]++;
			}
			else
			{
				g_iMapStats[attacker][FullSkeets]++;
				CPrintToChat(victim, "{default}[{olive}TS{default}] You were skeeted by{blue} %N{default} in{green} %d {default}shot%s.", attacker, shots, plural);
				
				CPrintToChat(attacker, "{default}[{olive}TS{default}] You skeeted{red} %N{default} in{green} %d {default}shot%s.", victim, shots, plural);
			}
		}
	}

	if (IsInfected(victim)) ClearDamage(victim);
}
/*
public Action:COLD_DOWN(Handle:timer,Handle:h_Pack)
{
	new String:assister_string[128],client;
	
	ResetPack(h_Pack);
	client = ReadPackCell(h_Pack);
	ReadPackString(h_Pack, assister_string, sizeof(assister_string));
	
	CPrintToChat(client, "|| Assisted by: %s.", assister_string);
}*/

public Action:Timer_BoomerKilledCheck(Handle:timer, any:client)
{
	// if g_iBoomerClient != client, boomer went AI, maybe do something with that info in the future?
	if (g_bHasBoomLanded) return;

	// In the following code even if it was an AI boomer that was shutdown, we're going to consider the AI boomer
	// the responsibility of the person who spawned it, aka g_iBoomerClient
	if (g_iBoomerShover && IsClientInGame(g_iBoomerShover))
	{
		if (IsClientInGame(g_iBoomerClient))
		{
			if (IsFakeClient(g_iBoomerClient))
			{
				CPrintToChat(g_iBoomerShover, "{default}[{olive}TS{default}] You shut down an{red} AI{default} boomer.");
			}
			else
			{
				CPrintToChat(g_iBoomerShover, "{default}[{olive}TS{default}] You shut down{red} %N{default}'s boomer.", g_iBoomerClient);
				CPrintToChat(g_iBoomerClient, "{default}[{olive}TS{default}]{blue} %N{default} shut down your boomer.", g_iBoomerShover);
				// g_iMapStats[g_iBoomerClient][BoomFailures]++;
			}
		}
		g_iMapStats[g_iBoomerShover][BoomerShutdowns]++;
	}
	else if (IsClientInGame(g_iBoomerKiller))
	{
		if (IsClientInGame(g_iBoomerClient))
		{
			if (IsFakeClient(g_iBoomerClient))
			{
				CPrintToChat(g_iBoomerKiller, "{default}[{olive}TS{default}] You shut down an{red} AI{default} boomer.");
			}
			else
			{
				CPrintToChat(g_iBoomerKiller, "{default}[{olive}TS{default}] You shut down{red} %N{default}'s boomer.", g_iBoomerClient);
				CPrintToChat(g_iBoomerClient, "{default}[{olive}TS{default}]{blue} %N{default} shut down your boomer.", g_iBoomerKiller);
				// g_iMapStats[g_iBoomerClient][BoomFailures]++;
			}
		}
		g_iMapStats[g_iBoomerKiller][BoomerShutdowns]++;
	}

	g_iBoomerClient = 0;
}

public Event_InfectedDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHasRoundEnded) return;
	// NOTE: Has some interesting stats like headshots, if it was a minigun kill or from explosion (might use in future)
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (attacker == 0 ||				// Killed by world?
		!IsClientInGame(attacker) ||
		!IsSurvivor(attacker)			// Tank killing common?
		) return;

	g_iMapStats[attacker][CIKills]++;
}

public Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	for (new i = 1; i <= MaxClients; i++)
	{
		// [Victim][Attacker]
		g_bShotCounted[i][client] = false;
	}
}

public Event_PlayerIncapacitated(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));

	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (attacker && IsClientInGame(attacker) && IsInfected(attacker))
	{
		g_iMapStats[victim][SIDamageTaken] += g_iLastHealth[victim];
		g_iMapStats[attacker][DamageDealtAsSI] += g_iLastHealth[victim];
		return;
	}

	if (!IsWitch(GetEventInt(event, "attackerentid")) ||
		!g_bShouldAnnounceWitchDamage					// Prevent double print on witch incapping 2 players (rare)
		) return;

	new health = g_iWitchHealth - g_iAccumulatedWitchDamage;
	if (health < 0) health = 0;

	CPrintToChatAll("{default}[{olive}TS{default}] {green}Witch {default}crowned {blue}%N{default}.", victim);
	CPrintToChatAll("{default}[{olive}TS{default}] {red}Witch{default} had{green} %d{default} health remaining.", health);
	/*
	for (new i = 1; i <= MaxClients; i++)
	{
		if (g_iWitchDamage[i] > 0 && IsClientInGame(i) && IsSurvivor(i))
		{
			CPrintToChat(i, "{default}[{olive}TS{default}] You dealt{green} %d{default} damage to the{red} witch{default}.", g_iWitchDamage[i]);
		}
	}
	*/
	g_iAccumulatedWitchDamage = 0;
	g_bShouldAnnounceWitchDamage = false;
}

public Event_InfectedHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHasRoundEnded) return;
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (attacker == 0 ||								// Killed by world?
		!IsWitch(GetEventInt(event, "entityid")) ||		// Tracking witch damage only
		!IsClientInGame(attacker) ||
		!IsSurvivor(attacker)							// Claws
		) return;

	new damage = GetEventInt(event, "amount");
	g_iWitchDamage[attacker] += damage;
	g_iAccumulatedWitchDamage += damage;
}

public Event_WitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHasRoundEnded) return;
	g_bIsWitch[GetEventInt(event, "witchid")] = false;

	new killer = GetClientOfUserId(GetEventInt(event, "userid"));

	if (killer == 0 ||				// Killed by world?
		!IsClientInGame(killer)
		) return;

	// Witch kills increment CI kill count, we don't want that (this seems hacky)
	if (IsSurvivor(killer)) g_iMapStats[killer][CIKills]--;

	// Not a crown, show all the survivors how they helped
	// TODO: will show someone how much damage they did on an unassisted drawcrown, fix? do we care?
	/*if (!GetEventBool(event, "oneshot") && g_bShouldAnnounceWitchDamage)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (g_iWitchDamage[i] > 0 && IsClientInGame(i) && IsSurvivor(i))
			{
				CPrintToChat(i, "{default}[{olive}TS{default}] You dealt{green} %d{default} damage to the{red} witch{default}.", g_iWitchDamage[i]);
			}
			g_iWitchDamage[i] = 0;
		}
	}*/

	for (new i = 1; i <= MaxClients; i++) { g_iWitchDamage[i] = 0; }
	g_iAccumulatedWitchDamage = 0;
	g_bShouldAnnounceWitchDamage = true;
}

public Event_WitchSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHasRoundEnded) return;
	g_bIsWitch[GetEventInt(event, "witchid")] = true;
	g_bShouldAnnounceWitchDamage = true;
}

// Pounce tracking, from skeet announce
public Event_AbilityUse(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bHasRoundEnded) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	decl String:ability_name[64];

	GetEventString(event, "ability", ability_name, sizeof(ability_name));
	if (IsClientInGame(client) && strcmp(ability_name, "ability_lunge", false) == 0)
	{
		g_bIsPouncing[client] = true;
		CreateTimer(0.5, Timer_GroundedCheck, client, TIMER_REPEAT);
	}
	else if (IsClientInGame(client) && strcmp(ability_name, "ability_throw", false) == 0)
	{
		// tank throws rock
		g_iRocksBeingThrown[g_iRocksBeingThrownCount] = client;
		
		// safeguard
		if(g_iRocksBeingThrownCount < 9)
			g_iRocksBeingThrownCount++;
	}
	else if (IsClientInGame(client) && strcmp(ability_name, "ability_vomit", false) == 0)
	{
		g_bHasBoomLanded = false;
	}
}

public Action:Timer_GroundedCheck(Handle:timer, any:client)
{
	if (!IsClientInGame(client) || IsGrounded(client))
	{
		g_bIsPouncing[client] = false;
		KillTimer(timer);
	}
}

public Event_LungePounce(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	g_bIsPouncing[attacker] = false;
	g_bHasLandedPounce[attacker] = true;

	// Don't count pounce stats for pounces on incapped survivors
	if (IsIncapped(victim)) return;

	g_iMapStats[attacker][PouncesLanded]++;
	g_iMapStats[victim][PouncesEaten]++;
	if (GetEventInt(event, "damage") >= g_iMinDPDamage)
	{
		g_iMapStats[attacker][DPsLanded]++;
		g_iMapStats[victim][DPsEaten]++;
	}
	
	if(g_iSurvivorLimit != 1)
	{
		new remaining_health = GetClientHealth(attacker);
		CPrintToChat(victim,"[{olive}TS{default}] {red}%N{default} had {green}%d{default} health remaining!", attacker, remaining_health);
		if (remaining_health == 1)
			CPrintToChat(victim, "[{olive}TS{default}] You don't have to be mad...");
	}
}

public Event_PlayerBoomed(Handle:event, const String:name[], bool:dontBroadcast)
{
	// This will only occur if the plugin is loaded mid map (and a boomer is already spawned)
	if (!g_iBoomerClient)
	{
		g_iBoomerClient = GetClientOfUserId(GetEventInt(event, "attacker"));
	}

	if (!g_bHasBoomLanded)
	{
		g_iMapStats[g_iBoomerClient][BoomSuccesses]++;
		g_bHasBoomLanded = true;
	}

	// Doesn't matter if we log stats to an out of play client, won't affect anything
	// if (!IsClientInGame(g_iBoomerClient) || IsFakeClient(g_iBoomerClient)) return;

	// We credit the person who spawned the boomer with booms even if it went AI
	if (GetEventBool(event, "exploded"))
	{
		// possible TODO: g_iBoomerKiller's fault, use this for something?
		g_iMapStats[g_iBoomerClient][BoomedSurvivorsByProxy]++;
	}
	else
	{
		g_iMapStats[g_iBoomerClient][BoomedSurvivorsByVomit]++;
	}
}

ClearMapStats()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		for (new j = 0; j < STATS_MAX; j++) g_iMapStats[i][j] = 0;
		g_iWitchDamage[i] = 0;
		ClearDamage(i);
	}
	g_iAccumulatedWitchDamage = 0;
	ResetWitchTracking();
}

/*
ClearPlayerStatsAndState(client)
{
	for (new i = 0; i < STATS_MAX; i++) g_iMapStats[client][i] = 0;
	g_iWitchDamage[client] = 0;
	ClearDamage(client);
}
*/

ResetWitchTracking()
{
	for (new i = MaxClients + 1; i < MAXENTITIES; i++) g_bIsWitch[i] = false;
}

// Clear g_iDamageDealt, g_iShotsDealt, and g_iLastHealth for given client
ClearDamage(client)
{
	g_iLastHealth[client] = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		g_iDamageDealt[client][i] = 0;
		g_iShotsDealt[client][i] = 0;
	}
}

bool:IsCommonInfected(entity)
{
	if(entity && IsValidEntity(entity) && IsValidEdict(entity))
	{
		decl String:classname[32];
		GetEdictClassname(entity, classname, sizeof(classname));
		return StrEqual(classname, "infected");
	}
	return false;
}  

// Takes 2D arrays [index] = {client, value}
public ClientValue2DSortDesc(x[], y[], const array[][], Handle:data)
{
	if (x[1] > y[1]) return -1;
	else if (x[1] < y[1]) return 1;
	else return 0;
}

// Jacked from skeet announce
bool:IsGrounded(client)
{
	return (GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONGROUND) > 0;
}
/*
PrintToTeamConsole(teamflag, const String:format[], any:...)
{
	decl String:buffer[1024];

	for(new i = 1;i <= MaxClients;i++)
	{
		if(IsClientInGame(i) && (!teamflag || teamflag & (1 << GetClientTeam(i))))
		{
			VFormat(buffer, sizeof(buffer), format, 3);
			PrintToConsole(i, buffer);
		}
	}
}
*/
public OnEntityCreated ( entity, const String:classname[] )
{
    if ( entity < 1 || !IsValidEntity(entity) || !IsValidEdict(entity) ) { return; }
    
    // track infected / witches, so damage on them counts as hits
    
    new strOEC: classnameOEC;
    if (!GetTrieValue(g_hTrieEntityCreated, classname, classnameOEC)) { return; }
    
    switch ( classnameOEC )
    {
        case OEC_TANKROCK:
        {
            decl String:rock_key[10];
            FormatEx(rock_key, sizeof(rock_key), "%x", entity);
            new rock_array[3];
            
            // store which tank is throwing what rock
            new tank = ShiftTankThrower();
            
            if ( IS_VALID_INGAME(tank) )
            {
                g_iTankRock[tank] = entity;
                rock_array[rckTank] = tank;
            }
            SetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array), true);
			
            SDKHook(entity, SDKHook_TraceAttack, TraceAttack_Rock);
            SDKHook(entity, SDKHook_Touch, OnTouch_Rock);
        }
    }
}

stock ShiftTankThrower()
{
    new tank = -1;
    
    if ( !g_iRocksBeingThrownCount ) { return -1; }
    
    tank = g_iRocksBeingThrown[0];
    
    // shift the tank array downwards, if there are more than 1 throwers
    if ( g_iRocksBeingThrownCount > 1 )
    {
        for ( new x = 1; x <= g_iRocksBeingThrownCount; x++ )
        {
            g_iRocksBeingThrown[x-1] = g_iRocksBeingThrown[x];
        }
    }
    
    g_iRocksBeingThrownCount--;
    
    return tank;
}

// tank rock
public Action: TraceAttack_Rock (victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
    if ( IS_VALID_SURVIVOR(attacker) )
    {
        /*
            can't really use this for precise detection, though it does
            report the last shot -- the damage report is without distance falloff
        */
        decl String:rock_key[10];
        decl rock_array[3];
        FormatEx(rock_key, sizeof(rock_key), "%x", victim);
        GetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array));
        rock_array[rckDamage] += RoundToFloor(damage);
        rock_array[rckSkeeter] = attacker;
        SetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array), true);
    }
}

public OnTouch_Rock ( entity )
{
    // remember that the rock wasn't shot
    decl String:rock_key[10];
    FormatEx(rock_key, sizeof(rock_key), "%x", entity);
    new rock_array[3];
    rock_array[rckDamage] = -1;
    SetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array), true);
    
    SDKUnhook(entity, SDKHook_Touch, OnTouch_Rock);
}

// entity destruction
public OnEntityDestroyed ( entity )
{
	decl String:witch_key[10];
	FormatEx(witch_key, sizeof(witch_key), "%x", entity);
	decl rock_array[3];
	if (GetTrieArray(g_hRockTrie, witch_key, rock_array, sizeof(rock_array)) )
	{
		// tank rock
		CreateTimer( ROCK_CHECK_TIME, Timer_CheckRockSkeet, entity );
		SDKUnhook(entity, SDKHook_TraceAttack, TraceAttack_Rock);
		return;
	}
}

public Action: Timer_CheckRockSkeet (Handle:timer, any:rock)
{
    decl rock_array[3];
    decl String: rock_key[10];
    FormatEx(rock_key, sizeof(rock_key), "%x", rock);
    if ( !GetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array)) ) { return Plugin_Continue; }
    
    RemoveFromTrie(g_hRockTrie, rock_key);
    
    // if rock didn't hit anyone / didn't touch anything, it was shot
    if ( rock_array[rckDamage] > 0 )
    {
        HandleRockSkeeted( rock_array[rckSkeeter], rock_array[rckTank] );
    }
    
    return Plugin_Continue;
}
// rocks
HandleRockEaten( attacker, victim )
{
    Call_StartForward(g_hForwardRockEaten);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_Finish();
}

HandleRockSkeeted( attacker, victim )
{
    // report?

    /*
    if ( IS_VALID_INGAME(attacker) && IS_VALID_INGAME(victim) && !IsFakeClient(victim) )
    {
	  CPrintToChatAll( "[{olive}TS{default}] {olive}%N{default} skeeted {green}%N{default}'s rock.", attacker, victim );
    }
    else if ( IS_VALID_INGAME(attacker) )
    {
	}
    */
    CPrintToChatAll( "[{olive}TS{default}] {olive}%N{default} skeeted a tank rock.", attacker );
    
    
    Call_StartForward(g_hForwardRockSkeeted);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_Finish();
}