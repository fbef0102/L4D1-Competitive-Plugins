#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#define DEBUG 0

enum WeaponID
{
	ID_NONE,
	ID_PISTOL,
	ID_DUAL_PISTOL,
	ID_SMG,
	ID_PUMPSHOTGUN,
	ID_RIFLE,
	ID_AUTOSHOTGUN,
	ID_HUNTING_RIFLE
}
char Weapon_Name[WeaponID][32];
int WeaponAmmoOffest[WeaponID];
int WeaponMaxClip[WeaponID];

//cvars
Handle hEnableReloadClipCvar;
Handle hEnableClipRecoverCvar;
Handle hSmgTimeCvar;
Handle hRifleTimeCvar;
Handle hHuntingRifleTimeCvar;
Handle hPistolTimeCvar;
Handle hDualPistolTimeCvar;
float g_EnableReloadClipCvar;
float g_EnableClipRecoverCvar;
float g_SmgTimeCvar;
float g_RifleTimeCvar;
float g_HuntingRifleTimeCvar;
float g_PistolTimeCvar;
float g_DualPistolTimeCvar;

//value
float g_hClientReload_Time[MAXPLAYERS+1]	= {0.0};	

//offest
int ammoOffset;	
											
public Plugin:myinfo = 
{
	name = "weapon csgo reload",
	author = "Harry Potter",
	description = "reload like csgo weapon",
	version = "1.2",
	url = "Harry Potter myself,you bitch shit"
};

public void OnPluginStart()
{
	hEnableReloadClipCvar	= CreateConVar("l4d_enable_reload_clip", 			"1", 	"enable this plugin?[1-Enable,0-Disable]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hEnableClipRecoverCvar	= CreateConVar("l4d_enable_clip_recover", 			"1", 	"enable previous clip recover?"			 , FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hSmgTimeCvar			= CreateConVar("l4d_smg_reload_clip_time", 			"1.65", "reload time for smg clip"				 , FCVAR_NOTIFY);
	hRifleTimeCvar			= CreateConVar("l4d_rifle_reload_clip_time", 		"1.2",  "reload time for rifle clip"			 , FCVAR_NOTIFY);
	hHuntingRifleTimeCvar   = CreateConVar("l4d_huntingrifle_reload_clip_time", "2.6",  "reload time for hunting rifle clip"	 , FCVAR_NOTIFY);
	hPistolTimeCvar 		= CreateConVar("l4d_pistol_reload_clip_time", 		"1.5",  "reload time for pistol clip"		     , FCVAR_NOTIFY);
	hDualPistolTimeCvar 	= CreateConVar("l4d_dualpistol_reload_clip_time", 	"2.1",  "reload time for dual pistol clip"       , FCVAR_NOTIFY);
	
	g_EnableReloadClipCvar  = GetConVarFloat(hEnableReloadClipCvar);
	g_EnableClipRecoverCvar = GetConVarFloat(hEnableClipRecoverCvar);
	g_SmgTimeCvar = GetConVarFloat(hSmgTimeCvar);
	g_RifleTimeCvar = GetConVarFloat(hRifleTimeCvar);
	g_HuntingRifleTimeCvar = GetConVarFloat(hHuntingRifleTimeCvar);
	g_PistolTimeCvar = GetConVarFloat(hPistolTimeCvar);
	g_DualPistolTimeCvar = GetConVarFloat(hDualPistolTimeCvar);
	
	HookConVarChange(hEnableReloadClipCvar, ConVarChange_hEnableReloadClipCvar);
	HookConVarChange(hEnableClipRecoverCvar, ConVarChange_hEnableClipRecoverCvar);
	HookConVarChange(hSmgTimeCvar, ConVarChange_hSmgTimeCvar);
	HookConVarChange(hRifleTimeCvar, ConVarChange_hRifleTimeCvar);
	HookConVarChange(hHuntingRifleTimeCvar, ConVarChange_hHuntingRifleTimeCvar);
	HookConVarChange(hPistolTimeCvar, ConVarChange_hPistolTimeCvar);
	HookConVarChange(hDualPistolTimeCvar, ConVarChange_hDualPistolTimeCvar);
	
	HookEvent("weapon_reload", OnWeaponReload_Event, EventHookMode_Post);
	HookEvent("round_start", RoundStart_Event);
	
	ammoOffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");
	
	SetWeapon();
}

public Action:RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		g_hClientReload_Time[i] = 0.0;
	}
}

