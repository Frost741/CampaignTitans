untyped

global function CampaignTitans_Init

// ---------------------------------------------------------------------------
// TF2.CampaignTitans v0.3
// Attrition ("aitdm" in Northstar): keeps N multiplayer AI Titans alive per team.
// They drop in at Titan spawnpoints, fight on campaign "Master" settings and use
// the campaign generic IMC titan-pilot voices (diag_imc_pilot1..8_hc_*).
// The spawn code follows the pattern of Neko's Attrition Extended Recode
// (CreateNPCTitan + npc_titan_auto_* settings + NPCTitanHotdrops).
// ---------------------------------------------------------------------------

const string CT_SCRIPTNAME = "ct_master"
const int CT_VOICES = 8

struct
{
	array<table> defs
	array<entity> titans
	table state
	table nextSpawn
	table spawnedTotal
	table deficitSince
	int playerTeam = 0
	table speech
	array<table> pending
	bool started = false
	array<int> camoIds
} file

// ---- setup -----------------------------------------------------------------

void function CampaignTitans_Init()
{
	printt( "[CT] init: GAMETYPE=" + GAMETYPE )

	string wanted = GetConVarString( "ct_gamemode" )
	if ( wanted != "" && GAMETYPE != wanted )
	{
		printt( "[CT] disabled: gamemode is '" + GAMETYPE + "', mod wants '" + wanted + "' (set ct_gamemode \"\" to allow any mode)" )
		return
	}

	if ( GetConVarInt( "ct_private_only" ) == 1 && GetCurrentPlaylistName() != "private_match" )
	{
		printt( "[CT] disabled: not a private match (playlist=" + GetCurrentPlaylistName() + ")" )
		return
	}

	CT_BuildDefs()
	CT_BuildCamoList()
	CT_InitSpeech()

	AddCallback_GameStateEnter( eGameState.Playing, CT_OnPlaying )
	AddDeathCallback( "npc_titan", CT_OnTitanDeath )
	AddCallback_OnTitanHealthSegmentLost( CT_OnSegmentLost )
	AddDamageCallback( "player", CT_OnPlayerDamaged )
	AddCallback_OnNPCKilled( CT_OnAnyNPCKilled )
	AddOnRodeoStartedCallback( CT_OnRodeoStarted )

	printt( "[CT] enabled, waiting for eGameState.Playing" )
	if ( GetGameState() == eGameState.Playing )
		CT_OnPlaying()
}

void function CT_AddDef( string setFile, string aiSettings, string behavior, string coreEvent, string primary, string ordnance, string core, string tactical, string special, string melee )
{
	file.defs.append( { setFile = setFile, aiSettings = aiSettings, behavior = behavior, coreEvent = coreEvent, primary = primary, ordnance = ordnance, core = core, tactical = tactical, special = special, melee = melee } )
}

