
> ❗ WARNING: This mod was created with the assistance of Claude AI, and files from ASillyNeko Attrition Extended Recode were used because Claude was unable to properly implement Titan spawning on its own.

TF2.CampaignTitans gives enemy AI Titans in Attrition the voice lines of regular enemy IMC Titans from the Titanfall 2 campaign.


> The mod uses Master difficulty. quoted textDon't try to play the hero and cut through the enemies, because they can catch you off guard.

**They will speak their campaign voice lines when:**


- They are killed.

-  detect the player.

-  lose one bar of health.

-  remove one bar of health from the player.

-  activate their Titan Core.

**The mod uses the following Titan classes:**


- Tone

- Ion

- Northstar

- Ronin

- Scorch

- Legion

*Voice Line Protection*

When I first added voice lines to enemy Titans, there was a problem: when they lost health quickly, they could immediately trigger another voice line before the previous one had finished playing.

To prevent voice lines from overlapping, a cooldown system was added. After an enemy Titan plays a voice line, it will not play another enemy voice line for 6 seconds.

However, if a Faction Leader or Titan OS voice line is currently playing, it can be interrupted so that the enemy Titan's voice line can be heard clearly. However, voice lines may still overlap in some situations. I don't know why this happens.

*Where are the mod settings located?*

Go to Options → Mod Settings and scroll all the way to the bottom. There you will find the TF2.CampaignTitans mod settings, available in both Russian and English.

## Configuration



| ConVar | Default | Description |
|---|---|---|
| `ct_titans_ally` | `2` | Titans on your team |
| `ct_titans_enemy` | `3` | Titans on the enemy team |
| `ct_respawn_delay` | `10` | Seconds after death before a replacement spawns |
| `ct_health_scale` | `1.0` | Health multiplier |
| `ct_damage_scale` | `1.9` | Damage dealt to players multiplier |
| `ct_random_camo` | `1` | Random camo per Titan (0/1) |
| `ct_private_only` | `0` | Only run in private matches (0/1) |
| `ct_gamemode` | `aitdm` | Restrict to this gamemode (empty = any) |
| `ct_core_chance` | `60` | Chance (%) a Titan is given a core ability |
| `ct_core_delay_min` / `ct_core_delay_max` | `20` / `45` | Core charge time range (seconds) |
| `ct_voice_range` | `6000` | Range at which enemies hear voice lines (0 = unlimited) |
| `ct_line_duration` | `6.0` | How long a voice line is considered "busy" |
| `ct_smoke_cooldown` | `15` | Anti-rodeo smoke cooldown per Titan (seconds) |