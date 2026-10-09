-- Sisa hukuman dihitung di server (JailSentence, lihat bridge/server/qbx.lua). Dulu client yang
-- mengurangi waktunya sendiri, jadi pemain dengan cheat bisa langsung bebas.
-- Satu interval 30 detik untuk semua tahanan online: sangat ringan.

local config = lib.load('configs.server')
local db     = require 'server.modules.db'

local PERIOD = math.max(1, math.floor((config.MinutesPerMonth or 10) * 60)) -- detik per "bulan"
local LIFER  = 999

---@type table<integer, integer> source -> os.time() saat bulan berikutnya selesai
local nextTick = {}

local function save(src, time)
    local cid = getCharID(src)
    if cid then MySQL.insert(db.UPDATE_JAILTIME, { cid, time }) end
end

SetInterval(function()
    local now = os.time()
    for src, time in pairs(JailSentence) do
        if time < LIFER then
            local due = nextTick[src]
            if not due then
                nextTick[src] = now + PERIOD
            elseif now >= due then
                local left = time - 1
                setJailTime(src, left)
                save(src, left)
                nextTick[src] = left > 0 and now + PERIOD or nil
                if left <= 0 then
                    lib.notify(src, { title = locale('notify.checkout'), icon = 'fas fa-unlock', type = 'success' })
                end
            end
        end
    end
    for src in pairs(nextTick) do
        if not JailSentence[src] then nextTick[src] = nil end
    end
end, 30000)

---Penjara dari server (MDT booking). Kalau sudah di penjara, hukumannya ditambah.
---@param src integer
---@param months integer
---@return boolean
local function jailPlayer(src, months)
    src = tonumber(src)
    months = math.floor(tonumber(months) or 0)
    if not src or months < 1 or not getPlayer(src) then return false end

    local current = JailSentence[src]
    if current then
        if current < LIFER then
            setJailTime(src, current + months)
            save(src, current + months)
        end
        return true
    end

    setJailTime(src, months)
    save(src, months)
    nextTick[src] = os.time() + PERIOD
    CreateThread(function()
        lib.callback.await('xt-prison:client:enterJail', src, months)
    end)
    return true
end
exports('JailPlayer', jailPlayer)

AddEventHandler('playerDropped', function()
    nextTick[source] = nil
end)
