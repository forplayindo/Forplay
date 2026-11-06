---------------------------------------------------------------------------
-- Mode staff untuk diri sendiri. Server memeriksa izin + mencatat log lewat 'f_admin:self',
-- lalu efeknya dijalankan di sini. Setiap loop hanya hidup selama modenya menyala.
---------------------------------------------------------------------------
local state = { noclip = false, god = false, invis = false, names = false, blips = false, vehgod = false, ammo = false, cuff = false }

function SelfState() return state end

local function allowed(key, on, extra)
    if lib.callback.await('f_admin:self', false, key, on, extra) then return true end
    Notify('Tidak punya izin untuk aksi ini.', 'error')
    return false
end

---------------------------------------------------------------- noclip
local noclipCam
local NOCLIP_BLOCK = { 32, 33, 34, 35, 36, 12, 13, 14, 15, 16, 17 }
local function noclipLoop()
    local ent = cache.vehicle or cache.ped
    local inVeh = cache.vehicle ~= false and cache.vehicle ~= nil
    local pos, rot = GetEntityCoords(ent), GetEntityRotation(ent)
    noclipCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, rot.z, 75.0, true, 2)
    AttachCamToEntity(noclipCam, ent, 0.0, 0.0, 0.0, true)
    RenderScriptCams(true, false, 0, true, false)
    FreezeEntityPosition(ent, true)
    SetEntityCollision(ent, false, false)
    SetEntityVisible(ent, false, false)
    SetPedCanRagdoll(cache.ped, false)
    if inVeh then SetEntityVisible(cache.ped, false, false) else ClearPedTasksImmediately(cache.ped) end

    local speed = 1.0
    while state.noclip do
        local _, fv = GetCamMatrix(noclipCam)
        if IsDisabledControlPressed(2, 17) then speed = math.min(speed + 0.1, 32.0)
        elseif IsDisabledControlPressed(2, 16) then speed = math.max(0.1, speed - 0.1) end

        local mult = IsDisabledControlPressed(2, 209) and 2.0 or IsDisabledControlPressed(2, 19) and 4.0 or IsDisabledControlPressed(2, 36) and 0.25 or 1.0
        local s = speed * mult
        local p
        if IsDisabledControlPressed(2, 32) then p = GetEntityCoords(ent) + fv * s
        elseif IsDisabledControlPressed(2, 33) then p = GetEntityCoords(ent) - fv * s end
        if IsDisabledControlPressed(2, 34) then p = GetOffsetFromEntityInWorldCoords(ent, -s, 0.0, 0.0)
        elseif IsDisabledControlPressed(2, 35) then p = GetOffsetFromEntityInWorldCoords(ent, s, 0.0, 0.0) end
        if IsDisabledControlPressed(2, 51) then p = GetOffsetFromEntityInWorldCoords(ent, 0.0, 0.0, s / 2)
        elseif IsDisabledControlPressed(2, 52) then p = GetOffsetFromEntityInWorldCoords(ent, 0.0, 0.0, -s / 2) end
        if p then SetEntityCoordsNoOffset(ent, p.x, p.y, p.z, false, false, false) end

        -- putar kamera dengan mouse
        local ax, ay = GetDisabledControlNormal(0, 1), GetDisabledControlNormal(0, 2)
        if ax ~= 0 or ay ~= 0 then
            local sens = GetProfileSetting(14) * 2
            if GetProfileSetting(15) == 0 then sens = -sens end
            local r = GetCamRot(noclipCam, 2)
            local rx = r.x + ay * sens
            if rx < -150.0 or rx > 160.0 then rx = r.x end
            SetCamRot(noclipCam, rx, r.y, r.z + ax * sens, 2)
        end
        SetEntityHeading(ent, (360 + GetCamRot(noclipCam, 2).z) % 360)
        for i = 1, #NOCLIP_BLOCK do DisableControlAction(2, NOCLIP_BLOCK[i], true) end
        DisablePlayerFiring(cache.playerId, true)
        Wait(0)
    end

    DestroyCam(noclipCam, false)
    noclipCam = nil
    RenderScriptCams(false, false, 0, true, false)
    FreezeEntityPosition(ent, false)
    SetEntityCollision(ent, true, true)
    SetEntityVisible(ent, not state.invis, false)
    SetPedCanRagdoll(cache.ped, true)
    if inVeh then
        SetEntityVisible(cache.ped, not state.invis, false)
        SetPedIntoVehicle(cache.ped, ent, -1)
    end
end

---------------------------------------------------------------- nama & blip
local tags, blips, radar = {}, {}, {}

local function clearTags()
    for _, t in pairs(tags) do RemoveMpGamerTag(t) end
    tags = {}
end

local function clearBlips()
    for _, b in pairs(blips) do RemoveBlip(b) end
    blips = {}
end