void function CT_BuildDefs()
{
	// EDIT HERE: which multiplayer Titans may spawn, their campaign core line and weapon kit.
	//          setFile                  aiSettings                              behavior                              coreEvent             primary                             ordnance                        core                        tactical                    special                       melee
	CT_AddDef( "titan_atlas_stickybomb", "npc_titan_auto_atlas_stickybomb", "behavior_titan", "corelaseractivate",  "mp_titanweapon_particle_accelerator", "mp_titanweapon_laser_lite",     "mp_titancore_laser_cannon", "mp_titanability_laser_trip",  "mp_titanweapon_vortex_shield", "melee_titan_punch" ) // Ion
	CT_AddDef( "titan_atlas_tracker",    "npc_titan_auto_atlas_tracker", "behavior_titan_long_range",    "corerocketactivate", "mp_titanweapon_sticky_40mm",          "mp_titanweapon_tracker_rockets", "mp_titancore_salvo_core",  "mp_titanability_sonar_pulse", "mp_titanability_particle_wall", "melee_titan_punch" ) // Tone
	CT_AddDef( "titan_ogre_minigun",     "npc_titan_auto_ogre_minigun", "behavior_titan_ogre_minigun",     "coresmartactivate",  "mp_titanweapon_predator_cannon",      "mp_titanability_power_shot",     "mp_titancore_siege_mode",  "mp_titanability_ammo_swap",   "mp_titanability_gun_shield",   "melee_titan_punch" ) // Legion
	CT_AddDef( "titan_ogre_meteor",      "npc_titan_auto_ogre_meteor", "behavior_titan_ogre_meteor",      "coreflameactivate",  "mp_titanweapon_meteor",               "mp_titanweapon_flame_wall",      "mp_titancore_flame_wave",  "mp_titanability_slow_trap",   "mp_titanweapon_heat_shield",   "melee_titan_punch" ) // Scorch
	CT_AddDef( "titan_stryder_leadwall", "npc_titan_auto_stryder_leadwall", "behavior_titan_shotgun", "coreswordactivate",  "mp_titanweapon_leadwall",             "mp_titanweapon_arc_wave",        "mp_titancore_shift_core",  "mp_titanability_phase_dash",  "mp_ability_swordblock",        "melee_titan_sword" ) // Ronin
	CT_AddDef( "titan_stryder_sniper",   "npc_titan_auto_stryder_sniper", "behavior_titan_sniper",   "coreflightactivate", "mp_titanweapon_sniper",               "mp_titanweapon_dumbfire_rockets", "mp_titancore_flight_core", "mp_titanability_hover",        "mp_titanability_tether_trap",  "melee_titan_punch" ) // Northstar
}

// Builds the list of real, valid camo ids (the same ones the loadout menu itself uses -
// GetItemPersistenceId turns a cosmetic ref like "titan_camo_skin63" into the numeric id
// SetCamo() expects) so a random pick can never land on an invalid/garbage index.
void function CT_BuildCamoList()
{
	array<string> refs = [
		"titan_camo_skin07", "titan_camo_skin08", "titan_camo_skin09", "titan_camo_skin10",
		"titan_camo_skin13", "titan_camo_skin55", "titan_camo_skin56", "titan_camo_skin57",
		"titan_camo_skin58", "titan_camo_skin59", "titan_camo_skin60", "titan_camo_skin61",
		"titan_camo_skin62", "titan_camo_skin63", "titan_camo_skin64", "titan_camo_skin65",
		"titan_camo_skin66", "titan_camo_skin67", "titan_camo_skin85", "titan_camo_skin87",
		"titan_camo_skin91", "titan_camo_skin92", "titan_camo_skin93", "titan_camo_skin94"
	]

	foreach ( string ref in refs )
	{
		int id = GetItemPersistenceId( ref )
		if ( id > 0 )
			file.camoIds.append( id )
	}

	printt( "[CT] built camo list: " + file.camoIds.len() + " valid camos found" )
}
bool function CT_GiveKit( entity titan, table def )
{
	TakeWeaponsForArray( titan, titan.GetMainWeapons() )
	titan.TakeOffhandWeapon( OFFHAND_ORDNANCE )
	titan.TakeOffhandWeapon( OFFHAND_SPECIAL )
	titan.TakeOffhandWeapon( OFFHAND_ANTIRODEO )
	titan.TakeOffhandWeapon( OFFHAND_EQUIPMENT )
	titan.TakeOffhandWeapon( OFFHAND_MELEE )

	titan.GiveWeapon( expect string( def.primary ) )
	titan.GiveOffhandWeapon( expect string( def.ordnance ), OFFHAND_ORDNANCE )

	// only a few Titans (ct_core_chance %) get a core ability at all
	bool hasCore = RandomInt( 100 ) < GetConVarInt( "ct_core_chance" )
	if ( hasCore )
		titan.GiveOffhandWeapon( expect string( def.core ), OFFHAND_EQUIPMENT )

	titan.GiveOffhandWeapon( expect string( def.tactical ), OFFHAND_ANTIRODEO )
	titan.GiveOffhandWeapon( expect string( def.special ), OFFHAND_SPECIAL )
	titan.GiveOffhandWeapon( expect string( def.melee ), OFFHAND_MELEE )

	return hasCore
}

