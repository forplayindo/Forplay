-- Performa:
--  * Tidak ada thread sama sekali saat tidak ada combat log.
--  * Saat ada log tapi jauh: cek jarak tiap 500 ms saja.
--  * Per-frame hanya saat ada log dalam Config.DrawDistance, dan NUI
--    hanya dikirimi data kalau posisi di layar benar-benar berubah.

local logs = {}          -- [id] = log
local count = 0
local running = false
local nearestId = nil    -- log yang bisa disalin (dalam CopyDistance)
local uiVisible = false

local mc = Config.MarkerColor

local function nui(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function removeLog(id)
    if not logs[id] then return end
    logs[id] = nil
    count -= 1
    nui('remove', id)
end

local function groundZ(c)
    local found, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
    if found then return z end
    return c.z - 0.98
end

local function hideAll()
    if uiVisible then
        uiVisible = false
        nui('hideAll')
    end
end

local function loop()
    if running then return end
    running = true

    CreateThread(function()
        local lastSig = nil

        while count > 0 do
            local now = GetGameTimer()
            for id, log in pairs(logs) do
                if now >= log.expiresAt then removeLog(id) end
            end

            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local anyNear = false
            for _, log in pairs(logs) do
                if #(pos - log.coords) <= Config.DrawDistance then anyNear = true break end
            end

            if not anyNear or IsPauseMenuActive() then
                nearestId = nil
                lastSig = nil
                hideAll()
                Wait(500)
            else
                local items, sig = {}, {}
                local best, bestDist = nil, Config.CopyDistance

                for id, log in pairs(logs) do
                    local dist = #(pos - log.coords)
                    if dist <= Config.DrawDistance then
                        if not log.gz then log.gz = groundZ(log.coords) end
                        local c = log.coords

                        DrawMarker(25, c.x, c.y, log.gz + 0.03, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            1.4, 1.4, 1.0, mc.r, mc.g, mc.b, mc.a, false, false, 2, false, nil, nil, false)

                        local onG, gx, gy = GetScreenCoordFromWorldCoord(c.x, c.y, log.gz + 0.03)
                        local onT, tx, ty = GetScreenCoordFromWorldCoord(c.x, c.y, log.gz + Config.CardHeight)

                        if onG and onT then
                            if dist < bestDist then best, bestDist = id, dist end
                            -- dibulatkan supaya perubahan kecil tidak memicu update NUI
                            gx, gy = math.floor(gx * 1000), math.floor(gy * 1000)
                            tx, ty = math.floor(tx * 1000), math.floor(ty * 1000)
                            local d = math.floor(dist)
                            items[#items + 1] = { id = id, gx = gx, gy = gy, tx = tx, ty = ty, dist = d }
                            sig[#sig + 1] = id .. ':' .. gx .. ',' .. gy .. ',' .. tx .. ',' .. ty .. ',' .. d
                        end
                    end
                end

                nearestId = best
                sig[#sig + 1] = 'n' .. tostring(best)
                local s = table.concat(sig, '|')
                if s ~= lastSig then
                    lastSig = s
                    uiVisible = true
                    nui('update', { items = items, active = best })
                end

                Wait(0)
            end
        end

        hideAll()
        nearestId = nil
        running = false
    end)
end

local function addLog(data)
    if logs[data.id] then return end
    local remaining = (data.duration - data.age) * 1000
    if remaining <= 0 then return end

    data.coords = vec3(data.coords.x, data.coords.y, data.coords.z)
    data.expiresAt = GetGameTimer() + remaining
    logs[data.id] = data
    count += 1

    nui('add', {
        id = data.id,
        name = data.name,
        serverId = data.serverId,
        discord = data.discord,
        reason = data.reason,
        age = data.age,
        duration = data.duration,
    })
    loop()
end

RegisterNetEvent('4play-combatlog:add', function(data)
    if Config.Debug then
        print(('[4play-combatlog] diterima log #%s dari %s, jarak %.1f m'):format(
            data.id, data.name, #(GetEntityCoords(PlayerPedId()) - vec3(data.coords.x, data.coords.y, data.coords.z))))
    end
    addLog(data)
end)

local function syncActive()
    local list = lib.callback.await('4play-combatlog:getActive', false)
    for _, data in ipairs(list or {}) do addLog(data) end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', syncActive)

-- NUI meminta config sekali saat halaman selesai dimuat
RegisterNUICallback('ready', function(_, cb)
    cb({ locale = Config.Locale, tag = Config.ServerTag, key = Config.CopyKey, drawDistance = Config.DrawDistance, scale = Config.UIScale })
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    if LocalPlayer.state.isLoggedIn then syncActive() end
end)

-- Keybind: tidak ada pengecekan per-frame, hanya terpanggil saat tombol ditekan
lib.addKeybind({
    name = '4play_combatlog_copy',
    description = 'Salin Discord ID combat log terdekat',
    defaultKey = Config.CopyKey,
    onPressed = function()
        if not nearestId then return end
        local log = logs[nearestId]
        if not log then return end

        local id = log.id
        CreateThread(function()
            local text = lib.callback.await('4play-combatlog:getCopyText', false, id)
            if not text then
                lib.notify({ description = Config.Locale.notifyGone, type = 'error' })
                return
            end
            lib.setClipboard(text)
            nui('copied', id)
            lib.notify({ description = Config.Locale.notifyCopy, type = 'success' })
        end)
    end,
})
