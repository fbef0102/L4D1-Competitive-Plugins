#include <sourcemod>
#include <sdktools>

#define VOICE_NORMAL	0	/**< Allow the client to listen and speak normally. */
#define VOICE_MUTED		1	/**< Mutes the client from speaking to everyone. */
#define VOICE_SPEAKALL	2	/**< Allow the client to speak to everyone. */
#define VOICE_LISTENALL	4	/**< Allow the client to listen to everyone. */
#define VOICE_TEAM		8	/**< Allow the client to always speak to team, even when dead. */
#define VOICE_LISTENTEAM	16	/**< Allow the client to always hear teammates, including dead ones. */

#define TEAM_SPEC 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

//new Handle:hAllTalk;
static bool:bListionActive[MAXPLAYERS + 1];
native Is_Ready_Plugin_On();
#define PLUGIN_VERSION "3.0"
public Plugin:myinfo = 
{
	name = "SpecLister",
	author = "waertf & bear modded by bman, l4d1 versus port by harry",
	description = "Allows spectator listen others team voice for l4d",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=95474"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("OpenSpectatorsListenMode", Native_OpenSpectatorsListenMode);
	return APLRes_Success;
}

public Native_OpenSpectatorsListenMode(Handle:plugin, numParams) {
  
	for (new client = 1; client <= MaxClients; client++)
		if (IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client) && GetClientTeam(client) == TEAM_SPEC)
		{
			if(bListionActive[client])
			{
				SetClientListeningFlags(client, VOICE_LISTENALL);
				//PrintToChat(client,"\x01[\x04Spectators\x01] \x03Listen Mode \x05On.");
				//PrintToChat(client,"\x05(You can see what\x04 Survivor\x05 and\x04 Infected\x05 type via chat box, and what they say via mic)" );
				PrintToChat(client,"\x01[\x04Spectators\x01] \x05type \x04!hear \x05Off \x03Listen Mode\x05." );
			}
			else
			{
				SetClientListeningFlags(client, VOICE_NORMAL);
				//PrintToChat(client,"\x01[\x04Spectators\x01] \x03Listen Mode \x05Off.");
				PrintToChat(client,"\x01[\x04Spectators\x01] \x05type \x04!hear \x05On \x03Listen Mode\x05." );
			}
		}
		
}

 public OnPluginStart()
{
	HookEvent("player_team",Event_PlayerChangeTeam);
	HookEvent("player_left_start_area", LeftStartAreaEvent, EventHookMode_PostNoCopy);
	RegConsoleCmd("hear", Panel_hear);
	
	//Fix for End of round all-talk.
	//hAllTalk = FindConVar("sv_alltalk");
	//HookConVarChange(hAllTalk, OnAlltalkChange);
	
	//Spectators hear Team_Chat
	RegConsoleCmd("say_team", Command_SayTeam);
	
	for (new i = 1; i <= MaxClients; i++) 
		bListionActive[i] = true;
}

public LeftStartAreaEvent(Handle:event, String:name[], bool:dontBroadcast)
{
	if(!Is_Ready_Plugin_On())
	{
		for (new client = 1; client <= MaxClients; client++)
			if (IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client) && GetClientTeam(client) == TEAM_SPEC)
			{
				if(bListionActive[client])
				{
					SetClientListeningFlags(client, VOICE_LISTENALL);
					//PrintToChat(client,"\x01[\x04Spectators\x01] \x03Listen Mode \x05On.");
					//PrintToChat(client,"\x05(You can see what\x04 Survivor\x05 and\x04 Infected\x05 type via chat box, and what they say via mic)" );
					PrintToChat(client,"\x01[\x04Spectators\x01] \x05type \x04!hear \x05Off \x03Listen Mode\x05." );
				}
				else
				{
					SetClientListeningFlags(client, VOICE_NORMAL);
					//PrintToChat(client,"\x01[\x04Spectators\x01] \x03Listen Mode \x05Off.");
					PrintToChat(client,"\x01[\x04Spectators\x01] \x05type \x04!hear \x05On \x03Listen Mode\x05." );
				}
			}
	}
}

public Action:Panel_hear(client,args)
{
	if(GetClientTeam(client)!=TEAM_SPEC)
		return Plugin_Handled;
		
	bListionActive[client] = !bListionActive[client];
	PrintToChat(client,"\x01[\x04Spectators\x01] \x03Listen Mode \x01is now %s\x01.", (bListionActive[client] ? "\x05On" : "\x05Off"));	
	
	if(bListionActive[client])
	{
		SetClientListeningFlags(client, VOICE_LISTENALL);
		PrintToChat(client,"\x05(You can see what\x04 Survivor\x05 and\x04 Infected\x05 type via chat box, and what they say via mic)" );
	}
	else
	{
		SetClientListeningFlags(client, VOICE_NORMAL);
	}
 
	return Plugin_Continue;

}