// The core meter only fills by dealing damage, so AI Titans rarely reach it. After the drop, and once the
// Titan is fighting, we fill the meter (1.0 = ready) and let the AI use it, then start over.
void function CT_MonitorCore( entity npc )
{
	entity soul = npc.GetTitanSoul()
	if ( !IsValid( soul ) )
		return

	soul.EndSignal( "OnDestroy" )
	soul.EndSignal( "OnDeath" )
	npc.EndSignal( "OnDestroy" )
	npc.EndSignal( "OnDeath" )

	while ( true )
	{
		SoulTitanCore_SetNextAvailableTime( soul, 0.0 )
		wait RandomFloatRange( GetConVarFloat( "ct_core_delay_min" ), GetConVarFloat( "ct_core_delay_max" ) )

		// only when the Titan is in a fight
		while ( !IsValid( npc.GetEnemy() ) )
			wait 1.0

		SoulTitanCore_SetNextAvailableTime( soul, 1.0 )
		printt( "[CT] core ready for " + npc.GetScriptName() + " (team " + npc.GetTeam() + ")" )

		// give the AI up to 20s to start the core
		float readyAt = Time()
		while ( Time() - readyAt < 20.0 && !IsTitanCoreFiring( npc ) )
			wait 0.5

		if ( IsTitanCoreFiring( npc ) )
		{
			printt( "[CT] core used" )

			// Ronin's sword core: same switch the campaign AI uses (aisettings + behavior_titan_melee_core)
			string coreEvent = expect string( file.state[ npc ].coreEvent )
			string behavior = expect string( file.state[ npc ].behavior )
			bool ronin = coreEvent == "coreswordactivate"
			if ( ronin )
			{
				npc.SetAISettings( "npc_titan_stryder_leadwall_shift_core" )
				npc.SetBehaviorSelector( "behavior_titan_melee_core" )
			}

			while ( IsTitanCoreFiring( npc ) )
				wait 0.5

			if ( ronin )
			{
				npc.SetAISettings( "npc_titan_auto_stryder_leadwall" )
				npc.SetBehaviorSelector( behavior )
			}
		}
		else
		{
			printt( "[CT] core was ready but the AI did not use it" )
		}

		// wait until the core is over
		while ( IsTitanCoreFiring( npc ) )
			wait 0.5
	}
}

// ---- main loop -------------------------------------------------------------

void function CT_OnPlaying()
{
	if ( file.started )
		return
	file.started = true
	printt( "[CT] match is Playing - starting manager" )
	thread CT_Manager()
}

// the team the human players are on (the majority; keeps the last answer on a tie)
int function CT_GetPlayerTeam()
{
	int imc = GetPlayerArrayOfTeam( TEAM_IMC ).len()
	int mil = GetPlayerArrayOfTeam( TEAM_MILITIA ).len()

	if ( imc > mil )
		file.playerTeam = TEAM_IMC
	else if ( mil > imc )
		file.playerTeam = TEAM_MILITIA
	else if ( file.playerTeam == 0 )
		file.playerTeam = TEAM_MILITIA

	return file.playerTeam
}

void function CT_Manager()
{
	int allyCount = GetConVarInt( "ct_titans_ally" )   // Titans on the players' team
	int enemyCount = GetConVarInt( "ct_titans_enemy" ) // Titans on the other team
	float delay = GetConVarFloat( "ct_respawn_delay" )

	array<int> teams = [ TEAM_IMC, TEAM_MILITIA ]

	foreach ( team in teams )
	{
		file.nextSpawn[ team ] <- 0.0
		file.spawnedTotal[ team ] <- 0
		file.deficitSince[ team ] <- 0.0
	}

	// small pause so the match/AI systems are up
	wait 3.0

	printt( "[CT] players are on team " + CT_GetPlayerTeam() + ": " + allyCount + " Titans there, " + enemyCount + " on the other team" )

	while ( GetGameState() == eGameState.Playing )
	{
		ArrayRemoveInvalid( file.titans )
		CT_CleanupState()

		int playerTeam = CT_GetPlayerTeam()

		foreach ( team in teams )
		{
			int target = ( team == playerTeam ) ? allyCount : enemyCount

			if ( CT_CountAlive( team ) >= target )
			{
				file.deficitSince[ team ] = 0.0
				continue
			}
			if ( Time() < file.nextSpawn[ team ] )
				continue

			bool opening = file.spawnedTotal[ team ] < target

			// replacement: wait ct_respawn_delay seconds from the moment a Titan is missing
			if ( !opening )
			{
				if ( file.deficitSince[ team ] == 0.0 )
					file.deficitSince[ team ] = Time()
				if ( Time() - file.deficitSince[ team ] < delay )
					continue
			}

			// opening fill is quick (1.5s apart)
			file.nextSpawn[ team ] = Time() + 1.5
			file.spawnedTotal[ team ] = file.spawnedTotal[ team ] + 1
			file.deficitSince[ team ] = 0.0

			thread CT_SpawnTitan( team )
		}

		wait 0.5
	}
}

