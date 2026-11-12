-- Carry (pikul bahu) & Gendong (punggung): server memegang pasangan pembawa <-> yang dibawa.
-- Validasi: jarak, bucket, borgol/pingsan/sandera/bagasi, kendaraan, spam & jeda angkat ulang.

local MODES = { bahu = true, punggung = true }
local MAX_DIST = 3.0         -- jarak maksimal saat mulai
local BREAK_DIST = 6.0       -- lepas otomatis kalau terpisah sejauh ini
local PICKUP_COOLDOWN = 5000 -- ms: yang baru turun tidak bisa langsung diangkat lagi (anti troll)

local active = {}  -- [src] = { other = id, role = 'carrier'|'carried' }
local spam = {}    -- [src] = waktu boleh request lagi
local dropped = {} -- [src] = waktu boleh diangkat lagi

local function notify(src, msg, kind)
    exports.qbx_core:Notify(src, msg, kind or 'error')
end

local function online(id)
    return GetPlayerName(id) ~= nil
end

---@return boolean free, integer? ped
local function isFree(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    local md = player.PlayerData.metadata
    if md.ishandcuffed or md.isdead or md.inlaststand then return false end
    local st = Player(src).state
    if active[src] or st.carry or st.cuffed or st.isDead or st.hostage or st.trunkVictim then return false end
    local ped = GetPlayerPed(src)
    if ped == 0 or GetVehiclePedIsIn(ped, false) ~= 0 then return false end
    return true, ped
end

local function release(src)
    local entry = active[src]
    if not entry then return end
    local other = entry.other
    active[src], active[other] = nil, nil

    local carried = entry.role == 'carried' and src or other
    dropped[carried] = GetGameTimer() + PICKUP_COOLDOWN

    for _, id in ipairs({ src, other }) do
        if online(id) then
            Player(id).state:set('carry', nil, true)
            TriggerClientEvent('f_carry:client:release', id)
        end
    end
end

RegisterNetEvent('f_carry:server:start', function(target, mode)
    local src = source
    target = tonumber(target)
    if not target or target == src or not MODES[mode] or not online(target) then return end

    local now = GetGameTimer()
    if (spam[src] or 0) > now then return end
    spam[src] = now + 1500

    local okSrc, pedSrc = isFree(src)
    if not okSrc then return end
    if (dropped[target] or 0) > now then
        return notify(src, 'Orang itu baru saja turun, tunggu sebentar.')
    end
    local okTarget, pedTarget = isFree(target)
    if not okTarget then return notify(src, 'Orang itu tidak bisa diangkat sekarang.') end
    if GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(target) then return end
    if #(GetEntityCoords(pedSrc) - GetEntityCoords(pedTarget)) > MAX_DIST then return end

    active[src] = { other = target, role = 'carrier' }
    active[target] = { other = src, role = 'carried' }
    Player(src).state:set('carry', 'carrier', true)
    Player(target).state:set('carry', 'carried', true)

    TriggerClientEvent('f_carry:client:start', src, 'carrier', target, mode)
    TriggerClientEvent('f_carry:client:start', target, 'carried', src, mode)
end)

RegisterNetEvent('f_carry:server:stop', function()
    release(source)
end)

AddEventHandler('playerDropped', function()
    local src = source
    release(src)
    spam[src], dropped[src] = nil, nil
end)

-- pengawas: pasangan yang terpisah jauh (teleport, desync) dilepas
CreateThread(function()
    while true do
        Wait(2000)
        for src, entry in pairs(active) do
            if entry.role == 'carrier' then
                local a, b = GetPlayerPed(src), GetPlayerPed(entry.other)
                if a == 0 or b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > BREAK_DIST then
                    release(src)
                end
            end
        end
    end
end)

-- statebag tersisa dari sebelum restart resource
for _, id in ipairs(GetPlayers()) do
    Player(id).state:set('carry', nil, true)
end
