return {
    runClearCronMinutes = 5,
    distanceToHandKeys = 3,
    distanceToVehicle = 7.5,             -- Max distance (m) between a player and a vehicle for server-side key-grant events to be honored. Prevents granting keys to vehicles the player isn't actually next to.
    lockDistance = 25.0,                 -- Max distance (m) to lock/unlock a vehicle (key fob range)
    theftDistance = 4.0,                 -- Max distance (m) to a vehicle while lockpicking / duplicating / upgrading
    newVehicleKeyWindow = 60,            -- Seconds after a script spawned (non-owned) vehicle is created during which a client may claim its keys (job / rental vehicles)
    newVehicleClaimDistance = 30.0,      -- Max distance (m) to such a fresh vehicle when claiming its keys (spawn points can be away from the player)
    carjackCooldown = 10000,             -- ms between carjack rolls per player
    findKeysCooldown = 15000,            -- ms between key search rolls per player
    ---@type table<WeaponTypeGroup, number>
    carjackChance = {                    -- Probability of successful carjacking based on weapon used
        [WeaponTypeGroup.MELEE] = 0.0,
        [WeaponTypeGroup.HANDGUN] = 0.5,
        [WeaponTypeGroup.SMG] = 0.75,
        [WeaponTypeGroup.SHOTGUN] = 0.90,
        [WeaponTypeGroup.RIFLE] = 0.90,
        [WeaponTypeGroup.LMG] = 0.99,
        [WeaponTypeGroup.SNIPER] = 0.99,
        [WeaponTypeGroup.HEAVY] = 0.99,
        [WeaponTypeGroup.THROWABLE] = 0.0,
        [WeaponTypeGroup.MISC] = 0.0,
    },
}