public void SetWeapon()
{
	Weapon_Name[ID_NONE] = "";
	Weapon_Name[ID_PISTOL] = "weapon_pistol";
	Weapon_Name[ID_DUAL_PISTOL] = "weapon_pistol";
	Weapon_Name[ID_SMG] = "weapon_smg";
	Weapon_Name[ID_PUMPSHOTGUN] = "weapon_pumpshotgun";
	Weapon_Name[ID_RIFLE] = "weapon_rifle";
	Weapon_Name[ID_AUTOSHOTGUN] = "weapon_autoshotgun";
	Weapon_Name[ID_HUNTING_RIFLE] = "weapon_hunting_rifle";

	WeaponAmmoOffest[ID_NONE] = 0;
	WeaponAmmoOffest[ID_PISTOL] = 0;
	WeaponAmmoOffest[ID_DUAL_PISTOL] = 0;
	WeaponAmmoOffest[ID_SMG] = 5;
	WeaponAmmoOffest[ID_PUMPSHOTGUN] = 6;
	WeaponAmmoOffest[ID_RIFLE] = 3;
	WeaponAmmoOffest[ID_AUTOSHOTGUN] = 6;
	WeaponAmmoOffest[ID_HUNTING_RIFLE] = 2;

	WeaponMaxClip[ID_NONE] = 0;
	WeaponMaxClip[ID_PISTOL] = 15;
	WeaponMaxClip[ID_DUAL_PISTOL] = 30;
	WeaponMaxClip[ID_SMG] = 50;
	WeaponMaxClip[ID_PUMPSHOTGUN] = 8;
	WeaponMaxClip[ID_RIFLE] = 50;
	WeaponMaxClip[ID_AUTOSHOTGUN] = 10;
	WeaponMaxClip[ID_HUNTING_RIFLE] = 15;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(g_EnableReloadClipCvar == 0 || g_EnableClipRecoverCvar == 0)	return Plugin_Continue;
	
	if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && buttons & IN_RELOAD) //If survivor alive player is holding weapon and wants to reload
	{
		int iCurrentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"); //抓人類目前裝彈的武器
		if (iCurrentWeapon == -1 || !IsValidEntity(iCurrentWeapon))
		{
			return Plugin_Continue;
		}
		
		if(GetEntProp(iCurrentWeapon, Prop_Send, "m_bInReload") == 0)
		{
			char sWeaponName[32];
			GetClientWeapon(client, sWeaponName, sizeof(sWeaponName));
			int previousclip = GetWeaponClip(iCurrentWeapon);
			#if DEBUG
				PrintToChatAll("%N - %s clip:%d",client,sWeaponName,previousclip);
			#endif
			WeaponID weaponid = GetWeaponID(iCurrentWeapon,sWeaponName);
			int MaxClip = WeaponMaxClip[weaponid];
			
			switch(weaponid)
			{
				case (WeaponID:ID_SMG),(WeaponID:ID_RIFLE),(WeaponID:ID_HUNTING_RIFLE):
				{
					if (0 < previousclip && previousclip < MaxClip)	//If the his current mag equals the maximum allowed, remove reload from buttons
					{
						Handle pack;
						CreateDataTimer(0.1, RecoverWeaponClip, pack, TIMER_FLAG_NO_MAPCHANGE);
						WritePackCell(pack, client);
						WritePackCell(pack, iCurrentWeapon);
						WritePackCell(pack, previousclip);
						WritePackCell(pack, weaponid);
					}
				}
				default:
					return Plugin_Continue;
			}
		}
	}
	return Plugin_Continue;
}

