# L4D1-Competitive-Plugins by Harry Potter
L4D1 Competitive enhancement, bug/glitch fixes, general purpose and freaky-fun plugins.
* <b>L4D1-competitive-framework</b>: following [L4D2-Competitive-Framework](https://github.com/Attano/L4D2-Competitive-Framework/tree/master/addons/sourcemod/scripting) I provide L4D1 version
* <b>modify</b>: [raziEiL/l4d competitive plugins](https://bitbucket.org/disawar1/l4d-competitive-plugins/src/master/) and [raziEiL/rotoblin2](https://github.com/raziEiL/rotoblin2/tree/master/src) I modify better version
* <b>fun</b>: I write some new plugins which are just for fun
> last edited:2019/8/13
# Require
* Clean Servers:
  * [Sourcemod 1.8](https://www.sourcemod.net/downloads.php?branch=1.8-dev) (or newer), [Metamod](https://www.metamodsource.net/downloads.php?branch=stable)
* <b>[l4dt-0.4.7.5.zip](https://bitbucket.org/disawar1/left4downtown/downloads/)</b>
* <b>[l4d_direct](https://github.com/raziEiL/l4d_direct-port)</b>
* <b>[GameRules Prop Hax](https://forums.alliedmods.net/showthread.php?t=154217)</b>
# Plugins
* <b>l4d2_ai_damagefix</b>: Makes AI SI take (and do) damage like human SI.
* <b>l4d2_blind_infected</b>: Hides all weapons and iteams from the infected team or dead survivor until they are (possibly) visible to one of the alive survivors to prevent SI scouting the map
* <b>l4d2_si_ffblock</b>: Disables friendly fire between infected players.
* <b>l4d2_witch_crown_fix</b>: Fixes the Witch not dying from a perfectly aligned shotgun blast due to the random nature of the pellet spread
* <b>l4d2_witch_restore</b>: Witch is restored at the same spot if she gets killed by a Tank
* <b>l4d2_nobackjumps</b>: Prevents players from using the wallkicking trick
* <b>l4d2_spec_stays_spec</b>: Spectator will stay as spectators on mapchange.
* <b>l4d_panic_notify</b>: Show who triggers the panic horde
* <b>l4d_tank_count</b>: Show how long is tank alive, and tank punch/rock/car statistics after tank dead
* <b>l4d_vesus_nerf_huntingrifle</b>: Make a nerf huntingrifle
* <b>l4d_tank_props</b></b>: Stop tank props from fading + Show Hittable Glow for inf team whilst the tank is alive (Fixed car disappear)
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
* <b>kills</b>: Statistics of infected kills/common kills/ff/capped for survivors
* <b>l4d_tankhud</b>: Show tank hud for spectators and show tank frustration for inf team
* <b>l4dcompstats</b>: Basic competitive stat tracking on a per map basis + MVP
* <b>l4d_passing_Tank_no_instant_respawn</b>: Passing control to AI tank will no longer be rewarded with an instant respawn
* <b>l4d_no_hunter_deadstops</b>: support L4D1 command "versus_shove_hunter_fov_pouncing" to get no deadstops work
* <b>1v1</b>: A plugin designed to support 1v1.
* <b>l4d_versus_GhostWarp</b>: Allows infected to warp to survivors based on their flow (MOUSE2 or use command)
* <b>lerptracker</b>: Keep track of players' lerp settings
* <b>ratemonitor</b>: Keep track of players' netsettings
* <b>temphealthfix</b>: Ensures that survivors that have been incapacitated with a hittable object get their temp health set correctly
* <b>fix_specbotkick</b>: Fixed no Survivor bots issue. Fix more Survivor bots issue.
* <b>l4d_tank_witch_damage_announce_spawnAnnouncer</b>: Bosses dealt damage announcer + Announce in chat and via a sound when a Tank/Witch has spawned
* <b>l4d_tank_attack_control</b>: Tank pounch and rock control variation
* <b>l4d_team_unscramble</b>: forces all players on the right team after map/campaign/match change
* <b>l4d_versus_same_UnprohibitBosses</b>: Force Enable bosses spawning on all maps, and same spawn positions for both team
* <b>l4d_stuckzombiemeleefix</b>: Smash nonstaggering Zombies
* <b>l4d_pounceprotect</b>: Prevent damage from blocking a hunter's ability to pounce
* <b>caster_assister</b>: Allows spectators to control their own specspeed and move vertically
* <b>pill_passer</b>: Lets players pass pills with +reload when they are holding one of those items
* <b>pounce_maxdamage</b>: Makes it easy to properly uncap hunter pounces
* <b>pounceannounce</b>: Announces hunter pounces to the entire server
* <b>tankdoorfix</b>: This should at some point fix the case in which the tank misses the door he's supposed to destroy by using his punch
* <b>l4d_ledge_HealthExpolitFixes</b>: Plugin fixes 3 health expolit caused when survivor hanging on a ledge and after it
* <b>l4d_NoEscapeTank</b>: No Tank Spawn as the rescue vehicle is coming
* <b>TickrateFixes</b>: Fixes a handful of silly Tickrate bugs
* <b>fix_engine</b>: Blocking ladder speed glitch, no fall damage bug, health boost glitch.
* <b>botpopstop</b>: Removes pills from bots if they try to use them and restores them when a human takes over.
* <b>l4d_PillsHere</b>: Gives pills to survivors who doesn't have pill
* <b>l4d_multiwitch</b>: A plugin that spawns unlimited witches off of a timer. Sets glows on witches when survivors are far away
* <b>l4d_NoRescueFirstTank</b>: Final Stage except for 'The Sacrifice', No First Tank Spawn as the final rescue start and second tank spawn same position for both team
* <b>si_class_announce</b>: Report what SI classes are up when the round starts.
* <b>l4d_boss_percent</b>: Announce boss flow percents!
* <b>l4d_current_survivor_progress</b>: Print survivor progress in flow percents
* <b>l4d_thirdpersonshoulderblock</b>: Spectates clients who enable the thirdpersonshoulder mode on L4D1/2 to prevent them from looking around corners, through walls etc.
* <b>l4d_versus_specListener3.0</b>: Allows spectator listen others team voice for l4d
* <b>l4d_texture_manager_block</b>: Kicks out clients who are potentially attempting to enable mathack
* <b>AI_HardSI</b>: Improves the AI behaviour of special infected
* <b>finalefix</b>: Kills survivors before the score is calculated so they don't get full distance and health bonus if they are incapped as the rescue vehicle leaves.
* <b>l4d_slot_vote</b>: Allow players to change server slots by using vote.
* <b>hunter_callout_blocker</b>: Stops Survivors from saying 'Hunter!' (sometimets survivors didn't see the silence hunter but their mouth keep saying 'Hunter!')
* <b>l4d_ladderblock</b>: Prevents people from blocking players who climb on the ladder.
* <b>l4d_teamshuffle</b>: Allows teamshuffles by voting or admin-forced.
* <b>l4d_Modo_mix_mm</b>: Left 4 Dead Mix
* <b>l4d_tankswap</b>: Allows a primary Tank Player to surrender control to one of his teammates
* <b>l4d_vomit_pounce_fix</b>: Fixed that player whom hunter pounces on will not be biled by a boomer
* <b>AntiBreach</b>: Disallows special infected from breaching into safe room by preventing them from spawning nearby the safe room door.
* <b>l4d1_witch_allow_in_safezone</b>: Allows witches to chase victims into safezones.
# Scripting Compiler
using sourcemod 1.8 or 1.9 Compiler if you want to edit code and recomplie
* <b>[l4d_lib](https://github.com/raziEiL/rotoblin2/blob/master/left4dead/addons/sourcemod/scripting/include/l4d_lib.inc)</b> 
* <b>[colors](https://forums.alliedmods.net/showthread.php?t=96831)</b>
* <b>[l4d2util](https://github.com/ConfoglTeam/l4d2util/tree/master/scripting/include)</b>