void function CT_CleanupState()

{
	array<entity> dead
	foreach ( ent, st in file.state )
	{
		if ( !IsValid( ent ) )
			dead.append( expect entity( ent ) )
	}
	foreach ( ent in dead )
		delete file.state[ ent ]
}

int function CT_CountAlive( int team )
{
	int n = 0
	foreach ( t in file.titans )
	{
		if ( IsAlive( t ) && t.GetTeam() == team )
			n++
	}
	return n
}

// ---- spawnpoints (same checks as the working Attrition Extended Recode) ------

bool function CT_IsSpawnpointValid( entity spawnpoint, int team )
{
	if ( !spawnpoint.HasKey( "ignoreGamemode" ) || spawnpoint.HasKey( "ignoreGamemode" ) && spawnpoint.kv.ignoreGamemode == "0" )
	{
		if ( GetSpawnpointGamemodeOverride() != "" )
		{
			string gamemodeKey = "gamemode_" + GetSpawnpointGamemodeOverride()
			if ( spawnpoint.HasKey( gamemodeKey ) && ( spawnpoint.kv[ gamemodeKey ] == "0" || spawnpoint.kv[ gamemodeKey ] == "" ) )
				return false
		}
		else if ( GameModeRemove( spawnpoint ) )
			return false
	}

	if ( spawnpoint.IsOccupied() || ( "inuse" in spawnpoint.s && spawnpoint.s.inuse ) || ( "lastUsedTime" in spawnpoint.s && Time() - spawnpoint.s.lastUsedTime <= 10.0 ) || ( spawnpoint.e.spawnTime != 0 && Time() - spawnpoint.e.spawnTime <= 10.0 ) || spawnpoint.e.spawnPointInUse )
		return false

	if ( SpawnPointInNoSpawnArea( spawnpoint.GetOrigin(), team ) )
		return false

	return !spawnpoint.IsVisibleToEnemies( team )
}

entity function CT_GetSpawnpoint( int team )
{
	array<entity> spawns = SpawnPoints_GetTitan()
	array<entity> valid
	foreach ( sp in spawns )
	{
		if ( CT_IsSpawnpointValid( sp, team ) )
			valid.append( sp )
	}

	if ( valid.len() == 0 )
		return null
	return valid.getrandom()
}

void function CT_ToggleSpawnpointUse( entity spawnpoint, bool value )
{
	spawnpoint.s.inuse <- value
	spawnpoint.e.spawnPointInUse = value
}

// ---- spawning --------------------------------------------------------------

table function CT_PickDef( int team )
{
	array<table> free
	foreach ( d in file.defs )
	{
		bool used = false
		foreach ( t in file.titans )
		{
			if ( !IsAlive( t ) || t.GetTeam() != team || !( t in file.state ) )
				continue
			if ( file.state[ t ].coreEvent == d.coreEvent )
				used = true
		}
		if ( !used )
			free.append( d )
	}

	if ( free.len() == 0 )
		return file.defs.getrandom()
	return free.getrandom()
}

