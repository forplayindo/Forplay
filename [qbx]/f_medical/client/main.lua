local config = require 'config.client'
local sharedConfig = require 'config.shared'

---@type table<number, boolean> weapon hashes as a set
WeaponsThatDamagedPlayer = {}

NumInjuries = 0

local playerState = LocalPlayer.state

---@type table<BodyPartKey, Injury>
Injuries = {}

for bodyPartKey in pairs(sharedConfig.bodyParts) do
    local bodyPartStateBag = BODY_PART_STATE_BAG_PREFIX .. bodyPartKey
    Injuries[bodyPartKey] = playerState[bodyPartStateBag]
    AddStateBagChangeHandler(bodyPartStateBag, ('player:%s'):format(cache.serverId), function(_, _, value)
        Injuries[bodyPartKey] = value
    end)
end

function SetInjury(bodyPartKey, severity)
    playerState:set(BODY_PART_STATE_BAG_PREFIX .. bodyPartKey, severity, true)
end

BleedLevel = playerState[BLEED_LEVEL_STATE_BAG] or 0

AddStateBagChangeHandler(BLEED_LEVEL_STATE_BAG, ('player:%s'):format(cache.serverId), function(_, _, value)
    BleedLevel = value
end)

function SetBleedLevel(level)
    playerState:set(BLEED_LEVEL_STATE_BAG, level, true)
end

DeathState = playerState[DEATH_STATE_STATE_BAG] or sharedConfig.deathState.ALIVE

AddStateBagChangeHandler(DEATH_STATE_STATE_BAG, ('player:%s'):format(cache.serverId), function(_, _, value)
    DeathState = value
end)

function SetDeathState(deathState)
    playerState:set(DEATH_STATE_STATE_BAG, deathState, true)
    DeathState = deathState

    -- f_hud & f_radialmenu dengerin event ini buat tahu player lagi mati/last-stand (misal
    -- buat maksa health bar jadi 0%), tapi sebelumnya tidak ada resource manapun yang men-trigger-nya
    TriggerServerEvent('hospital:server:SetDeathStatus', deathState ~= sharedConfig.deathState.ALIVE)
end

BleedTickTimer, AdvanceBleedTimer = 0, 0
FadeOutTimer, BlackoutTimer = 0, 0

---@type number
Hp = nil

DeathTime = 0
LaststandTime = 0
RespawnHoldTime = 5
LastStandDict = 'combat@damage@writhe'
LastStandAnim = 'writhe_loop'

exports('IsDead', function()
    return DeathState == sharedConfig.deathState.DEAD
end)

exports('IsLaststand', function()
    return DeathState == sharedConfig.deathState.LAST_STAND
end)

exports('GetDeathTime', function()
    return DeathTime
end)

exports('GetLaststandTime', function()
    return LaststandTime
end)

exports('IncrementDeathTime', function(seconds)
    DeathTime += seconds
end)

exports('IncrementLaststandTime', function(seconds)
    LaststandTime += seconds
end)

exports('GetRespawnHoldTimeDeprecated', function()
    return RespawnHoldTime
end)

lib.callback.register('f_medical:client:killPlayer', function()
    SetEntityHealth(cache.ped, 0)
end)

---@return boolean isInjuryCausingLimp if injury causes a limp and is damaged.
local function isInjuryCausingLimp()
    for bodyPartKey in pairs(Injuries) do
        if sharedConfig.bodyParts[bodyPartKey].causeLimp then
            return true
        end
    end
    return false
end

---notify the player of damage to their body.
local function doLimbAlert()
    if DeathState ~= sharedConfig.deathState.ALIVE or NumInjuries == 0 then return end

    local limbDamageMsg = ''
    if NumInjuries <= config.alertShowInfo then
        local i = 0
        for bodyPartKey, injury in pairs(Injuries) do
            local bodyPart = sharedConfig.bodyParts[bodyPartKey]
            limbDamageMsg = limbDamageMsg .. locale('info.pain_message', bodyPart.label, sharedConfig.woundLevels[injury.severity].label)
            i += 1
            if i < NumInjuries then
                limbDamageMsg = limbDamageMsg .. ' | '
            end
        end
    else
        limbDamageMsg = locale('info.many_places')
    end
    exports.qbx_core:Notify(limbDamageMsg, 'error')
end

---sets ped animation to limping and prevents running.
function MakePedLimp()
    if not isInjuryCausingLimp() then return end
    lib.requestAnimSet('move_m@injured', 5000)
    SetPedMovementClipset(cache.ped, 'move_m@injured', 1)
    SetPlayerSprint(cache.playerId, false)
end

--- TODO: this export should not check any conditions, but force the ped to limp instead.
exports('MakePedLimp', MakePedLimp)

local function resetMinorInjuries()
    for bodyPartKey, injury in pairs(Injuries) do
        if injury.severity <= 2 then
            SetInjury(bodyPartKey, nil)
            NumInjuries -= 1
        end
    end

    if BleedLevel <= 2 then
        SetBleedLevel(0)
        BleedTickTimer = 0
        AdvanceBleedTimer = 0
        FadeOutTimer = 0
        BlackoutTimer = 0
    end

    SendBleedAlert()
    MakePedLimp()
    doLimbAlert()
end

