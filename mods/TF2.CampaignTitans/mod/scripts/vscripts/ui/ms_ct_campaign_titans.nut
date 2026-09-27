global function CT_AddModSettings

// ---------------------------------------------------------------------------
// Adds a "TF2.CampaignTitans" page to Northstar's Mod Settings menu (main menu ->
// Mods -> Mod Settings) with every convar of this mod, grouped by category.
// Since a private match is a listen server (server + client in the same game
// process), changing a value here changes it for the match you're about to host.
// See docs.northstar.tf/Modding/reference/northstar/modsettings
// ---------------------------------------------------------------------------

void function CT_AddModSettings()
{
	ModSettings_AddModTitle( "#CT_MOD_TITLE" )

	ModSettings_AddModCategory( "#CT_CAT_TITANS" )
	ModSettings_AddSliderSetting( "ct_titans_ally", "#CT_SET_ALLY", 0, 6, 1, true )
	ModSettings_AddSliderSetting( "ct_titans_enemy", "#CT_SET_ENEMY", 0, 6, 1, true )
	ModSettings_AddSliderSetting( "ct_respawn_delay", "#CT_SET_RESPAWN", 0, 60, 1, true )
	ModSettings_AddSliderSetting( "ct_health_scale", "#CT_SET_HEALTH", 0.25, 3.0, 0.05 )
	ModSettings_AddSliderSetting( "ct_damage_scale", "#CT_SET_DAMAGE", 0.25, 3.0, 0.05 )
	ModSettings_AddEnumSetting( "ct_random_camo", "#CT_SET_CAMO", [ "#CT_OFF", "#CT_ON" ] )

	ModSettings_AddModCategory( "#CT_CAT_MATCH" )
	ModSettings_AddEnumSetting( "ct_private_only", "#CT_SET_PRIVATE", [ "#CT_OFF", "#CT_ON" ] )
	ModSettings_AddSetting( "ct_gamemode", "#CT_SET_GAMEMODE", "string" )

	ModSettings_AddModCategory( "#CT_CAT_TTDM" )
	ModSettings_AddEnumSetting( "ct_ttdm_enabled", "#CT_SET_TTDM_ENABLED", [ "#CT_OFF", "#CT_ON" ] )
	ModSettings_AddSliderSetting( "ct_ttdm_titans_ally", "#CT_SET_ALLY", 0, 6, 1, true )
	ModSettings_AddSliderSetting( "ct_ttdm_titans_enemy", "#CT_SET_ENEMY", 0, 8, 1, true )
	ModSettings_AddSliderSetting( "ct_ttdm_respawn_delay", "#CT_SET_RESPAWN", 0, 60, 1, true )

	ModSettings_AddModCategory( "#CT_CAT_LTS" )
	ModSettings_AddEnumSetting( "ct_lts_enabled", "#CT_SET_LTS_ENABLED", [ "#CT_OFF", "#CT_ON" ] )
	ModSettings_AddSliderSetting( "ct_lts_titans_ally", "#CT_SET_ALLY", 0, 6, 1, true )
	ModSettings_AddSliderSetting( "ct_lts_titans_enemy", "#CT_SET_ENEMY", 0, 8, 1, true )

	ModSettings_AddModCategory( "#CT_CAT_CORE" )
	ModSettings_AddSliderSetting( "ct_core_chance", "#CT_SET_CORE_CHANCE", 0, 100, 5, true )
	ModSettings_AddSliderSetting( "ct_core_delay_min", "#CT_SET_CORE_MIN", 5, 120, 1, true )
	ModSettings_AddSliderSetting( "ct_core_delay_max", "#CT_SET_CORE_MAX", 5, 120, 1, true )
	ModSettings_AddSliderSetting( "ct_monarch_core_delay_min", "#CT_SET_MONARCH_CORE_MIN", 3, 120, 1, true )
	ModSettings_AddSliderSetting( "ct_monarch_core_delay_max", "#CT_SET_MONARCH_CORE_MAX", 3, 120, 1, true )

	ModSettings_AddModCategory( "#CT_CAT_VOICE" )
	ModSettings_AddSliderSetting( "ct_voice_range", "#CT_SET_VOICE_RANGE", 0, 10000, 500, true )
	ModSettings_AddSliderSetting( "ct_line_duration", "#CT_SET_LINE_DURATION", 1, 15, 0.5 )
	ModSettings_AddSliderSetting( "ct_smoke_cooldown", "#CT_SET_SMOKE_COOLDOWN", 0, 60, 1, true )
}
