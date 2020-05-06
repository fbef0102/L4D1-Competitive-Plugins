#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#define CLASSNAME_LENGTH 	64
#define DEBUG 0
#pragma newdecls required //強制1.7以後的新語法

enum WeaponID
{
	ID_NONE,
	ID_PISTOL,
	ID_DUAL_PISTOL,
	ID_SMG,
	ID_PUMPSHOTGUN,
	ID_RIFLE,
	ID_AUTOSHOTGUN,
	ID_HUNTING_RIFLE,
	ID_WEAPON_MAX
}
#define PISTOL_RELOAD_INCAP_MULTIPLY 1.3
char Weapon_Name[view_as<int>(ID_WEAPON_MAX)][CLASSNAME_LENGTH];
int WeaponAmmoOffest[view_as<int>(ID_WEAPON_MAX)];
int WeaponMaxClip[view_as<int>(ID_WEAPON_MAX)];

//cvars
ConVar hEnableReloadClipCvar;
ConVar hEnableClipRecoverCvar;
ConVar hSmgTimeCvar;
ConVar hRifleTimeCvar;
ConVar hHuntingRifleTimeCvar;
ConVar hPistolTimeCvar;
ConVar hDualPistolTimeCvar;
bool g_EnableReloadClipCvar;
bool g_EnableClipRecoverCvar;
float g_SmgTimeCvar;
float g_RifleTimeCvar;
float g_HuntingRifleTimeCvar;
float g_PistolTimeCvar;
float g_DualPistolTimeCvar;

//value
float g_hClientReload_Time[MAXPLAYERS+1]	= {0.0};	

//offest
int ammoOffset;	
											
public Plugin myinfo = 
{
	name = "weapon csgo reload",
	author = "Harry Potter",
	description = "reload like csgo weapon",
	version = "1.7",
	url = "https://forums.alliedmods.net/showthread.php?t=318820"
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
	
	g_EnableReloadClipCvar  = hEnableReloadClipCvar.BoolValue;
	g_EnableClipRecoverCvar = hEnableClipRecoverCvar.BoolValue;
	g_SmgTimeCvar = hSmgTimeCvar.FloatValue;
	g_RifleTimeCvar = hRifleTimeCvar.FloatValue;
	g_HuntingRifleTimeCvar = hHuntingRifleTimeCvar.FloatValue;
	g_PistolTimeCvar = hPistolTimeCvar.FloatValue;
	g_DualPistolTimeCvar = hDualPistolTimeCvar.FloatValue;
	
	hEnableReloadClipCvar.AddChangeHook(ConVarChange_hEnableReloadClipCvar);
	hEnableClipRecoverCvar.AddChangeHook(ConVarChange_hEnableClipRecoverCvar);
	hSmgTimeCvar.AddChangeHook(ConVarChange_hSmgTimeCvar);
	hRifleTimeCvar.AddChangeHook(ConVarChange_hRifleTimeCvar);
	hHuntingRifleTimeCvar.AddChangeHook(ConVarChange_hHuntingRifleTimeCvar);
	hPistolTimeCvar.AddChangeHook(ConVarChange_hPistolTimeCvar);
	hDualPistolTimeCvar.AddChangeHook(ConVarChange_hDualPistolTimeCvar);
	
	HookEvent("weapon_reload", OnWeaponReload_Event, EventHookMode_Post);
	HookEvent("round_start", RoundStart_Event);
	
	ammoOffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");
	
	SetWeapon();
}