local function resetAllInjuries()
    for bodyPartKey in pairs(sharedConfig.bodyParts) do
        SetInjury(bodyPartKey, nil)
    end
    NumInjuries = 0
    SetBleedLevel(0)
    BleedTickTimer = 0
    AdvanceBleedTimer = 0
    FadeOutTimer = 0
    BlackoutTimer = 0

    WeaponsThatDamagedPlayer = {}

    SendBleedAlert()
    MakePedLimp()
    doLimbAlert()
    -- non-blocking: kalau response hilang (resource restart / reconnect), revive tidak ikut tertahan 5 menit
    lib.callback('f_medical:server:resetHungerAndThirst', false, function() end)
end

---notify the player of bleeding to their body.
function SendBleedAlert()
    if DeathState == sharedConfig.deathState.DEAD or BleedLevel == 0 then return end
    exports.qbx_core:Notify(locale('info.bleed_alert', sharedConfig.bleedingStates[BleedLevel]), 'inform')
end

exports('SendBleedAlert', SendBleedAlert)

---adds a bleed to the player and alerts them. Total bleed level maxes at 4.
---@param level 1|2|3|4 speed of the bleed
function ApplyBleed(level)
    if BleedLevel == 4 then return end
    local newBleedLevel = level + BleedLevel
    if newBleedLevel > 4 then
        SetBleedLevel(4)
    else
        SetBleedLevel(newBleedLevel)
    end
    SendBleedAlert()
end

---Hitung ulang NumInjuries dari tabel Injuries dan sesuaikan pincang. Dipakai setelah luka dihapus
---satu per satu (panel Cek Pasien), supaya counter tidak selisih dan thread move-rate tidak error.
local function refreshInjuryState()
    local count = 0
    for _ in pairs(Injuries) do count += 1 end
    NumInjuries = count
    if isInjuryCausingLimp() then
        MakePedLimp()
    else
        ResetPedMovementClipset(cache.ped, 0.0)
        SetPlayerSprint(cache.playerId, true)
    end
end

-- Event di bawah dipicu SERVER (f_medical exports) setelah tindakan EMS divalidasi.

---@param bodyPartKey BodyPartKey
RegisterNetEvent('f_medical:client:healPart', function(bodyPartKey)
    if not sharedConfig.bodyParts[bodyPartKey] or not Injuries[bodyPartKey] then return end
    SetInjury(bodyPartKey, nil)
    Injuries[bodyPartKey] = nil
    refreshInjuryState()
end)

---@param level integer
RegisterNetEvent('f_medical:client:setBleed', function(level)
    level = math.max(0, math.min(4, math.floor(tonumber(level) or 0)))
    SetBleedLevel(level)
    BleedLevel = level
    if level == 0 then
        BleedTickTimer, AdvanceBleedTimer, FadeOutTimer, BlackoutTimer = 0, 0, 0, 0
    end
end)

---@param pct integer darah 0-100 (sama dengan bar HUD: health - 100)
RegisterNetEvent('f_medical:client:setBloodPct', function(pct)
    if DeathState ~= sharedConfig.deathState.ALIVE then return end
    pct = math.max(1, math.min(100, math.floor(tonumber(pct) or 0)))
    SetEntityMaxHealth(cache.ped, 200)
    SetEntityHealth(cache.ped, 100 + pct)
    Hp = 100 + pct
end)

---heals player wounds.
---@param type? 'full'|any heals all wounds if full otherwise heals only major wounds.
RegisterNetEvent('f_medical:client:heal', function(type)
    if type == 'full' then
        resetAllInjuries()
    else
        resetMinorInjuries()
    end

    exports.qbx_core:Notify(locale('success.wounds_healed'), 'success')
end)

CreateThread(function()
    while true do
        Wait((1000 * config.messageTimer))
        doLimbAlert()
    end
end)

---Revives player, healing all injuries.
---@param opts? { keepInjuries?: boolean, bloodPct?: integer } revive EMS lapangan: luka tetap, darah sesuai bloodPct
RegisterNetEvent('f_medical:client:playerRevived', function(opts)
    if DeathState ~= sharedConfig.deathState.ALIVE then
        local pos = GetEntityCoords(cache.ped, true)
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(cache.ped), true, false)
        SetDeathState(sharedConfig.deathState.ALIVE)
        SetEntityInvincible(cache.ped, false)
        EndLastStand()
    end

    if type(opts) == 'table' and opts.keepInjuries then
        local pct = math.max(1, math.min(100, math.floor(tonumber(opts.bloodPct) or 25)))
        SetEntityMaxHealth(cache.ped, 200)
        SetEntityHealth(cache.ped, 100 + pct)
        Hp = 100 + pct
        ClearPedTasks(cache.ped)
        refreshInjuryState()
        LocalPlayer.state.invBusy = false
        exports.qbx_core:Notify(locale('info.healthy'), 'inform')
        return
    end

    SetEntityMaxHealth(cache.ped, 200)
    SetEntityHealth(cache.ped, 200)
    ClearPedBloodDamage(cache.ped)
    SetPlayerSprint(cache.playerId, true)
    resetAllInjuries()
    ResetPedMovementClipset(cache.ped, 0.0)
    TriggerServerEvent('hud:server:RelieveStress', 100)
    exports.qbx_core:Notify(locale('info.healthy'), 'inform')
    LocalPlayer.state.invBusy = false
end)