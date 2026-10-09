-- Masa pemulihan kaki (server). Dimulai saat Splint dipasang di kaki / telapak / tulang belakang
-- (dan nanti setelah operasi kaki). Sisa waktu disimpan di metadata `recovery` (detik waktu
-- bermain, hanya berkurang saat online) dan dikirim ke client lewat state bag supaya efek pincang /
-- wajib Crutch berjalan. Selama pemulihan pemain wajib memakai Crutch.

local cfg = require 'config.treatment'
local rec = cfg.recovery

local STATE = 'f_ambulancejob:recovery'

Recovery = {}

local function setState(src, left)
    Player(src).state:set(STATE, left and left > 0 and left or nil, true)
end

---@param src number
---@return integer? detik tersisa
function Recovery.Get(src)
    local player = exports.qbx_core:GetPlayer(src)
    local data = player and player.PlayerData.metadata.recovery
    return type(data) == 'table' and tonumber(data.left) or nil
end

---Mulai / perpanjang masa pemulihan (yang lebih lama yang dipakai).
---@param src number
---@param part string area tubuh
function Recovery.Start(src, part)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local left = math.max(Recovery.Get(src) or 0, rec.duration)
    player.Functions.SetMetaData('recovery', { left = left, part = part })
    setState(src, left)
    TriggerClientEvent('f_ambulancejob:client:recoveryStarted', src, left)
end

---@param src number
---@param silent? boolean
function Recovery.Clear(src, silent)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    player.Functions.SetMetaData('recovery', nil)
    setState(src, nil)
    if not silent then TriggerClientEvent('f_ambulancejob:client:recoveryEnded', src) end
end

exports('StartRecovery', Recovery.Start)
exports('GetRecovery', Recovery.Get)

-- pengurangan waktu untuk player online
CreateThread(function()
    while true do
        Wait(rec.tick * 1000)
        for src, player in pairs(exports.qbx_core:GetQBPlayers()) do
            local data = player.PlayerData.metadata.recovery
            if type(data) == 'table' and tonumber(data.left) then
                local left = data.left - rec.tick
                if left <= 0 then
                    Recovery.Clear(src)
                else
                    player.Functions.SetMetaData('recovery', { left = left, part = data.part })
                    setState(src, left)
                end
            end
        end
    end
end)

-- pulihkan state bag saat login / resource restart
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    setState(src, Recovery.Get(src))
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(exports.qbx_core:GetQBPlayers()) do
        setState(src, Recovery.Get(src))
    end
end)

lib.addCommand('clearrecovery', {
    help = 'Akhiri masa pemulihan kaki pemain',
    restricted = 'group.admin',
    params = { { name = 'id', help = 'ID pemain', type = 'playerId', optional = true } },
}, function(source, args)
    local target = args.id or source
    if not exports.qbx_core:GetPlayer(target) then
        return exports.qbx_core:Notify(source, 'Pemain tidak online', 'error')
    end
    Recovery.Clear(target)
    exports.qbx_core:Notify(source, 'Masa pemulihan diakhiri', 'success')
end)

-- Setel posisi Crutch di tangan secara live (admin), lalu salin angkanya ke config/treatment.lua.
lib.addCommand('crutchpos', {
    help = 'Setel posisi prop Crutch: x y z rx ry rz',
    restricted = 'group.admin',
    params = {
        { name = 'x', type = 'number' }, { name = 'y', type = 'number' }, { name = 'z', type = 'number' },
        { name = 'rx', type = 'number', optional = true }, { name = 'ry', type = 'number', optional = true },
        { name = 'rz', type = 'number', optional = true },
    },
}, function(source, args)
    TriggerClientEvent('f_ambulancejob:client:crutchPos', source,
        vec3(args.x, args.y, args.z), vec3(args.rx or 0.0, args.ry or 0.0, args.rz or 0.0))
end)
