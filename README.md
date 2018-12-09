# L4D1-Competitive-Plugins by Harry Potter
L4D1 Competitive enhancement, bug/glitch fixes, general purpose and freaky-fun plugins.
* <b>L4D1-competitive-framework</b>: following [L4D2-Competitive-Framework](https://github.com/Attano/L4D2-Competitive-Framework/tree/master/addons/sourcemod/scripting) I provide L4D1 version
* <b>modify</b>: [raziEiL/l4d competitive plugins](https://bitbucket.org/disawar1/l4d-competitive-plugins/src/master/) and [raziEiL/rotoblin2](https://github.com/raziEiL/rotoblin2/tree/master/src) I modify better version
* <b>fun</b>: I write some new plugins which are just for fun
> All plugins in here only apply to L4D1 (last edited:2018/12/7)
# Require
* <b>[sourcemod 1.8 or newer](https://www.sourcemod.net/downloads.php?branch=stable)</b>
* <b>[l4dt-0.4.7.5.zip](https://bitbucket.org/disawar1/left4downtown/downloads/)</b>
* <b>[l4d_direct](https://github.com/raziEiL/l4d_direct-port)</b>
# Plugins
* <b>l4d2_ai_damagefix</b>: Makes AI SI take (and do) damage like human SI.
* <b>l4d2_blind_infected</b>: Hides all weapons and iteams from the infected team or dead survivor until they are (possibly) visible to one of the alive survivors to prevent SI scouting the map
* <b>l4d2_si_ffblock</b>: Disables friendly fire between infected players.
* <b>l4d_panic_notify</b>: Show who triggers the panic horde
* <b>l4d_tank_count</b>: Show how long is tank alive, and tank punch/rock/car statistics after tank dead
* <b>l4d_vesus_nerf_huntingrifle</b>: Make a nerf huntingrifle
* <b>l4d_tank_props</b></b>: Stop tank props from fading + Show Hittable Glow for inf team whilst the tank is alive
* <b>l4d_tankpunchstuckfix</b>: Fixes the problem where tank-punches get a survivor stuck in the roof
* <b>1vHunters</b>: Hunter pounce survivors and die ,set hunter scratch damage, no getup animation
* <b>hunter_growl_sound_fix</b>: Fix silence Hunter produces growl sound when player MIC on
* <b>huntercrouchsound</b>: Forces silent but crouched hunters to emitt sounds
* <b>l4d_jukebox_spawner</b>: Auto-spawn jukeboxes on all value maps when round start.
* <b>l4d_pig_infected_notify</b>: Show who the god teammate boom the Tank, Tank use which weapon(car,pounch,rock) to kill teammates S.I. and Witch , player open door to stun tank (l4d 豬隊友提示)
* <b>l4d_storm</b>: Control L4d1 skybox/sun color/snow/rain/wind/maplight...and etc
* <b>sm_l4d_mapchanger</b>: When final stage round ends, auto change next Map based on date/...txt
* <b>l4dinfectedbots</b>: control and spawn Infected bots, works in l4d1 versus
* <b>match_vote</b>: type !match/!load/!mode to vote a new mode
* <b>l4d_drop_secondary</b>: Survivor players will drop their secondary weapon when they die
* <b>l4d_bw_rock_hit</b>: Stops rocks from passing through soon-to-be-dead Survivors
* <b>checkpoint-rage-control</b>: Enable tank to lose rage while survivors are in saferoom
* <b>l4d_stumble_block_button</b>: Blocks all button presses during stumbles
* <b>l4d_bash_kills</b>: Stop special infected getting bashed to death, except boomer
* <b>l4d_tank_shove_slowdown_fix</b>: Stops Shoves slowing the Tank Down
* <b>l4d_si_slowdown</b>: Removes the slow down from special infected
* <b>l4d_godframes_and_hittable_control</b>: Control survivors godframes + Allows for customisation of hittable damage values.
* <b>l4d_tank_hittable_refill</b>: Refill Tank's frustration whenever a hittable hits a Survivor
* <b>nodeathcamskip</b>: Blocks players skipping their death cam
* <b>l4d_versus_despawn_health</b>: Gives Special Infected health back when they despawn.
* <b>l4d_smg_pumpshotgun_ammo_set</b>: custom SMG/PUMPSHOTGUN ammo capacity.
* <b>l4d_tank_control</b>: Forces each player to play the tank at least once before Map change.
* <b>fix_ghostsound</b>: Mute some SI sounds for Survivors.
* <b>l4d2_witch_restore</b>: Witch is restored at the same spot if she gets killed by a Tank
* <b>kills</b>: Statistics of infected kills/common kills/ff/capped for survivors
* <b>l4d_tankhud</b>: Show tank hud for spectators and show tank frustration for inf team
* <b>l4dcompstats</b>: Basic competitive stat tracking on a per map basis + MVP
* <b>l4d_passing_Tank_no_instant_respawn</b>: Passing control to AI tank will no longer be rewarded with an instant respawn
* <b>l4d_no_hunter_deadstops</b>: support L4D1 command "versus_shove_hunter_fov_pouncing" to get no deadstops work
* <b>1v1</b>: A plugin designed to support 1v1.
* <b>l4d2_nobackjumps</b>: Prevents players from using the wallkicking trick
* <b>l4d_versus_GhostWarp</b>: Allows infected to warp to survivors based on their flow (MOUSE2 or use command)
* <b>lerptracker</b>: Keep track of players' lerp settings
* <b>ratemonitor</b>: Keep track of players' netsettings
* <b>temphealthfix</b>: Ensures that survivors that have been incapacitated with a hittable object get their temp health set correctly
* <b>fix_specbotkick</b>: Fixed no Survivor bots issue. Fix more Survivor bots issue.
* <b>l4d_tank_witch_damage_announce_spawnAnnouncer</b>: Bosses dealt damage announcer + Announce in chat and via a sound when a Tank/Witch has spawned
* <b>l4d_tank_attack_control</b>: Tank pounch and rock control variation
* <b>l4d_team_unscramble</b>: forces all players on the right team after map/campaign/match change
* <b>l4d_versus_same_UnprohibitBosses</b>: Force Enable bosses spawning on all maps, and same spawn positions for both team
# Scripting Compiler
using sourcemod 1.8 Compiler
* <b>[l4d_lib.inc](https://github.com/raziEiL/rotoblin2/blob/master/left4dead/addons/sourcemod/scripting/include/l4d_lib.inc)</b> 
* <b>[l4d_weapon_stocks.inc](https://github.com/fbef0102/L4D1-Plugins/blob/master/scripting/include/l4d_weapon_stocks.inc)</b>
* <b>[colors.inc](https://forums.alliedmods.net/showthread.php?t=96831)</b>
