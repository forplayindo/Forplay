# f_anticheat

Server-authoritative anti-cheat for this Qbox server. Everything runs on the
server; there is no client script, so there is nothing on a cheater's machine
for them to disable or bypass.

## What it catches

| Module | Detects | Default action |
|---|---|---|
| Entity spam | Object/vehicle/ped flood used to crash the server (`entityCreating`) | escalating points, cancels the entity |
| Explosion spam | Rapid explosion triggering | escalating points, cancels the explosion |
| Speed / teleport | Sustained movement beyond human/vehicle limits (3 consecutive samples required, so a single legit scripted teleport never trips it) | escalating points |
| Unauthorized weapon | Holding a weapon ox_inventory says you don't own (menu-spawned weapons) | escalating points |
| Invincibility | Repeated hits registered with no health loss | **log only** to Discord, never auto-punishes (too many legit systems - armor, downed state, medical revives - look identical) |

Points accumulate per player per session (`Config.Punish`):
warn at 3, kick at 6, permanent ban at 10 (tunable in `config.lua`). A category
can also be set to `instantBan` for a first-hit ban instead of accumulating.

## Setup

1. Set `Config.Webhook` in `config.lua` to a Discord webhook URL to receive
   alerts (bans, kicks, warnings, flags). Leave empty to disable Discord
   logging - everything is still written to the `f_anticheat_log` /
   `f_anticheat_bans` MySQL tables either way.
2. `ensure [standalone]` in your server.cfg already starts this automatically
   since it lives in that category folder.
3. Staff holding `Config.ExemptAce` (default `group.admin`) are never flagged.

## Admin commands (`group.admin`)

- `/ac status` - shows which modules are enabled
- `/ac points <id>` - check a player's current violation points
- `/ac resetpoints <id>` - clear a player's points (false-positive recovery)
- `/ac unban <license|discord|ip>` - remove a ban
- `/ac bans` - print the 10 most recent bans to console

## Known limitations - please read

This is a heuristic, best-effort system, not a substitute for FiveM's own
anti-cheat signal or a paid EAC-grade product. Specifically:

- **Speed detection** can never be perfectly tuned. Thresholds are set
  generously to avoid false-positiving supercars/planes and fall damage, which
  means a very disciplined speedhacker staying just under the limit could
  still slip through. Watch the webhook for a while after enabling and adjust
  `Config.Speed` if you see false positives from a specific vehicle/resource.
- **Weapon detection** only covers the standard GTA V weapon list. Custom
  weapon items need to be added to `WEAPON_NAMES` in
  `server/detections/weapon.lua`, and it does nothing if ox_inventory isn't
  running.
- **Invincibility detection is log-only on purpose.** It is not reliable
  enough to auto-punish without risking banning legitimately armored/downed
  players.
- This does **not** replace enabling FiveM's own built-in trust-score
  anti-cheat, which costs nothing and isn't currently on in this server.cfg.
  Recommended addition:
  ```
  set sv_authMaxVariance 1
  set sv_authMinTrust 5
  ```
- Nothing here validates money/item-granting events inside your ~45 custom
  job resources - that's a separate, much larger audit (checking every
  `RegisterNetEvent` that pays out money/items actually trusts server-side
  state and not client-supplied amounts).
- `qbx_core` already ships an unused `ExploitBan` function and an `anticheat`
  webhook slot in its own config, clearly intended for exactly this purpose
  but never wired up. This resource intentionally does **not** hook into it
  (it's `local`, not exported) so that a future `git pull` of qbx_core can't
  silently break this resource - it keeps its own independent ban table
  instead.