local function radarLoop()
    while state.names or state.blips do
        local list = lib.callback.await('f_admin:radar', false)
        if not list then
            state.names, state.blips = false, false
            break
        end
        radar = {}
        for _, p in ipairs(list) do radar[p.id] = p end

        if state.blips then
            for id, b in pairs(blips) do
                if not radar[id] then RemoveBlip(b) blips[id] = nil end
            end
            for id, p in pairs(radar) do
                local b = blips[id]
                if not b then
                    b = AddBlipForCoord(p.c.x, p.c.y, p.c.z)
                    SetBlipSprite(b, 1)
                    SetBlipColour(b, 0)
                    SetBlipScale(b, 0.8)
                    SetBlipCategory(b, 7)
                    ShowHeadingIndicatorOnBlip(b, true)
                    blips[id] = b
                else
                    SetBlipCoords(b, p.c.x, p.c.y, p.c.z)
                end
                SetBlipSprite(b, p.v and 225 or 1)
                ShowHeadingIndicatorOnBlip(b, true)
                SetBlipRotation(b, p.h)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(('%d | %s'):format(id, p.name))
                EndTextCommandSetBlipName(b)
            end
        elseif next(blips) then
            clearBlips()
        end

        if state.names then
            for id, t in pairs(tags) do
                if not radar[id] or GetPlayerFromServerId(id) == -1 then RemoveMpGamerTag(t) tags[id] = nil end
            end
            for _, pl in ipairs(GetActivePlayers()) do
                local id = GetPlayerServerId(pl)
                local p = radar[id]
                if p and pl ~= cache.playerId then
                    local ped = GetPlayerPed(pl)
                    local t = tags[id]
                    if not t or not IsMpGamerTagActive(t) then
                        t = CreateFakeMpGamerTag(ped, ('%d | %s'):format(id, p.name), false, false, '', 0)
                        SetMpGamerTagAlpha(t, 2, 255)
                        SetMpGamerTagHealthBarColour(t, 25)
                        tags[id] = t
                    end
                    SetMpGamerTagVisibility(t, 0, true)
                    SetMpGamerTagVisibility(t, 2, true)
                    SetMpGamerTagVisibility(t, 4, NetworkIsPlayerTalking(pl))
                end
            end
        elseif next(tags) then
            clearTags()
        end
        Wait(1500)
    end
    clearTags()
    clearBlips()
end

---------------------------------------------------------------- toggle
local loops = {
    noclip = noclipLoop,
    god = function()
        while state.god do
            SetPlayerInvincible(cache.playerId, true)
            SetEntityInvincible(cache.ped, true)
            Wait(500)
        end
        SetPlayerInvincible(cache.playerId, false)
        SetEntityInvincible(cache.ped, false)
    end,
    invis = function()
        local t = 0
        while state.invis do
            if GetGameTimer() > t then
                SetEntityVisible(cache.ped, false, false)
                t = GetGameTimer() + 500
            end
            SetEntityLocallyVisible(cache.ped)
            SetEntityAlpha(cache.ped, 120, false)
            Wait(0)
        end
        ResetEntityAlpha(cache.ped)
        if not state.noclip then SetEntityVisible(cache.ped, true, false) end
    end,
    vehgod = function()
        while state.vehgod do
            local veh = cache.vehicle
            if veh then
                SetEntityInvincible(veh, true)
                SetEntityCanBeDamaged(veh, false)
                if GetVehicleEngineHealth(veh) < 1000.0 or GetVehicleBodyHealth(veh) < 1000.0 then SetVehicleFixed(veh) end
            end
            Wait(500)
        end
        if cache.vehicle then
            SetEntityInvincible(cache.vehicle, false)
            SetEntityCanBeDamaged(cache.vehicle, true)
        end
    end,
    ammo = function()
        while state.ammo do
            local w = GetSelectedPedWeapon(cache.ped)
            SetPedInfiniteAmmo(cache.ped, true, w)
            SetPedInfiniteAmmoClip(cache.ped, true)
            Wait(250)
        end
        SetPedInfiniteAmmo(cache.ped, false, GetSelectedPedWeapon(cache.ped))
        SetPedInfiniteAmmoClip(cache.ped, false)
    end,
    names = radarLoop,
    blips = radarLoop,
}

local function toggle(k)
    local on = not state[k]
    if k == 'cuff' then on = not LocalPlayer.state.cuffed end -- ikut status borgol asli (bisa juga diborgol polisi)
    if not allowed(k, on) then return { ok = false } end
    local radarRunning = state.names or state.blips
    state[k] = on
    if k == 'cuff' then
        if on then TriggerEvent('police:client:GetCuffed', cache.serverId, true) end -- lepas: server f_admin -> f_police
    elseif on and loops[k] and not ((k == 'names' or k == 'blips') and radarRunning) then
        CreateThread(loops[k])
    end
    local label = ({ noclip = 'Noclip', god = 'God mode', invis = 'Tidak terlihat', names = 'Nama pemain', blips = 'Blip pemain', vehgod = 'Godmode kendaraan', ammo = 'Amunisi tak terbatas', cuff = 'Borgol' })[k]
    Notify(('%s %s'):format(label, on and 'aktif' or 'mati'), on and 'success' or 'inform')
    return { ok = true, on = on, state = state }
