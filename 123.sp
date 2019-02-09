#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4downtown>
#include <l4d_direct>
#include <colors>


#define TEAM_SPECTATOR      1
#define TEAM_SURVIVOR       2
#define TEAM_INFECTED       3

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1)   (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))

#define TIMEOUT_TIME    30
#define MAX_PLY         48


// globals
new     bool:   g_bRoundIsLive = false;

new             g_iTeamSize = 4;

new             g_iPreviousCount[4];                // for each GetClientTeam(), the # players in it
new             g_iPreviousTeams[4][MAX_PLY];       // for each GetClientTeam(), the players in it

// voting
new     bool:   g_bSrvVoted = false;                // whether anyone in survivor team voted using the command
new     bool:   g_bInfVoted = false;
new             g_iTimeout = 0;                     // how long to wait until a 'time out' is assumed, seconds
new g_iMixTimeout = 0;
native IsInReady();
native Is_Ready_Plugin_On();
#define L4D_TEAM_SURVIVORS 2
#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SPECTATE 1

public Plugin:myinfo = {
    name = "Team Shuffle & Mix",
    author = "Tabun & Zen & Sir (L4D1 port by Harry)",
    description = "Allows teamshuffles and Mix by voting or admin-forced during readyup.",
    version = "1.0",
    url = "none"
};

public OnPluginStart ()
{
    // events    
    HookEvent("round_start",                Event_RoundStart,               EventHookMode_PostNoCopy);
    
    // commands:
    RegConsoleCmd( "sm_teamshuffle", Cmd_TeamShuffle, "Vote for a team shuffle.");
	RegConsoleCmd( "sm_shuffle", Cmd_TeamShuffle, "Vote for a team shuffle." );
	RegConsoleCmd( "sm_mix", Cmd_Mix, "Vote for a Mix" );
	RegAdminCmd("sm_forceteamshuffle", Cmd_ForceTeamShuffle,ADMFLAG_BAN,"Shuffle the teams. Only works during readyup. Admins only.");
	RegAdminCmd("sm_forceshuffle", Cmd_ForceTeamShuffle,ADMFLAG_BAN,"Shuffle the teams. Only works during readyup. Admins only.");
}

public Action: Cmd_Mix ( client, args )
{
    if ( !Is_Ready_Plugin_On() || !IsInReady() )
    {
        if ( client == 0 ) {
            PrintToServer( "[Mix] Start Mix when round is not live.(ready stage)" );
        } else {
            PrintToChat( client, "[Mix] Start Mix when round is not live.(ready stage)" );
        }
        return Plugin_Handled;
    }
	
	if ( g_iMixTimeout != 0 && GetTime() < g_iMixTimeout )
    {
        if ( client == 0 ) {
            PrintToServer( "[Mix] Too soon after previous teamshuffle. (Wait %is).", (g_iMixTimeout - GetTime()) );
        } else {
            PrintToChat( client, "\x01[Mix] Too soon after previous teamshuffle. (Wait \x05%i\x01s).", (g_iMixTimeout - GetTime()) );
        }
        return Plugin_Handled;
    }
    
    //MixVote( client );
    return Plugin_Handled;
}

public Action: Cmd_TeamShuffle ( client, args )
{
    if ( !Is_Ready_Plugin_On() || !IsInReady() )
    {
        if ( client == 0 ) {
            PrintToServer( "[Shuffle] Teams can only be shuffled when round is not live.(ready stage)" );
        } else {
            PrintToChat( client, "\x01[Shuffle] Teams can only be shuffled when round is not live.(ready stage)" );
        }
        return Plugin_Handled;
    }
	
	if ( g_iTimeout != 0 && GetTime() < g_iTimeout )
    {
        if ( client == 0 ) {
            PrintToServer( "[Shuffle] Too soon after previous teamshuffle. (Wait %is).", (g_iTimeout - GetTime()) );
        } else {
            PrintToChat( client, "\x01[Shuffle] Too soon after previous teamshuffle. (Wait \x05%i\x01s).", (g_iTimeout - GetTime()) );
        }
        return Plugin_Handled;
    }
	
    /*
        maybe argument for 'schemes'?
    new String: sArg[24];
    if ( args )
    {
        GetCmdArg( 1, sArg, sizeof(sArg) );
    }
    else
    {
        sArg = "a";
    }
    */
    
    TeamShuffleVote( client );
    return Plugin_Handled;
}

public Action: Cmd_ForceTeamShuffle ( client, args )
{
    ShuffleTeams(client,true);
    return Plugin_Handled;
}

public Event_RoundStart (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    g_bRoundIsLive = false;
    g_bSrvVoted = false;
    g_bInfVoted = false;
    g_iTimeout = GetTime() + 5;
}

