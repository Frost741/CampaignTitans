untyped

#if CLIENT
global function CT_ServerCallback_InterruptDialogue
#endif // CLIENT

global function CT_NetSync_Init

// ---------------------------------------------------------------------------
// Registers a Northstar "remote function" (server -> client RPC) so the server
// can tell one specific listener's client to cut off whatever dialogue line is
// currently playing (Titan ready, TitanOS status lines, etc.) right before our
// enemy Titan's own line starts - see docs.northstar.tf/Modding/squirrel/networking
// ---------------------------------------------------------------------------

void function CT_NetSync_Init()
{
	AddCallback_OnRegisteringCustomNetworkVars( CT_RegisterNetworkFunctions )

	// Brute's kit isn't part of any MP loadout, so precache it on both VMs (like _items.nut does for NPC weapons)
	PrecacheWeapon( "mp_titanweapon_rocketeer_rocketstream" )
	PrecacheWeapon( "mp_titanweapon_homing_rockets" )
	PrecacheWeapon( "mp_titanability_rocketeer_ammo_swap" )
}

void function CT_RegisterNetworkFunctions()
{
	// must run identically on both CLIENT and SERVER or the client desyncs/disconnects
	Remote_RegisterFunction( "CT_ServerCallback_InterruptDialogue" )
}

#if CLIENT
// called on the listener's own client, right before the server plays our enemy Titan line to them
void function CT_ServerCallback_InterruptDialogue( int unused )
{
	entity player = GetLocalClientPlayer()
	if ( IsValid( player ) )
		CancelConversation( player )
}
#endif // CLIENT
