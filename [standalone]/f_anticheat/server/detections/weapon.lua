if not Config.Weapon.enabled then return end

if GetResourceState('ox_inventory') ~= 'started' then
    lib.print.warn('f_anticheat: ox_inventory is not running, unauthorized-weapon detection is disabled')
    return
end

-- hash -> ox_inventory item name, for every weapon ox_inventory ships by default.
-- extend this list if your server adds custom weapon items.
local WEAPON_NAMES = {
    'weapon_pistol', 'weapon_pistol_mk2', 'weapon_combatpistol', 'weapon_appistol', 'weapon_stungun',
    'weapon_pistol50', 'weapon_snspistol', 'weapon_snspistol_mk2', 'weapon_heavypistol', 'weapon_vintagepistol',
    'weapon_flaregun', 'weapon_marksmanpistol', 'weapon_revolver', 'weapon_revolver_mk2', 'weapon_doubleaction',
    'weapon_raypistol', 'weapon_ceramicpistol', 'weapon_navyrevolver', 'weapon_gadgetpistol',
    'weapon_microsmg', 'weapon_smg', 'weapon_smg_mk2', 'weapon_assaultsmg', 'weapon_combatpdw',
    'weapon_machinepistol', 'weapon_minismg', 'weapon_raycarbine',
    'weapon_pumpshotgun', 'weapon_pumpshotgun_mk2', 'weapon_sawnoffshotgun', 'weapon_assaultshotgun',
    'weapon_bullpupshotgun', 'weapon_musket', 'weapon_heavyshotgun', 'weapon_dbshotgun', 'weapon_autoshotgun',
    'weapon_assaultrifle', 'weapon_assaultrifle_mk2', 'weapon_carbinerifle', 'weapon_carbinerifle_mk2',
    'weapon_advancedrifle', 'weapon_specialcarbine', 'weapon_specialcarbine_mk2', 'weapon_bullpuprifle',
    'weapon_bullpuprifle_mk2', 'weapon_compactrifle', 'weapon_militaryrifle', 'weapon_heavyrifle',
    'weapon_mg', 'weapon_combatmg', 'weapon_combatmg_mk2', 'weapon_gusenberg',
    'weapon_sniperrifle', 'weapon_heavysniper', 'weapon_heavysniper_mk2', 'weapon_marksmanrifle',
    'weapon_marksmanrifle_mk2', 'weapon_precisionrifle',
    'weapon_rpg', 'weapon_grenadelauncher', 'weapon_grenadelauncher_smoke', 'weapon_minigun',
    'weapon_firework', 'weapon_railgun', 'weapon_hominglauncher', 'weapon_compactlauncher',
    'weapon_rayminigun', 'weapon_emplauncher',
    'weapon_grenade', 'weapon_bzgas', 'weapon_molotov', 'weapon_stickybomb', 'weapon_proxmine',
    'weapon_pipebomb', 'weapon_smokegrenade', 'weapon_flare', 'weapon_ball', 'weapon_snowball',
}

local HASH_TO_NAME = {}
for _, name in ipairs(WEAPON_NAMES) do
    HASH_TO_NAME[joaat(name)] = name
end

---@type table<integer, integer>
local lastWarned = {}

local function checkPlayer(source)
    local ped = GetPlayerPed(source --[[@as string]])
    if ped == 0 or not DoesEntityExist(ped) then return end

    local hasWeapon, weaponHash = GetCurrentPedWeapon(ped, true)
    if not hasWeapon or weaponHash == 0 or Config.Weapon.ignore[weaponHash] then return end

    local name = HASH_TO_NAME[weaponHash]
    if not name then return end -- unknown/custom weapon hash, nothing to cross-check it against

    if weaponHash == lastWarned[source] then return end -- already flagged this exact weapon this session

    local ok, count = pcall(function()
        return exports.ox_inventory:Search(source, 'count', name)
    end)

    if ok and (not count or count <= 0) then
        lastWarned[source] = weaponHash
        Punish.Flag(source, 'weapon', Config.Weapon.points, ('is holding %s but ox_inventory shows none in their inventory'):format(name))
    end
end

CreateThread(function()
    while true do
        Wait(Config.Weapon.tickMs)
        for _, playerId in ipairs(GetPlayers()) do
            local source = tonumber(playerId)
            local ok, err = pcall(checkPlayer, source)
            if not ok then
                lib.print.error(('f_anticheat weapon check failed for %s: %s'):format(source, err))
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    lastWarned[source] = nil
end)