public Action RecoverWeaponClip(Handle timer, Handle pack)
{
	ResetPack(pack);
	int client = ReadPackCell(pack);
	int CurrentWeapon = ReadPackCell(pack);
	int previousclip = ReadPackCell(pack);
	WeaponID weaponid = ReadPackCell(pack);
	int nowweaponclip;
	
	if (CurrentWeapon == -1 || //CurrentWeapon drop
	!IsValidEntity(CurrentWeapon) ||
	client == 0 || //client disconnected
	!IsClientInGame(client) || 
	!IsPlayerAlive(client) ||
	GetClientTeam(client)!=2 ||
	GetEntProp(CurrentWeapon, Prop_Send, "m_bInReload") == 0 || //reload interrupted
	(nowweaponclip = GetWeaponClip(CurrentWeapon)) == WeaponMaxClip[weaponid] || //CurrentWeapon complete reload finished
	nowweaponclip == previousclip //CurrentWeapon clip has been recovered
	)
	{
		return Plugin_Handled;
	}
	
	if (nowweaponclip < WeaponMaxClip[weaponid] && nowweaponclip == 0)
	{
		int ammo = GetWeaponAmmo(client, WeaponAmmoOffest[weaponid]);
		ammo -= previousclip;
		#if DEBUG
			PrintToChatAll("CurrentWeapon clip recovered");
		#endif
		SetWeaponAmmo(client,WeaponAmmoOffest[weaponid],ammo);
		SetWeaponClip(CurrentWeapon,previousclip);
	}
	return Plugin_Handled;
}