public Action RoundStart_Event(Event event, const char[] name, bool dontBroadcast) 
{
	for(int i = 1; i <= MaxClients; i++)
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
	if(g_EnableReloadClipCvar == false || g_EnableClipRecoverCvar == false)	return Plugin_Continue;
	
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
				case ID_SMG,ID_RIFLE,ID_HUNTING_RIFLE:
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
	!HasEntProp(CurrentWeapon, Prop_Send, "m_bInReload") ||
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
		g_EnableReloadClipCvar == false) //disable this plugin
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
	#if DEBUG
		PrintToChatAll("%N - %s - weaponid: %d",client,sWeaponName,weaponid);
		for (int i = 0; i < 32; i++)
		{
			PrintToConsole(client, "Offset: %i - Count: %i", i, GetEntData(client, ammoOffset+(i*4)));
		} 
	#endif
	
	Handle pack;
	switch(weaponid)
	{
		case ID_SMG: CreateDataTimer(g_SmgTimeCvar, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
		case ID_RIFLE: CreateDataTimer(g_RifleTimeCvar, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
		case ID_HUNTING_RIFLE: CreateDataTimer(g_HuntingRifleTimeCvar, WeaponReloadClip, pack,TIMER_FLAG_NO_MAPCHANGE);
		case ID_PISTOL: 
		{
			if(IsIncapacitated(client))
				CreateDataTimer(g_PistolTimeCvar * PISTOL_RELOAD_INCAP_MULTIPLY, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
			else
				CreateDataTimer(g_PistolTimeCvar, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		case ID_DUAL_PISTOL:
		{
			if(IsIncapacitated(client))
			    CreateDataTimer(g_DualPistolTimeCvar * PISTOL_RELOAD_INCAP_MULTIPLY, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
			else
				CreateDataTimer(g_DualPistolTimeCvar, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		default: return Plugin_Continue;
	}
	WritePackCell(pack, client);
	WritePackCell(pack, iCurrentWeapon);
	WritePackCell(pack, weaponid);
	WritePackCell(pack, g_hClientReload_Time[client]);
	
	
	return Plugin_Continue;
}

public Action WeaponReloadClip(Handle timer, Handle pack)
{
	ResetPack(pack);
	int client = ReadPackCell(pack);
	int CurrentWeapon = ReadPackCell(pack);
	WeaponID weaponid = ReadPackCell(pack);
	float reloadtime = ReadPackCell(pack);
	int clip;
	
	if ( reloadtime != g_hClientReload_Time[client] || //裝彈時間被刷新
	CurrentWeapon == -1 || //CurrentWeapon drop
	!IsValidEntity(CurrentWeapon) || 
	client == 0 || //client disconnected
	!IsClientInGame(client) ||
	!IsPlayerAlive(client) ||
	GetClientTeam(client)!=2 ||
	!HasEntProp(CurrentWeapon, Prop_Send, "m_bInReload") ||
	GetEntProp(CurrentWeapon, Prop_Send, "m_bInReload") == 0 || //reload interrupted
	(clip = GetWeaponClip(CurrentWeapon)) == WeaponMaxClip[weaponid] //CurrentWeapon complete reload finished
	)
	{
		return Plugin_Handled;
	}
		
	if (clip < WeaponMaxClip[weaponid])
	{
		switch(weaponid)
		{
			case ID_SMG,ID_RIFLE,ID_HUNTING_RIFLE:
			{
				#if DEBUG
					PrintToChatAll("CurrentWeapon reload clip completed");
				#endif
			
				int ammo = GetWeaponAmmo(client, WeaponAmmoOffest[weaponid]);
				if( (ammo - (WeaponMaxClip[weaponid] - clip)) <= 0)
				{
					clip = clip + ammo;
					ammo = 0;
				}
				else
				{
					ammo = ammo - (WeaponMaxClip[weaponid] - clip);
					clip = WeaponMaxClip[weaponid];
				}
				SetWeaponAmmo(client,WeaponAmmoOffest[weaponid],ammo);
				SetWeaponClip(CurrentWeapon,clip);
			}
			case ID_PISTOL,ID_DUAL_PISTOL:
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

public void ConVarChange_hEnableReloadClipCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_EnableReloadClipCvar  = hEnableReloadClipCvar.BoolValue;
}
public void ConVarChange_hEnableClipRecoverCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_EnableClipRecoverCvar = hEnableClipRecoverCvar.BoolValue;
}
public void ConVarChange_hSmgTimeCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_SmgTimeCvar = hSmgTimeCvar.FloatValue;
}
public void ConVarChange_hRifleTimeCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_RifleTimeCvar = hRifleTimeCvar.FloatValue;
}
public void ConVarChange_hHuntingRifleTimeCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_HuntingRifleTimeCvar = hHuntingRifleTimeCvar.FloatValue;
}
public void ConVarChange_hPistolTimeCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_PistolTimeCvar = hPistolTimeCvar.FloatValue;
}
public void ConVarChange_hDualPistolTimeCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_DualPistolTimeCvar = hDualPistolTimeCvar.FloatValue;
}

stock int GetWeaponAmmo(int client, int offest)
{
    return GetEntData(client, ammoOffset+(offest*4));
} 

stock int GetWeaponClip(int weapon)
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

stock bool IsIncapacitated(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

stock WeaponID GetWeaponID(int weapon,const char[] weapon_name)
{
	for(WeaponID i = ID_NONE; i < ID_WEAPON_MAX ; ++i)
	{
		if(StrEqual(weapon_name,Weapon_Name[i],false))
			return i;
	}
	return ID_NONE;
}