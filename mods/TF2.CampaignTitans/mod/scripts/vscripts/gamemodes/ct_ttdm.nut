untyped

global function CT_TTDM_IsActive
global function CT_TTDM_Init
global function CT_TTDM_GetAllyCount
global function CT_TTDM_GetEnemyCount
global function CT_TTDM_GetRespawnDelay

// ---------------------------------------------------------------------------
// Titan Brawl ("ttdm" in Northstar) support for TF2.CampaignTitans.
// ct_campaign_titans.nut runs the same Titan manager here, but takes its team
// sizes and respawn delay from the ct_ttdm_* convars below (3 on the players'
// team, 4 on the enemy team, respawn right after death by default).
//
// Scoring: Northstar's ttdm only gives the team a point when a PLAYER kills a
// PLAYER, so kills involving our AI Titans would count for nothing. This file
// adds 1 point (the same value as a player kill) for:
//  * an AI Titan of ours killed by anyone on the other team (player or NPC)
//  * a player killed by one of our AI Titans
// Player-vs-player kills are left to Northstar, so nothing is counted twice.
// ---------------------------------------------------------------------------

bool function CT_TTDM_IsActive()
{
	return GAMETYPE == "ttdm" && GetConVarInt( "ct_ttdm_enabled" ) == 1
}

// called by CampaignTitans_Init once the mod has decided to run in this match
void function CT_TTDM_Init()
{
	AddCallback_OnNPCKilled( CT_TTDM_OnNPCKilled )
	AddCallback_OnPlayerKilled( CT_TTDM_OnPlayerKilled )
	printt( "[CT] Titan Brawl: " + CT_TTDM_GetAllyCount() + " ally / " + CT_TTDM_GetEnemyCount() + " enemy AI Titans, respawn delay " + CT_TTDM_GetRespawnDelay() + "s, AI kills score" )
}

int function CT_TTDM_GetAllyCount()
{
	return GetConVarInt( "ct_ttdm_titans_ally" )
}

int function CT_TTDM_GetEnemyCount()
{
	return GetConVarInt( "ct_ttdm_titans_enemy" )
}

float function CT_TTDM_GetRespawnDelay()
{
	return GetConVarFloat( "ct_ttdm_respawn_delay" )
}

// ---- scoring ---------------------------------------------------------------

void function CT_TTDM_AddScore( int team, int amount )
{
	if ( GetGameState() != eGameState.Playing )
		return
	if ( team != TEAM_IMC && team != TEAM_MILITIA )
		return

	// same cap as the other modes use, so the score never goes past the limit
	int limit = GetScoreLimit_FromPlaylist()
	int score = GameRules_GetTeamScore( team )
	if ( score + amount > limit )
		amount = limit - score
	if ( amount <= 0 )
		return

	AddTeamScore( team, amount )
}

// one of our AI Titans died
void function CT_TTDM_OnNPCKilled( entity victim, entity attacker, var damageInfo )
{
	if ( !CT_IsOurs( victim ) )
		return
	if ( !IsValid( attacker ) || attacker.GetTeam() == victim.GetTeam() )
		return // suicide, fall, team kill: no point

	CT_TTDM_AddScore( attacker.GetTeam(), 1 )
}

// a player died to one of our AI Titans (player kills are scored by Northstar itself)
void function CT_TTDM_OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if ( !CT_IsOurs( attacker ) )
		return
	if ( attacker.GetTeam() == victim.GetTeam() )
		return

	CT_TTDM_AddScore( attacker.GetTeam(), 1 )
}