public Action OnWeaponReload_Event(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
		
	if (client < 1 || 
		client > MaxClients ||
		!IsClientInGame(client) ||
		IsFakeClient(client) ||
		GetClientTeam(client) != 2 ||
		g_EnableReloadClipCvar == 0) //disable this plugin
		return Plugin_Continue;
	

	int iCurrentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"); //抓人類目前裝彈的武器
	if (iCurrentWeapon == -1 || !IsValidEntity(iCurrentWeapon))
	{
		return Plugin_Continue;
	}
	
	g_hClientReload_Time[client] = GetEngineTime();
	
	char sWeaponName[32];
	GetClientWeapon(client, sWeaponName, sizeof(sWeaponName));
	WeaponID weaponid = GetWeaponID(iCurrentWeapon,sWeaponName);
	int ammo = GetWeaponAmmo(client, WeaponAmmoOffest[weaponid]);
	#if DEBUG
		PrintToChatAll("%N - %s ammo:%d",client,sWeaponName,ammo);
		for (int i = 0; i < 32; i++)
		{
			PrintToConsole(client, "Offset: %i - Count: %i", i, GetEntData(client, ammoOffset+(i*4)));
		} 
	#endif
	
	Handle pack;
	switch(weaponid)
	{
		case (WeaponID:ID_SMG): CreateDataTimer(g_SmgTimeCvar, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
		case (WeaponID:ID_RIFLE): CreateDataTimer(g_RifleTimeCvar, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
		case (WeaponID:ID_HUNTING_RIFLE): CreateDataTimer(g_HuntingRifleTimeCvar, WeaponReloadClip, pack,TIMER_FLAG_NO_MAPCHANGE);
		case (WeaponID:ID_PISTOL): CreateDataTimer(g_PistolTimeCvar, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
		case (WeaponID:ID_DUAL_PISTOL): CreateDataTimer(g_DualPistolTimeCvar, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
		default: return Plugin_Continue;
	}
	WritePackCell(pack, client);
	WritePackCell(pack, iCurrentWeapon);
	WritePackCell(pack, ammo);
	WritePackCell(pack, weaponid);
	WritePackCell(pack, g_hClientReload_Time[client]);
	
	
	return Plugin_Continue;
}

public Action WeaponReloadClip(Handle timer, Handle pack)
{
	ResetPack(pack);
	int client = ReadPackCell(pack);
	int CurrentWeapon = ReadPackCell(pack);
	int ammo = ReadPackCell(pack);
	WeaponID weaponid = ReadPackCell(pack);
	float reloadtime = ReadPackCell(pack);
	int nowsmgclip;
	
	if ( reloadtime != g_hClientReload_Time[client] || //裝彈時間被刷新
	CurrentWeapon == -1 || //CurrentWeapon drop
	!IsValidEntity(CurrentWeapon) || 
	client == 0 || //client disconnected
	!IsClientInGame(client) ||
	!IsPlayerAlive(client) ||
	GetClientTeam(client)!=2 ||
	GetEntProp(CurrentWeapon, Prop_Send, "m_bInReload") == 0 || //reload interrupted
	(nowsmgclip = GetWeaponClip(CurrentWeapon)) == WeaponMaxClip[weaponid] //CurrentWeapon complete reload finished
	)
	{
		return Plugin_Handled;
	}
	
	if (nowsmgclip < WeaponMaxClip[weaponid])
	{
		switch(weaponid)
		{
			case (WeaponID:ID_SMG),(WeaponID:ID_RIFLE),(WeaponID:ID_HUNTING_RIFLE):
			{
				ammo -= WeaponMaxClip[weaponid];
				#if DEBUG
					PrintToChatAll("CurrentWeapon reload clip completed");
				#endif
				SetWeaponAmmo(client,WeaponAmmoOffest[weaponid],ammo);
				SetWeaponClip(CurrentWeapon,WeaponMaxClip[weaponid]);
			}
			case (WeaponID:ID_PISTOL),(WeaponID:ID_DUAL_PISTOL):
			{
				#if DEBUG
					PrintToChatAll("Pistol reload clip completed");
				#endif
				SetWeaponClip(CurrentWeapon,WeaponMaxClip[weaponid]);
			}
			default:
			{
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Handled;
}

public void ConVarChange_hEnableReloadClipCvar(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_EnableReloadClipCvar  = GetConVarFloat(hEnableReloadClipCvar);
}
public void ConVarChange_hEnableClipRecoverCvar(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_EnableClipRecoverCvar = GetConVarFloat(hEnableClipRecoverCvar);
}
public void ConVarChange_hSmgTimeCvar(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_SmgTimeCvar = GetConVarFloat(hSmgTimeCvar);
}
public void ConVarChange_hRifleTimeCvar(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_RifleTimeCvar = GetConVarFloat(hRifleTimeCvar);
}
public void ConVarChange_hHuntingRifleTimeCvar(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_HuntingRifleTimeCvar = GetConVarFloat(hHuntingRifleTimeCvar);
}
public void ConVarChange_hPistolTimeCvar(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_PistolTimeCvar = GetConVarFloat(hPistolTimeCvar);
}
public void ConVarChange_hDualPistolTimeCvar(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_DualPistolTimeCvar = GetConVarFloat(hDualPistolTimeCvar);
}

stock GetWeaponAmmo(int client, int offest)
{
    return GetEntData(client, ammoOffset+(offest*4));
} 

stock GetWeaponClip(int weapon)
{
    return GetEntProp(weapon, Prop_Send, "m_iClip1");
} 

stock void SetWeaponAmmo(int client, int offest, int ammo)
{
    SetEntData(client, ammoOffset+(offest*4), ammo);
} 
stock void SetWeaponClip(int weapon, int clip)
{
	SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
} 
stock WeaponID GetWeaponID(int weapon,const char[] weapon_name)
{
	if(StrEqual(weapon_name,Weapon_Name[ID_DUAL_PISTOL],false) && GetEntProp(weapon, Prop_Send, "m_hasDualWeapons"))
	{
		return WeaponID:ID_DUAL_PISTOL;
	}
	else if(StrEqual(weapon_name,Weapon_Name[ID_PISTOL],false))
	{
		return WeaponID:ID_PISTOL;
	}
	else if(StrEqual(weapon_name,Weapon_Name[ID_SMG],false))
	{
		return WeaponID:ID_SMG;
	}
	else if(StrEqual(weapon_name,Weapon_Name[ID_PUMPSHOTGUN],false))
	{
		return WeaponID:ID_PUMPSHOTGUN;
	}
	else if(StrEqual(weapon_name,Weapon_Name[ID_RIFLE],false))
	{
		return WeaponID:ID_RIFLE;
	}
	else if(StrEqual(weapon_name,Weapon_Name[ID_AUTOSHOTGUN],false))
	{
		return WeaponID:ID_AUTOSHOTGUN;
	}
	else if(StrEqual(weapon_name,Weapon_Name[ID_HUNTING_RIFLE],false))
	{
		return WeaponID:ID_HUNTING_RIFLE;
	}
	return WeaponID:ID_NONE;
}