-- Carry (pikul bahu) & Gendong (punggung) untuk pemain yang SADAR, lewat ox_target.
-- Pemain pingsan / diborgol memakai opsi "Carry / Lepas" dari f_police (bisa masuk mobil,
-- bagasi, meja operasi EMS) -> opsi di sini disembunyikan untuk target seperti itu.
-- Status dipegang server (statebag 'carry'), tanpa persetujuan target. [X] = lepas (dua pihak).

local MODES = {
    bahu = {
        carrier = { dict = 'missfinale_c2mcs_1', clip = 'fin_c2_mcs_1_camman', flag = 49 },
        carried = { dict = 'nm', clip = 'firemans_carry', flag = 33 },
        offset = vec3(0.27, 0.15, 0.63),
    },
    punggung = {
        carrier = { dict = 'anim@arena@celeb@flat@paired@no_props@', clip = 'piggyback_c_player_a', flag = 49 },
        carried = { dict = 'anim@arena@celeb@flat@paired@no_props@', clip = 'piggyback_c_player_b', flag = 33 },
        offset = vec3(0.0, -0.07, 0.45),
    },
}

local BLOCK_CARRIER = { 21, 22, 23, 24, 25, 37, 44, 140, 141, 142, 257, 263 }
local BLOCK_CARRIED = { 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 44, 140, 141, 142, 257, 263 }

---@type { role: 'carrier'|'carried', other: integer, mode: string }?
local current
local nextRequest = 0

local function serverIdOf(ped)
    local idx = NetworkGetPlayerIndexFromPed(ped)
    if idx == -1 then return end
    return GetPlayerServerId(idx)
end

local function pedOf(serverId)
    local idx = GetPlayerFromServerId(serverId)
    if idx == -1 then return 0 end
    return GetPlayerPed(idx)
end

---Status yang membuat pemain tidak bisa membawa / dibawa (statebag dari server).
local function blocked(state)
    return state.carry ~= nil or state.cuffed or state.isDead or state.hostage or state.trunkVictim
end

local function selfFree()
    if current or cache.vehicle or cache.weapon then return false end
    local md = QBX.PlayerData.metadata
    if md.ishandcuffed or md.isdead or md.inlaststand then return false end
    if blocked(LocalPlayer.state) then return false end
    if GetEntityAttachedTo(cache.ped) ~= 0 then return false end -- sedang diseret / dibawa script lain
    if IsEntityPlayingAnim(cache.ped, 'missfinale_c2mcs_1', 'fin_c2_mcs_1_camman', 3) then return false end -- carry f_police
    return not IsPedFalling(cache.ped) and not IsPedSwimming(cache.ped)
end

local function canCarry(entity)
    if not selfFree() then return false end
    if IsPedInAnyVehicle(entity, true) or IsPedDeadOrDying(entity, true) or IsPedRagdoll(entity) then return false end
    if GetEntityAttachedTo(entity) ~= 0 then return false end
    local id = serverIdOf(entity)
    return id ~= nil and not blocked(Player(id).state)
end

local function request(entity, mode)
    local now = GetGameTimer()
    if now < nextRequest then return end
    nextRequest = now + 1500
    local id = serverIdOf(entity)
    if id then TriggerServerEvent('f_carry:server:start', id, mode) end
end

local function playAnim(anim)
    TaskPlayAnim(cache.ped, anim.dict, anim.clip, 8.0, -8.0, -1, anim.flag, 0, false, false, false)
end

local function attach(otherPed, cfg)
    AttachEntityToEntity(cache.ped, otherPed, 0, cfg.offset.x, cfg.offset.y, cfg.offset.z, 0.5, 0.5, 0.0,
        false, false, false, false, 2, false)
end

local function release()
    if not current then return end
    local token = current
    current = nil
    lib.hideTextUI()
    LocalPlayer.state.invBusy = false
    local anim = MODES[token.mode][token.role]
    if token.role == 'carried' then
        DetachEntity(cache.ped, true, false)
    end
    StopAnimTask(cache.ped, anim.dict, anim.clip, 1.0)
    ClearPedSecondaryTask(cache.ped)
    RemoveAnimDict(anim.dict)
end

local function stop()
    if not current then return end
    TriggerServerEvent('f_carry:server:stop')
    release() -- lepas lokal langsung; balasan server jadi no-op
end

---Pengawas selama membawa / dibawa: anim, tempelan, dan syarat lepas otomatis.
local function watch(token)
    local cfg = MODES[token.mode]
    local anim = cfg[token.role]
    while current == token do
        local otherPed = pedOf(token.other)
        local md, st = QBX.PlayerData.metadata, LocalPlayer.state
        if otherPed == 0 or not DoesEntityExist(otherPed)
            or md.isdead or md.inlaststand or md.ishandcuffed
            or st.isDead or st.cuffed or st.hostage or st.trunkVictim
            or cache.vehicle
            or #(GetEntityCoords(cache.ped) - GetEntityCoords(otherPed)) > 4.0
        then
            stop()
            break
        end
        if token.role == 'carried' and GetEntityAttachedTo(cache.ped) ~= otherPed then attach(otherPed, cfg) end
        if not IsEntityPlayingAnim(cache.ped, anim.dict, anim.clip, 3) then playAnim(anim) end
        Wait(250)
    end
end

local function blockControls(token)
    local list = token.role == 'carrier' and BLOCK_CARRIER or BLOCK_CARRIED
    while current == token do
        for i = 1, #list do DisableControlAction(0, list[i], true) end
        Wait(0)
    end
end

RegisterNetEvent('f_carry:client:start', function(role, other, mode)
    local cfg = MODES[mode]
    if not cfg or (role ~= 'carrier' and role ~= 'carried') then return end
    if current then release() end

    local otherPed = pedOf(other)
    if otherPed == 0 then return TriggerServerEvent('f_carry:server:stop') end

    local token = { role = role, other = other, mode = mode }
    current = token
    LocalPlayer.state.invBusy = true

    local anim = cfg[role]
    lib.requestAnimDict(anim.dict)
    if role == 'carried' then attach(otherPed, cfg) end
    playAnim(anim)

    lib.showTextUI(role == 'carrier' and '[X] Turunkan' or '[X] Turun')
    CreateThread(function() watch(token) end)
    CreateThread(function() blockControls(token) end)
end)

RegisterNetEvent('f_carry:client:release', release)

lib.addKeybind({
    name = 'f_carry_lepas',
    description = 'Lepas Carry / Gendong',
    defaultKey = 'X',
    onReleased = stop,
})

exports.ox_target:addGlobalPlayer({
    {
        name = 'f_carry:bahu',
        icon = 'fa-solid fa-people-carry-box',
        label = 'Carry (Pikul Bahu)',
        distance = 1.5,
        canInteract = canCarry,
        onSelect = function(data) request(data.entity, 'bahu') end,
    },
    {
        name = 'f_carry:punggung',
        icon = 'fa-solid fa-person-hiking',
        label = 'Gendong (Punggung)',
        distance = 1.5,
        canInteract = canCarry,
        onSelect = function(data) request(data.entity, 'punggung') end,
    },
})

AddEventHandler('onResourceStop', function(name)
    if name ~= cache.resource then return end
    release()
end)