end

ACT.self = function(d)
    if state[d.k] == nil then return { ok = false, msg = 'Mode tidak dikenal.' } end
    return toggle(d.k)
end

-- /noclip /names /blips dari chat
RegisterNetEvent('f_admin:client:toggle', function(k)
    if state[k] ~= nil then toggle(k) end
end)

---------------------------------------------------------------- aksi sekali
ACT.ped = function(d)
    local model = type(d.model) == 'string' and d.model:gsub('%s', '') or ''
    local hash = joaat(model)
    if model == '' or not IsModelInCdimage(hash) or not IsModelValid(hash) then return { ok = false, msg = 'Model tidak valid.' } end
    if not allowed('ped', true, model) then return { ok = false } end
    lib.requestModel(hash)
    SetPlayerModel(cache.playerId, hash)
    SetPedDefaultComponentVariation(cache.ped)
    SetModelAsNoLongerNeeded(hash)
    return { ok = true, msg = 'Model diganti ke ' .. model }
end

ACT.pedreset = function()
    TriggerEvent('illenium-appearance:client:reloadSkin', true)
    return { ok = true, msg = 'Karakter dikembalikan' }
end

ACT.tpm = function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return { ok = false, msg = 'Pasang waypoint di peta dulu.' } end
    if not allowed('tpm', true, GetEntityCoords(cache.ped)) then return { ok = false } end
    local c = GetBlipInfoIdCoord(blip)
    local ent = cache.vehicle or cache.ped
    CreateThread(function()
        DoScreenFadeOut(250)
        while not IsScreenFadedOut() do Wait(0) end
        FreezeEntityPosition(ent, true)
        local z = 0.0
        for h = 1, 1000, 25 do
            SetEntityCoordsNoOffset(ent, c.x, c.y, h + 0.0, false, false, false)
            RequestCollisionAtCoord(c.x, c.y, h + 0.0)
            Wait(30)
            local found, gz = GetGroundZFor_3dCoord(c.x, c.y, h + 0.0, false)
            if found then z = gz break end
        end
        SetEntityCoordsNoOffset(ent, c.x, c.y, z + 1.0, false, false, false)
        FreezeEntityPosition(ent, false)
        DoScreenFadeIn(250)
    end)
    return { ok = true, msg = 'Teleport ke waypoint', close = true }
end

ACT.fix = function(d)
    local veh = cache.vehicle
    if not veh then return { ok = false, msg = 'Kamu harus berada di kendaraan.' } end
    if not allowed('fix', true) then return { ok = false } end
    if d.clean then
        SetVehicleDirtLevel(veh, 0.0)
        WashDecalsFromVehicle(veh, 1.0)
        return { ok = true, msg = 'Kendaraan dibersihkan' }
    end
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    return { ok = true, msg = 'Kendaraan diperbaiki' }
end

ACT.dv = function()
    local veh = cache.vehicle
    if not veh then
        veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, true)
    end
    if not veh then return { ok = false, msg = 'Tidak ada kendaraan dalam 5 m.' } end
    if not NetworkGetEntityIsNetworked(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
        return { ok = true, msg = 'Kendaraan dihapus' }
    end
    return lib.callback.await('f_admin:veh_delete', false, { net = NetworkGetNetworkIdFromEntity(veh) })
end

ACT.tune = function()
    if not cache.vehicle then return { ok = false, msg = 'Kamu harus berada di kendaraan.' } end
    if GetResourceState('f_customs') ~= 'started' then return { ok = false, msg = 'f_customs tidak berjalan.' } end
    if not allowed('tune', true) then return { ok = false } end
    CloseNui()
    SetTimeout(150, function() exports.f_customs:OpenMenu() end)
    return { ok = true }
end

ACT.announce = function(d)
    local text = type(d.text) == 'string' and d.text:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if text == '' then return { ok = false, msg = 'Isi pengumuman.' } end
    if not allowed('announce', true, text) then return { ok = false } end
    ExecuteCommand('announceadmin ' .. text:gsub('[\r\n]+', ' '))
    return { ok = true, msg = 'Pengumuman terkirim' }
end

ACT.state = function() return { ok = true, state = state } end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if noclipCam then RenderScriptCams(false, false, 0, true, false) end
    if state.noclip or state.invis then
        local ent = cache.vehicle or cache.ped
        FreezeEntityPosition(ent, false)
        SetEntityCollision(ent, true, true)
        SetEntityVisible(cache.ped, true, false)
        ResetEntityAlpha(cache.ped)
    end
    if state.god then SetPlayerInvincible(cache.playerId, false) end
    clearTags()
    clearBlips()
end)