void function CT_SpawnTitan( int team )
{
	entity spawnpoint = CT_GetSpawnpoint( team )
	if ( !IsValid( spawnpoint ) )
	{
		printt( "[CT] no free titan spawnpoint for team " + team + ", will retry" )
		// give the slot back so the manager retries soon
		file.nextSpawn[ team ] = Time() + 3.0
		file.spawnedTotal[ team ] = file.spawnedTotal[ team ] - 1
		return
	}

	spawnpoint.s.lastUsedTime <- Time()
	spawnpoint.e.spawnTime = Time()
	CT_ToggleSpawnpointUse( spawnpoint, true )

	vector origin = spawnpoint.GetOrigin()
	vector angles = spawnpoint.GetAngles()
	table def = CT_PickDef( team )
	string setFile = expect string( def.setFile )
	string aiSettings = expect string( def.aiSettings )
	string coreEvent = expect string( def.coreEvent )
	string behavior = expect string( def.behavior )
	string tactical = expect string( def.tactical )
	printt( "[CT] spawning " + setFile + " (" + aiSettings + ") for team " + team + " at " + origin )

	entity titan = CreateNPCTitan( setFile, team, origin, angles )
	SetSpawnOption_AISettings( titan, aiSettings )
	DispatchSpawn( titan )
	bool hasCore = CT_GiveKit( titan, def )

	// random camo/paint job, picked from the same real cosmetic ids the loadout menu uses
	if ( GetConVarInt( "ct_random_camo" ) == 1 && file.camoIds.len() > 0 )
	{
		titan.SetSkin( TITAN_SKIN_INDEX_CAMO )
		titan.SetCamo( file.camoIds.getrandom() )
	}

	// campaign "Master" settings
	titan.SetScriptName( CT_SCRIPTNAME )
	titan.kv.WeaponProficiency = eWeaponProficiency.PERFECT
	float hp = titan.GetMaxHealth() * GetConVarFloat( "ct_health_scale" )
	titan.SetMaxHealth( hp )
	titan.SetHealth( hp )

	file.state[ titan ] <- { voice = RandomIntRange( 1, CT_VOICES + 1 ), coreEvent = coreEvent, behavior = behavior, tactical = tactical, segmentsLost = 0, nextSay = 0.0, nextSmoke = 0.0 }
	file.titans.append( titan )

	// titanfall, same as a player's Titan drop
	SetStanceKneel( titan.GetTitanSoul() )
	UpdateEnemyMemoryFromTeammates( titan )
	NPCTitanHotdrops( titan, true ) // blocks until the Titan has landed and stood up

	// start the behaviour threads only now, otherwise WaitTillHotDropComplete returns before the drop begins
	if ( IsAlive( titan ) )
	{
		// behavior_mp_auto_titan has no core schedule; the campaign behaviors (behavior_titan*) have
		// CNPC_Titan::SelectSchedule_TitanCore, so this is what lets the AI use its core
		titan.SetBehaviorSelector( behavior )

		thread CT_VoiceThread( titan )
		thread CT_RoamThread( titan )
		if ( hasCore )
			thread CT_MonitorCore( titan )
	}

	if ( IsValid( spawnpoint ) )
		CT_ToggleSpawnpointUse( spawnpoint, false )
}

// ---- master damage ---------------------------------------------------------

// ---- score for AI-vs-AI kills --------------------------------------------
// Native scoring (AddPlayerScore) only fires for a PLAYER attacker, so a kill made
// by one AI against another AI normally gives the team nothing. This mirrors the
// point values AI_TDM already uses for its own scoring (see sh_gamemode_aitdm.nut).

int function CT_PointsForVictim( entity victim )
{
	if ( victim.IsTitan() )
		return 10
	if ( IsSuperSpectre( victim ) )
		return 3
	if ( IsGrunt( victim ) || IsSpectre( victim ) || IsStalker( victim ) )
		return 1
	return 0
}

void function CT_OnAnyNPCKilled( entity victim, entity attacker, var damageInfo )
{
	if ( !IsValid( attacker ) || !attacker.IsNPC() )
		return
	if ( !IsValid( victim ) || !victim.IsNPC() )
		return
	if ( attacker.GetTeam() == victim.GetTeam() )
		return // no team-kill credit

	int points = CT_PointsForVictim( victim )
	if ( points <= 0 )
		return

	int team = attacker.GetTeam()
	GameRules_SetTeamScore( team, GameRules_GetTeamScore( team ) + points )
}

