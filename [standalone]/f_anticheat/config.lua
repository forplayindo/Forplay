Config = {}

-- Discord webhook that receives every alert this resource raises. Leave empty to disable.
Config.Webhook = ''

-- Player identifiers matching these ACE permissions are never flagged or punished.
-- (staff testing spawn menus, noclip, etc. should not trip the detectors)
-- f_admin: diberikan ke Owner, dan ke Admin/Support kalau dicentang di Daftar Command (anticheat.exempt).
Config.ExemptAce = 'f_admin.anticheat.exempt'

-- Grup yang boleh memakai command /ac
Config.CommandGroup = 'group.admin'

-- ============================================================================
-- Punishment engine
-- Every detector calls Punish.Flag(source, category, severity, reason) instead
-- of kicking/banning directly. Severity points accumulate per player per
-- session and cross a threshold to decide the action taken.
-- ============================================================================
Config.Punish = {
    warnThreshold = 3,   -- points -> chat warning to the player
    kickThreshold = 6,   -- points -> DropPlayer
    banThreshold  = 10,  -- points -> permanent ban (stored in this resource's own table)

    -- some categories are dangerous enough to skip straight to a ban on the
    -- first confirmed hit, regardless of accumulated points
    instantBan = {
        entityspam = false,
        explosion  = false,
        weapon     = false,
        speed      = false,
    },
}

-- ============================================================================
-- Entity spam (object/vehicle/ped flood used to crash the server)
-- ============================================================================
Config.EntitySpam = {
    enabled = true,
    windowMs = 10000,      -- sliding window
    maxObjects = 20,       -- created props/objects allowed per window
    maxVehicles = 8,       -- created vehicles allowed per window
    maxPeds = 8,           -- created peds (non-player) allowed per window
    points = 4,
}

-- ============================================================================
-- Explosion spam
-- ============================================================================
Config.Explosion = {
    enabled = true,
    windowMs = 10000,
    maxExplosions = 5,     -- legit gameplay (grenades, rpg fights) rarely exceeds this
    points = 5,
}

-- ============================================================================
-- Speed / teleport / flying anomaly detection
-- Pure server-side polling of networked ped position - no client script
-- required, so there is nothing running on the cheater's machine to disable.
-- A single instantaneous jump (a legit scripted teleport: garage, property,
-- /tp, death respawn, house robbery marker, etc.) is intentionally NOT enough
-- to flag - only SUSTAINED movement beyond human/vehicle limits over several
-- consecutive samples counts, which one-off teleports never produce.
-- ============================================================================
Config.Speed = {
    enabled = true,
    tickMs = 1000,             -- how often to sample each player's position
    requiredConsecutive = 3,   -- consecutive over-limit samples needed to flag
    maxSpeedOnFootMs = 12.0,   -- m/s, sprint + stamina perks top out well under this
    maxSpeedInVehicleMs = 90.0,-- m/s (~324 km/h), covers supercars/planes with margin
    maxSpeedFallingMs = 60.0,  -- m/s, free-fall / parachute opening allowance
    points = 2,
}

-- ============================================================================
-- Unauthorized weapon detection (menu-spawned weapons the player never
-- received through ox_inventory)
-- ============================================================================
Config.Weapon = {
    enabled = true,
    tickMs = 2000,
    points = 5,
    -- weapons ignored entirely (unarmed, melee that's always available, etc.)
    ignore = {
        [`weapon_unarmed`] = true,
    },
}

-- ============================================================================
-- Weapon damage / invincibility monitor
-- False-positive prone (armor, downed state, medical revive, PVP toggle all
-- look similar), so this ONLY logs to the webhook for staff review - it never
-- auto-punishes.
-- ============================================================================
Config.Health = {
    enabled = true,
    logOnly = true,
}