public Action:Command_SayTeam(client, args)
{
	if (client == 0)
		return Plugin_Continue;
		
	new String:buffermsg[256];
	new String:text[192];
	GetCmdArgString(text, sizeof(text));
	new senderteam = GetClientTeam(client);
	
	if(FindCharInString(text, '@') == 0)	//Check for admin messages
		return Plugin_Continue;
	
	new startidx = trim_quotes(text);  //Not sure why this function is needed.(bman)
	
	new String:name[32];
	GetClientName(client,name,31);
	
	new String:senderTeamName[10];
	switch (senderteam)
	{
		case 3:
			senderTeamName = "INFECTED"
		case 2:
			senderTeamName = "SURVIVORS"
		case 1:
			senderTeamName = "SPEC"
	}
	
	//Is not console, Sender is not on Spectators, and there are players on the spectator team
	if (client > 0 && senderteam != TEAM_SPEC && GetTeamClientCount(TEAM_SPEC) > 0)
	{
		for (new i = 1; i <= GetMaxClients(); i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SPEC)
			{
				switch (senderteam)	//Format the color different depending on team
				{
					case 3:
						Format(buffermsg, 256, "\x01(%s) \x04%s\x05: %s", senderTeamName, name, text[startidx]);
					case 2:
						Format(buffermsg, 256, "\x01(%s) \x03%s\x05: %s", senderTeamName, name, text[startidx]);
				}
				//Format(buffermsg, 256, "\x01(TEAM-%s) \x03%s\x05: %s", senderTeamName, name, text[startidx]);
				SayText2(i, client, buffermsg);	//Send the message to spectators
			}
		}
	}
	return Plugin_Continue;
}

stock SayText2(client_index, author_index, const String:message[] ) 
{
    new Handle:buffer = StartMessageOne("SayText2", client_index)
    if (buffer != INVALID_HANDLE) 
	{
        BfWriteByte(buffer, author_index)
        BfWriteByte(buffer, true)
        BfWriteString(buffer, message)
        EndMessage()
    }
} 

public trim_quotes(String:text[])
{
	new startidx = 0
	if (text[0] == '"')
	{
		startidx = 1
		/* Strip the ending quote, if there is one */
		new len = strlen(text);
		if (text[len-1] == '"')
		{
			text[len-1] = '\0'
		}
	}
	
	return startidx
}

public Event_PlayerChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userID = GetClientOfUserId(GetEventInt(event, "userid"));
	if(userID==0)
		return ;

	//PrintToChat(userID,"\x02X02 \x03X03 \x04X04 \x05X05 ");\\ \x02:color:default \x03:lightgreen \x04:orange \x05:darkgreen
	if(!IsFakeClient(userID)&&IsClientConnected(userID)&&IsClientInGame(userID))
		CreateTimer(1.0,PlayerChangeTeamCheck,userID);
}
public Action:PlayerChangeTeamCheck(Handle:timer,any:client)
{
	if(IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client))
		if(GetClientTeam(client)==TEAM_SPEC)
		{
			if(bListionActive[client])
			{
				SetClientListeningFlags(client, VOICE_LISTENALL);
				//PrintToChat(client,"\x01[\x04Spectators\x01] \x03Listen Mode \x05On.");
			}
			else
			{
				SetClientListeningFlags(client, VOICE_NORMAL);
				//PrintToChat(client,"\x01[\x04Spectators\x01] \x03Listen Mode \x05Off.");
			}
		}
		else
		{
			SetClientListeningFlags(client, VOICE_NORMAL);
			//PrintToChat(client,"\x04[listen]\x03disable" )
		}
}
/*
public OnAlltalkChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && GetClientTeam(i) == TEAM_SPEC)
			{
				SetClientListeningFlags(i, VOICE_LISTENALL);
				PrintToChat(i,"\x01[\x04Spectators\x01] \x03Listen Mode\x05Reset because of All-Talk.");
			}
		}
	}
}*/

public IsValidClient (client)
{
    if (client == 0)
        return false;
    
    if (!IsClientConnected(client))
        return false;
    
    if (IsFakeClient(client))
        return false;
    
    if (!IsClientInGame(client))
        return false;	
		
    return true;
}  