bool function CT_IsOurs( entity ent )
{
	return IsValid( ent ) && ent.IsNPC() && ent.IsTitan() && ent.GetScriptName() == CT_SCRIPTNAME
}

void function CT_OnPlayerDamaged( entity player, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !CT_IsOurs( attacker ) )
		return

	DamageInfo_ScaleDamage( damageInfo, GetConVarFloat( "ct_damage_scale" ) )
}

// ---- anti-rodeo electric smoke ---------------------------------------------
// When an enemy pilot starts rodeoing one of our Titans, give it a short reaction
// window and then have it pop its electric smoke screen - the same ability real
// Titans use against rodeo (mp_titanability_electric_smoke / OFFHAND_ANTIRODEO).
// This borrows the weapon rather than reimplementing it: we equip the smoke
// tactical for one shot, fire it through the NPC entry point the game already
// uses for AI Titans, then give the Titan its normal tactical back.

const string CT_SMOKE_WEAPON = "mp_titanability_electric_smoke"

void function CT_OnRodeoStarted( entity player, entity titan )
{
	if ( !CT_IsOurs( titan ) )
		return
	if ( !IsValid( player ) || !player.IsPlayer() )
		return
	if ( player.GetTeam() == titan.GetTeam() )
		return // friendly rodeo (repair/battery), not an attack
	if ( !( titan in file.state ) )
		return

	thread CT_TitanSmokeThread( titan )
}

void function CT_TitanSmokeThread( entity titan )
{
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "OnDeath" )

	local st = file.state[ titan ]
	if ( Time() < expect float( st.nextSmoke ) )
		return
	st.nextSmoke = Time() + GetConVarFloat( "ct_smoke_cooldown" )

	// give the AI a moment to "notice" the rider, like a player reacting
	wait RandomFloatRange( 0.4, 1.2 )

	if ( !IsAlive( titan ) )
		return

	string previousTactical = expect string( file.state[ titan ].tactical )

	titan.TakeOffhandWeapon( OFFHAND_ANTIRODEO )
	titan.GiveOffhandWeapon( CT_SMOKE_WEAPON, OFFHAND_ANTIRODEO )

	entity smokeWeapon = titan.GetOffhandWeapon( OFFHAND_ANTIRODEO )
	if ( IsValid( smokeWeapon ) )
	{
		WeaponPrimaryAttackParams attackParams
		OnWeaponNpcPrimaryAttack_titanability_smoke( smokeWeapon, attackParams )
		printt( "[CT] " + titan.GetScriptName() + " popped electric smoke against a rodeoing pilot" )
	}

	titan.TakeOffhandWeapon( OFFHAND_ANTIRODEO )
	if ( previousTactical != "" )
		titan.GiveOffhandWeapon( previousTactical, OFFHAND_ANTIRODEO )
}

// ---- roaming ---------------------------------------------------------------

vector function CT_PickRoamPoint( entity titan )
{
	int team = titan.GetTeam()

	array<entity> players
	foreach ( entity p in GetPlayerArrayOfEnemies( team ) )
	{
		if ( IsAlive( p ) )
			players.append( p )
	}

	array<entity> npcs
	foreach ( entity n in GetNPCArrayOfEnemies( team ) )
	{
		if ( IsAlive( n ) )
			npcs.append( n )
	}

	if ( players.len() > 0 && ( npcs.len() == 0 || RandomInt( 100 ) < 50 ) )
		return players.getrandom().GetOrigin()
	if ( npcs.len() > 0 )
		return npcs.getrandom().GetOrigin()

	array<entity> spawns = SpawnPoints_GetTitan()
	if ( spawns.len() > 0 )
		return spawns.getrandom().GetOrigin()

	return titan.GetOrigin()
}

void function CT_RoamThread( entity titan )
{
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "OnDeath" )

	WaitTillHotDropComplete( titan )

	titan.EnableNPCFlag( NPC_ALLOW_PATROL | NPC_ALLOW_INVESTIGATE | NPC_ALLOW_HAND_SIGNALS )

	while ( true )
	{
		vector point = CT_PickRoamPoint( titan )
		titan.AssaultPoint( point )
		titan.AssaultSetGoalRadius( 1200 )

		wait RandomFloatRange( 8.0, 18.0 )
	}
}