stock TeamShuffleVote ( client )
{
    if ( !IS_VALID_SURVIVOR(client) && !IS_VALID_INFECTED(client) ) { return; }
    
    if ( g_bSrvVoted && g_bInfVoted)
    {
        PrintToChat(client, "\x01Shuffle is already in progress!");
        return;
    }
    
    // status?
    if ( GetClientTeam(client) == TEAM_SURVIVOR )
    {
        if ( g_bInfVoted)
        {
            // survivors respond
            if ( !g_bSrvVoted)
            {
                g_bSrvVoted = true;
                CPrintToChatAll("[Shuffle] {blue}The Survivors{default} have agreed to start the {green}team shuffle{default}. Shuffling in {green}3 {default}seconds.", client);
                CreateTimer( 3.0, Timer_ShuffleTeams, _, TIMER_FLAG_NO_MAPCHANGE );
            }
        }
        else
        {
            // survivors first
            if ( !g_bSrvVoted )
            {
                g_bSrvVoted = true;
                PrintToChatAll("[Shuffle] {blue}The Survivors{default} have requested to start a {green}team shuffle{default}.");
				PrintToChatAll("{red}The Infected{default} must agree by typing {green}!shuffle{default}.", client);
            }
        }
    }
    else
    {
        if ( g_bSrvVoted )
        {
            // infected respond
            if ( !g_bInfVoted )
            {
                g_bInfVoted = true;
                PrintToChatAll("\x05%N\x01 (\x04Infected\x01) accepted the team shuffle. Shuffling in 3 seconds.", client);
                CreateTimer(3.0, Timer_ShuffleTeams, _, TIMER_FLAG_NO_MAPCHANGE);
            }
        } else {
            // Infected first
            if ( !g_bInfVoted )
            {
                g_bInfVoted = true;
                PrintToChatAll("\x05%N\x01 (\x04Infected\x01) voted for a team shuffle. Survivors can \x04!teamshuffle\x01 to accept.", client);
            }
        }
    }
}

public Action: Timer_ShuffleTeams ( Handle:timer )
{
    g_bSrvVoted = false;
    g_bInfVoted = false;
    ShuffleTeams();
}

stock ShuffleTeams ( client = -1 , bool: adm = false)
{
     if ( !Is_Ready_Plugin_On() || !IsInReady() )
    {
        if (client == -1) {
            PrintToChatAll("\x01[Shuffle] Team shuffle only allowed before a round is live.(ready stage)");
        } else {
            PrintToChat(client, "\x01[Shuffle] Team shuffle only allowed before a round is live.(ready stage)");
        }
        return;
    }
    
    g_iTeamSize = GetConVarInt( FindConVar("survivor_limit") );
    
    // save current player / team setup
    new tmpTeam;
    for ( new i = 1; i <= MaxClients; i++ )
    {
        if ( !IS_VALID_INGAME( i ) || IsFakeClient(i) ) { continue; }
        
        tmpTeam = GetClientTeam(i);
        g_iPreviousTeams[tmpTeam][ g_iPreviousCount[tmpTeam] ] = i;
        g_iPreviousCount[tmpTeam]++;
    }
    
    // check amount
    new iTotal = g_iPreviousCount[TEAM_SURVIVOR] + g_iPreviousCount[TEAM_INFECTED];
    new bool: bSpecs = false;
    new i, j;
    
    if ( iTotal < (2 * g_iTeamSize) )
    {
        iTotal += g_iPreviousCount[TEAM_SPECTATOR];
        bSpecs = true;
    }
    
	new freeslots = GetTeamMaxHumans(2)+GetTeamMaxHumans(3);
	new UsedSlots = GetTeamHumanCount(2)+GetTeamHumanCount(3);
	if(freeslots != UsedSlots)
	{
        PrintToChatAll("[Shuffle] Can't shuffle, both team must be full first");
    }
    
	if(adm)
	{
		CPrintToChatAll("[Shuffle] {lightgreen}%N {default}has forced the team shuffle");
	}
	
    // move specs to teams, to see available totals
    if ( bSpecs )
    {
        for ( j = TEAM_SURVIVOR; j <= TEAM_INFECTED; j++ )
        {
            while ( g_iPreviousCount[j] < g_iTeamSize && g_iPreviousCount[TEAM_SPECTATOR] > 0 )
            {
                g_iPreviousCount[TEAM_SPECTATOR]--;
                g_iPreviousTeams[j][ g_iPreviousCount[j] ] = g_iPreviousTeams[TEAM_SPECTATOR][ g_iPreviousCount[TEAM_SPECTATOR] ];
                g_iPreviousCount[j]++;
            }
        }
    }
    
    
    // if there are uneven players, move one to the other
    new tmpDif = g_iPreviousCount[TEAM_SURVIVOR] - g_iPreviousCount[TEAM_INFECTED];
    if ( tmpDif > 1 )
    {
        g_iPreviousCount[TEAM_SURVIVOR]--;
        g_iPreviousTeams[TEAM_INFECTED][ g_iPreviousCount[TEAM_INFECTED] ] = g_iPreviousTeams[TEAM_SURVIVOR][ g_iPreviousCount[TEAM_SURVIVOR] ];
        g_iPreviousCount[TEAM_INFECTED]++;
        
    }
    else if ( tmpDif < -1 )
    {
        g_iPreviousCount[TEAM_INFECTED]--;
        g_iPreviousTeams[TEAM_SURVIVOR][ g_iPreviousCount[TEAM_SURVIVOR] ] = g_iPreviousTeams[TEAM_INFECTED][ g_iPreviousCount[TEAM_INFECTED] ];
        g_iPreviousCount[TEAM_SURVIVOR]++;
    }
    
    // if the teams are too full (for whatever glitchy reason), truncate
    for ( j = TEAM_SURVIVOR; j <= TEAM_INFECTED; j++ )
    {
        while( g_iPreviousCount[j] > g_iTeamSize )
        {
            g_iPreviousCount[j]--;
            g_iPreviousTeams[TEAM_SPECTATOR][ g_iPreviousCount[TEAM_SPECTATOR] ] = g_iPreviousTeams[j][ g_iPreviousCount[j] ];
            g_iPreviousCount[TEAM_SPECTATOR]++;
        }
    }
    
    // do shuffle: swap at least teamsize/2 rounded up players
    new bool: bShuffled[MAXPLAYERS+1];
    new iShuffleCount = RoundToCeil( float( (g_iPreviousCount[TEAM_INFECTED] > g_iPreviousCount[TEAM_SURVIVOR]) ? g_iPreviousCount[TEAM_INFECTED] : g_iPreviousCount[TEAM_SURVIVOR]  ) / 2.0 );
    
    new pickA, pickB;
    new spotA, spotB;
    
    for ( j = 0; j < iShuffleCount; j++ )
    {
        pickA = -1;
        pickB = -1;
        
        while ( pickA == -1 || bShuffled[pickA] ) {
            spotA = GetRandomInt( 0, g_iPreviousCount[TEAM_SURVIVOR] - 1 );
            pickA = g_iPreviousTeams[TEAM_SURVIVOR][ spotA ];
        }
        while ( pickB == -1 || bShuffled[pickB] ) {
            spotB = GetRandomInt( 0, g_iPreviousCount[TEAM_INFECTED] - 1 );
            pickB = g_iPreviousTeams[TEAM_INFECTED][ spotB ];
        }
        
        bShuffled[pickA] = true;
        bShuffled[pickB] = true;
        
        g_iPreviousTeams[TEAM_SURVIVOR][spotA] = pickB;
        g_iPreviousTeams[TEAM_INFECTED][spotB] = pickA;
    }
    
    // set all players to spec
    for ( i = 1; i <= MaxClients; i++ )
    {
        if ( !IS_VALID_INGAME(i) || IsFakeClient(i) ) { continue; }
        ChangePlayerTeam( i, TEAM_SPECTATOR );
    }
    
    // now place all the players in the teams according to previousteams (silly name now, but ok)
    for ( j = TEAM_SURVIVOR; j <= TEAM_INFECTED; j++ )
    {
        for ( i = 0; i < g_iPreviousCount[j]; i++ )
        {
            ChangePlayerTeam( g_iPreviousTeams[j][i], j );
        }
    }
    
    PrintToChatAll("\x01Teams were shuffled.");
    
    // set timeout
    g_iTimeout = GetTime() + TIMEOUT_TIME;
    
}

