untyped

global function CT_LTS_IsActive
global function CT_LTS_Init
global function CT_LTS_GetAllyCount
global function CT_LTS_GetEnemyCount
global function CT_LTS_GetSpawnpoint
global function CT_LTS_SpawnWindowClosed

// ---------------------------------------------------------------------------
// Last Titan Standing ("lts" in Northstar) support for TF2.CampaignTitans.
//
// Every round ct_campaign_titans.nut drops ct_lts_titans_ally / ct_lts_titans_enemy
// AI Titans once (no replacements - LTS has no respawns).
//
// AI Titans count as real team members: a team only loses the round when
// its players' Titans AND its AI Titans are all destroyed.
// Northstar ends an elimination round by itself as soon as the players of a
// team are dead (IsPilotEliminationBased / IsTitanEliminationBased in
// _utility_shared.nut decide that). We switch the elimination riff to Default
// so that never fires, and do the elimination check here instead.
// Round time-outs are still decided by Northstar.
// ---------------------------------------------------------------------------

// AI Titans still missing this long after the round started (no free spawnpoint) aren't dropped anymore,
// and a team counts as fully deployed after it no matter what
const float CT_LTS_SPAWN_WINDOW = 25.0

struct
{
	table hadTitans // team -> bool: the team fielded at least one Titan this round
	float roundStart = 0.0
	int roundId = 0
} file

bool function CT_LTS_IsActive()
{
	return GAMETYPE == "lts" && GetConVarInt( "ct_lts_enabled" ) == 1
}

int function CT_LTS_GetAllyCount()
{
	return GetConVarInt( "ct_lts_titans_ally" )
}

int function CT_LTS_GetEnemyCount()
{
	return GetConVarInt( "ct_lts_titans_enemy" )
}

// called by CampaignTitans_Init once the mod has decided to run in this match
void function CT_LTS_Init()
{
	AddCallback_GameStateEnter( eGameState.Prematch, CT_LTS_OnPrematch )
	AddCallback_GameStateEnter( eGameState.Playing, CT_LTS_OnRoundPlaying )
	CT_LTS_DisableNorthstarElimination()
	printt( "[CT] Last Titan Standing: " + CT_LTS_GetAllyCount() + " ally / " + CT_LTS_GetEnemyCount() + " enemy AI Titans per round, AI Titans count for elimination" )
}

// ---- round flow ------------------------------------------------------------

// new round is about to start: remove AI Titans left over from the last round
void function CT_LTS_OnPrematch()
{
	CT_DestroyAllTitans()
	CT_LTS_DisableNorthstarElimination()
}

void function CT_LTS_OnRoundPlaying()
{
	// re-apply every round, in case the mode sets it again on round start
	CT_LTS_DisableNorthstarElimination()

	file.hadTitans[ TEAM_IMC ] <- false
	file.hadTitans[ TEAM_MILITIA ] <- false
	file.roundStart = Time()
	file.roundId++

	thread CT_LTS_EliminationThink( file.roundId )
}

void function CT_LTS_DisableNorthstarElimination()
{
	// guarded, so a failure here can't stop our own elimination check from starting
	try
	{
		Riff_ForceSetEliminationMode( eEliminationMode.Default )
	}
	catch ( ex )
	{
		printt( "[CT] LTS: could not change the elimination mode: " + ex )
	}
}

bool function CT_LTS_SpawnWindowClosed()
{
	return Time() - file.roundStart > CT_LTS_SPAWN_WINDOW
}

// ---- spawning at the players' start --------------------------------------
// Players start an LTS round on the map's Titan start spawns (info_spawnpoint_titan_start,
// marked "gamemode_lts" "1" in maps/*_spawn.ent), one group per side. AI Titans use the same
// points: a team with players drops next to them, an AI-only team drops on the start points
// farthest from the other team's players (= the opposite base). Sides are worked out from
// where the players actually are rather than the points' team number, since sides can swap
// between rounds.

bool function CT_LTS_IsStartSpawnFree( entity spawnpoint )
{
	string gamemodeKey = "gamemode_" + GAMETYPE
	if ( spawnpoint.HasKey( gamemodeKey ) && ( spawnpoint.kv[ gamemodeKey ] == "0" || spawnpoint.kv[ gamemodeKey ] == "" ) )
		return false

	if ( spawnpoint.IsOccupied() || ( "inuse" in spawnpoint.s && spawnpoint.s.inuse ) || ( "lastUsedTime" in spawnpoint.s && Time() - spawnpoint.s.lastUsedTime <= 10.0 ) || spawnpoint.e.spawnPointInUse )
		return false

	// don't drop onto a Titan that is already standing there (a player, or one of ours still landing)
	foreach ( entity titan in GetTitanArray() )
	{
		if ( IsAlive( titan ) && Distance2D( titan.GetOrigin(), spawnpoint.GetOrigin() ) < 200 )
			return false
	}

	return true
}