// ---- campaign voice lines (diag_imc_pilotN_hc_<event>) -----------------------
//
// Rules:
//  * only the ENEMY players of the speaking Titan hear a line (nobody on its own team)
//  * per team only ONE Titan speaks at a time; a line from another Titan is dropped
//  * lines of the same Titan never overlap: lostchicket lines wait for the current line to end
//  * "death" plays when the Titan is destroyed and cuts whatever is playing
//  * while a line plays, the game's own conversations (Titan ready, ...) are blocked for the listeners

void function CT_InitSpeech()
{
	array<int> teams = [ TEAM_IMC, TEAM_MILITIA ]
	foreach ( team in teams )
		file.speech[ team ] <- { speaker = null, endTime = 0.0, alias = "", targets = [] }
}

int function CT_EventPriority( string event )
{
	if ( event == "death" )
		return 3
	if ( event == "battlestart" || event == "plyrlostchicklet" )
		return 1
	return 2
}

bool function CT_IsSegmentEvent( string event )
{
	return event == "lostchicket1" || event == "lostchicket2" || event == "lostchicket34" || event == "lostchicket56"
}

array<entity> function CT_GetListeners( int team, vector origin )
{
	array<entity> out
	float range = GetConVarFloat( "ct_voice_range" )

	foreach ( entity p in GetPlayerArrayOfEnemies( team ) )
	{
		if ( !IsAlive( p ) )
			continue
		if ( range > 0 && Distance( p.GetOrigin(), origin ) > range )
			continue
		out.append( p )
	}

	return out
}

void function CT_ReleaseListeners( array<entity> targets )
{
	foreach ( entity p in targets )
	{
		if ( IsValid( p ) )
			SetPlayerForcedDialogueOnly( p, false )
	}
}

void function CT_StopCurrent( int team )
{
	local sp = file.speech[ team ]

	if ( IsValid( sp.speaker ) && sp.alias != "" )
		StopSoundOnEntity( expect entity( sp.speaker ), expect string( sp.alias ) )

	foreach ( p in sp.targets )
	{
		if ( IsValid( p ) )
			SetPlayerForcedDialogueOnly( expect entity( p ), false )
	}

	sp.endTime = 0.0
	sp.alias = ""
	sp.speaker = null
}

void function CT_Play( entity titan, int team, string alias, vector origin, bool isDeath )
{
	array<entity> targets = CT_GetListeners( team, origin )
	if ( targets.len() == 0 )
		return

	// GetSoundDuration is client-only, so the server uses a fixed estimate per line
	float dur = GetConVarFloat( "ct_line_duration" )
	if ( dur < 1.0 )
		dur = 1.0

	local sp = file.speech[ team ]
	sp.speaker = titan
	sp.alias = alias
	sp.endTime = Time() + dur
	sp.targets.clear()
	foreach ( entity t in targets )
		sp.targets.append( t )

	foreach ( entity p in targets )
	{
		SetPlayerForcedDialogueOnly( p, true ) // blocks Titan ready & co while the line plays
		Remote_CallFunction_NonReplay( p, "CT_ServerCallback_InterruptDialogue", 0 ) // cuts off whatever is already playing (incl. TitanOS) right now

		if ( isDeath )
			EmitSoundAtPositionOnlyToPlayer( team, origin, p, alias )
		else
			EmitSoundOnEntityOnlyToPlayer( titan, p, alias )
	}

	thread CT_SpeechEndThread( team, alias, dur, targets )
}

void function CT_SpeechEndThread( int team, string alias, float dur, array<entity> targets )
{
	wait dur + 0.3

	local sp = file.speech[ team ]
	if ( sp.alias != alias ) // interrupted or replaced by another line
		return

	CT_ReleaseListeners( targets )
	sp.endTime = 0.0
	sp.alias = ""
	sp.speaker = null

	CT_PlayNextPending( team )
}