/*      Helper functions
        ----------------    */

stock bool: ChangePlayerTeam(client, team )
{
    if ( !IS_VALID_INGAME(client) || GetClientTeam(client) == team )
    {
        return true;
    }
    
    if ( team != TEAM_SURVIVOR )
    {
        ChangeClientTeam( client, team );
        return true;
    }
    else
    {
        new bot = FindSurvivorBot();
        if ( bot > 0 )
        {
            CheatCommand( client, "sb_takecontrol", "" );
            return true;
        }
    }
    return false;
}

stock FindSurvivorBot()
{
    for ( new client = 1; client <= MaxClients; client++ )
    {
        if ( IS_VALID_SURVIVOR(client) && IsFakeClient(client) )
        {
            return client;
        }
    }
    return -1;
}

CheatCommand(client, const String:command[], const String:arguments[])
{
    if ( !client ) { return; }
    
    new admindata = GetUserFlagBits(client);
    SetUserFlagBits(client, ADMFLAG_ROOT);
    
    new flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    
    FakeClientCommand(client, "%s %s", command, arguments);
    
    SetCommandFlags(command, flags);
    SetUserFlagBits(client, admindata);
}

stock GetTeamMaxHumans(team)
{
	if(team == 2)
	{
		return GetConVarInt(FindConVar("survivor_limit"));
	}
	else if(team == 3)
	{
		return GetConVarInt(FindConVar("z_max_player_zombies"));
	}
	
	return -1;
}

stock GetTeamHumanCount(team)
{
	new humans = 0;
	
	new i;
	for(i = 1; i < (MaxClients + 1); i++)
	{
		if(IsClientInGameHuman(i) && GetClientTeam(i) == team)
		{
			humans++;
		}
	}
	
	return humans;
}

bool:IsClientInGameHuman(client)
{
	return IsClientInGame(client) && !IsFakeClient(client) && ((GetClientTeam(client) == L4D_TEAM_SURVIVORS || GetClientTeam(client) == L4D_TEAM_INFECTED));
}