// average position of a team's living players, false if it has none
bool function CT_LTS_GetPlayersCenter( int team, table out )
{
	vector sum = < 0, 0, 0 >
	int n = 0
	foreach ( entity p in GetPlayerArrayOfTeam( team ) )
	{
		if ( !IsAlive( p ) )
			continue
		sum += p.GetOrigin()
		n++
	}
	if ( n == 0 )
		return false

	out.center <- sum * ( 1.0 / float( n ) )
	return true
}

// returns null when no start point fits, the caller then falls back to the normal Titan spawnpoints
entity function CT_LTS_GetSpawnpoint( int team )
{
	array<entity> free
	foreach ( entity sp in GetEntArrayByClass_Expensive( "info_spawnpoint_titan_start" ) )
	{
		if ( CT_LTS_IsStartSpawnFree( sp ) )
			free.append( sp )
	}
	if ( free.len() == 0 )
		return null

	table ours = {}
	table theirs = {}
	bool nearOurs = CT_LTS_GetPlayersCenter( team, ours )
	bool awayFromTheirs = !nearOurs && CT_LTS_GetPlayersCenter( GetOtherTeam( team ), theirs )
	if ( !nearOurs && !awayFromTheirs )
		return free.getrandom()

	vector anchor = nearOurs ? expect vector( ours.center ) : expect vector( theirs.center )

	// take the best few by distance to the anchor (closest next to our players, farthest away from theirs)
	// and pick a random one of them, so the Titans don't always stack on the same point
	array<entity> best
	while ( best.len() < 4 && free.len() > 0 )
	{
		int bestIndex = 0
		for ( int i = 1; i < free.len(); i++ )
		{
			float di = Distance2D( free[ i ].GetOrigin(), anchor )
			float db = Distance2D( free[ bestIndex ].GetOrigin(), anchor )
			if ( nearOurs ? ( di < db ) : ( di > db ) )
				bestIndex = i
		}
		best.append( free[ bestIndex ] )
		free.remove( bestIndex )
	}

	return best.getrandom()
}

// ---- elimination -----------------------------------------------------------

int function CT_LTS_CountPlayerTitans( int team )
{
	int n = 0
	foreach ( entity p in GetPlayerArrayOfTeam( team ) )
	{
		if ( IsAlive( p ) && p.IsTitan() )
			n++
	}
	return n
}

// No EndSignal on purpose: the loop ends by itself once the round leaves Playing,
// and roundId stops a thread from an older round from deciding a newer one.
void function CT_LTS_EliminationThink( int roundId )
{
	array<int> teams = [ TEAM_IMC, TEAM_MILITIA ]
	table lastLogged = { [TEAM_IMC] = "", [TEAM_MILITIA] = "" }

	printt( "[CT] LTS: round " + roundId + " elimination check running" )

	while ( GetGameState() == eGameState.Playing && roundId == file.roundId )
	{
		wait 0.5

		foreach ( team in teams )
		{
			int playerTitans = CT_LTS_CountPlayerTitans( team )
			int aiTitans = CT_CountAlive( team )
			bool deployed = CT_IsOpeningDone( team ) || CT_LTS_SpawnWindowClosed()

			// log whenever a team's numbers change, so a stuck round can be read from the console
			string status = "players " + playerTitans + ", AI " + aiTitans + ", had titans " + ( file.hadTitans[ team ] ? "yes" : "no" ) + ", deployed " + ( deployed ? "yes" : "no" )
			if ( status != lastLogged[ team ] )
			{
				lastLogged[ team ] = status
				printt( "[CT] LTS: team " + team + ": " + status )
			}

			if ( playerTitans + aiTitans > 0 )
			{
				file.hadTitans[ team ] = true
				continue
			}

			// a team that never had a Titan this round (AI still to drop, empty team) can't be eliminated,
			// and neither can one whose AI Titans are still being called in (at most CT_LTS_SPAWN_WINDOW seconds)
			if ( !file.hadTitans[ team ] || !deployed )
				continue

			int winner = GetOtherTeam( team )
			printt( "[CT] LTS: team " + team + " has no Titans left (players + AI), team " + winner + " wins the round" )
			SetWinner( winner, "#GAMEMODE_ENEMY_TITANS_DESTROYED", "#GAMEMODE_FRIENDLY_TITANS_DESTROYED" )
			return
		}
	}
}