void function CT_PlayNextPending( int team )
{
	while ( true )
	{
		int idx = -1
		for ( int i = 0; i < file.pending.len(); i++ )
		{
			if ( file.pending[ i ].team == team )
			{
				idx = i
				break
			}
		}
		if ( idx == -1 )
			return

		local p = file.pending[ idx ]
		file.pending.remove( idx )

		entity pt = expect entity( p.titan )
		if ( Time() - p.queuedAt > 12.0 || !IsAlive( pt ) )
			continue

		CT_Play( pt, team, expect string( p.alias ), pt.GetOrigin(), false )
		return
	}
}

void function CT_Request( entity titan, int team, int voice, string event, vector origin )
{
	string alias = "diag_imc_pilot" + voice + "_hc_" + event
	local sp = file.speech[ team ]
	bool busy = Time() < sp.endTime

	if ( !busy )
	{
		CT_Play( titan, team, alias, origin, event == "death" )
		return
	}

	if ( event == "death" )
	{
		CT_StopCurrent( team )
		CT_Play( titan, team, alias, origin, true )
		return
	}

	// same Titan, segment line: wait until its current line is over (no mixing)
	if ( CT_IsSegmentEvent( event ) && sp.speaker == titan )
	{
		// keep at most one waiting line per Titan
		for ( int i = file.pending.len() - 1; i >= 0; i-- )
		{
			if ( file.pending[ i ].titan == titan )
				file.pending.remove( i )
		}
		file.pending.append( { titan = titan, team = team, alias = alias, queuedAt = Time() } )
		return
	}

	// somebody else is talking: drop the line
}

void function CT_Say( entity titan, string event )
{
	if ( !IsValid( titan ) || !( titan in file.state ) )
		return

	local st = file.state[ titan ]
	CT_Request( titan, titan.GetTeam(), expect int( st.voice ), event, titan.GetOrigin() )
}

// battlestart: a real line of sight to an enemy player
bool function CT_SeesEnemyPlayer( entity titan )
{
	foreach ( entity p in GetPlayerArrayOfEnemies( titan.GetTeam() ) )
	{
		if ( !IsAlive( p ) )
			continue
		if ( Distance( p.GetOrigin(), titan.GetOrigin() ) > 3500 )
			continue

		TraceResults result = TraceLine( titan.EyePosition(), p.EyePosition(), titan, TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
		if ( result.hitEnt == p || result.fraction >= 0.98 )
			return true
	}

	return false
}

void function CT_VoiceThread( entity titan )
{
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "OnDeath" )

	WaitTillHotDropComplete( titan )

	float lastBattleStart = -100.0
	bool coreWasFiring = false

	while ( true )
	{
		wait 0.5

		if ( Time() - lastBattleStart > 45.0 && CT_SeesEnemyPlayer( titan ) )
		{
			lastBattleStart = Time()
			CT_Say( titan, "battlestart" )
		}

		bool coreNow = IsTitanCoreFiring( titan )
		if ( coreNow && !coreWasFiring )
			CT_Say( titan, expect string( file.state[ titan ].coreEvent ) )
		coreWasFiring = coreNow
	}
}

void function CT_OnSegmentLost( entity victim, entity attacker )
{
	if ( CT_IsOurs( victim ) && ( victim in file.state ) )
	{
		local st = file.state[ victim ]
		st.segmentsLost = st.segmentsLost + 1

		string ev = "lostchicket1"
		if ( st.segmentsLost == 2 )
			ev = "lostchicket2"
		else if ( st.segmentsLost >= 3 && st.segmentsLost <= 4 )
			ev = "lostchicket34"
		else if ( st.segmentsLost > 4 )
			ev = "lostchicket56"

		CT_Say( victim, ev )
	}

	if ( CT_IsOurs( attacker ) && IsValid( victim ) && victim.IsPlayer() )
		CT_Say( attacker, "plyrlostchicklet" )
}

// the Titan is destroyed
void function CT_OnTitanDeath( entity titan, var damageInfo )
{
	if ( CT_IsOurs( titan ) )
		CT_Say( titan, "death" )
}
