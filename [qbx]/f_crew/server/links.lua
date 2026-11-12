-- Jembatan ke resource lain: qbx_core (gang), f_banking (kas), f_garages (garasi),
-- pma-voice/mm_radio (channel), f_phone (notifikasi & nomor HP). Semua dipanggil hanya saat ada
-- aksi; tidak ada loop. Resource yang belum/tidak jalan dilewati tanpa error.
local config = require 'config'

local links = {}

---@param res string
---@return boolean
local function started(res)
    return GetResourceState(res) == 'started'
end
links.started = started

-- qbx_core -----------------------------------------------------------------------------------

---Definisi gang untuk qbx_core dari data cache.
---@param g table
---@return table
function links.gangDef(g)
    local grades = {}
    for i = 0, 3 do
        local base = config.Grades[i]
        grades[i] = {
            name = g.grades[i + 1] or base.name,
            isboss = base.isboss or nil,
            bankAuth = base.bankAuth or nil,
        }
    end
    return { label = g.label, grades = grades }
end

---Mendaftarkan (atau memperbarui) banyak gang sekaligus di qbx_core.
---@param list table[]
function links.registerGangs(list)
    local defs, any = {}, false
    for i = 1, #list do
        defs[list[i].name] = links.gangDef(list[i])
        any = true
    end
    if any then exports.qbx_core:CreateGangs(defs) end
end

-- f_banking ----------------------------------------------------------------------------

---@param g table
function links.ensureAccount(g)
    if not started('f_banking') then return end
    local ok, err = pcall(function()
        exports['f_banking']:CreateJobAccount({ name = g.name, label = g.label })
    end)
    if not ok then lib.print.warn(('f_crew: gagal membuat rekening %s: %s'):format(g.name, err)) end
end

---@param name string
---@return integer? balance nil saat banking tidak tersedia
function links.balance(name)
    if not started('f_banking') then return nil end
    local ok, value = pcall(function() return exports['f_banking']:getAccountMoney(name) end)
    if ok and type(value) == 'number' then return math.floor(value) end
    return nil
end

---@return boolean
function links.addAccount(name, amount)
    if not started('f_banking') then return false end
    local ok, res = pcall(function() return exports['f_banking']:addAccountMoney(name, amount) end)
    return ok and res == true
end

---@return boolean
function links.removeAccount(name, amount)
    if not started('f_banking') then return false end
    local ok, res = pcall(function() return exports['f_banking']:removeAccountMoney(name, amount) end)
    return ok and res == true
end

---Catat juga di riwayat rekening f_banking (supaya terlihat di aplikasi bank).
function links.bankHistory(name, title, amount, message, issuer, receiver, kind)
    if not started('f_banking') then return end
    pcall(function()
        exports['f_banking']:handleTransaction(name, title, amount, message, issuer, receiver, kind)
    end)
end

-- f_garages ----------------------------------------------------------------------------------

---Daftarkan garasi gang (pribadi per anggota). Tanpa lokasi = garasi dimatikan (tanpa titik akses).
---@param g table
---@param force? boolean daftar ulang walau tanpa lokasi (untuk mematikan garasi lama)
function links.syncGarage(g, force)
    if not started('f_garages') then return end
    if not g.garage and not force then return end
    local points = {}
    if g.garage then
        local c = g.garage
        local spot = vec4(c.x, c.y, c.z, c.h)
        points[1] = { coords = spot, spawns = { spot } }
    end
    local ok, err = pcall(function()
        exports.f_garages:RegisterGarage(g.name, {
            label = ('Garasi %s'):format(g.label),
            vehicleType = 'car',
            groups = g.name,
            shared = false,
            accessPoints = points,
        })
    end)
    if not ok then lib.print.warn(('f_crew: gagal daftar garasi %s: %s'):format(g.name, err)) end
end

---Kendaraan di garasi gang dipindah ke impound (yang sedang di luar hanya dipindah garasinya).
---@param gangName string
function links.impoundGarage(gangName)
    MySQL.update.await('UPDATE player_vehicles SET garage = ?, state = IF(state = 1, 2, state) WHERE garage = ?', {
        config.ImpoundGarage, gangName,
    })
end

-- pma-voice / mm_radio -----------------------------------------------------------------------

---Kunci channel di server: hanya anggota gang yang bisa masuk.
---@param g table
function links.radioLock(g)
    if not g.radio or not started('pma-voice') then return end
    local gangName = g.name
    exports['pma-voice']:addChannelCheck(g.radio, function(src)
        local p = exports.qbx_core:GetPlayer(src)
        return p ~= nil and p.PlayerData.gang ~= nil and p.PlayerData.gang.name == gangName
    end)
end

---@param channel integer
function links.radioUnlock(channel)
    if not started('pma-voice') then return end
    pcall(function() exports['pma-voice']:removeChannelCheck(channel) end)
end

---Beri tahu semua client (mm_radio) ada channel gang baru / dihapus (gang nil).
function links.radioBroadcast(channel, gangName, label)
    TriggerClientEvent('f_crew:client:radioChannel', -1, channel, gangName, label)
end

---Keluarkan pemain dari channel gang kalau sedang di situ.
---@param src integer
---@param channel integer?
function links.radioKick(src, channel)
    if not channel or not started('pma-voice') then return end
    local current = Player(src).state.radioChannel
    if type(current) == 'number' and math.floor(current) == channel then
        exports['pma-voice']:setPlayerRadio(src, 0)
    end
end

-- f_phone -----------------------------------------------------------------------------------

local function phoneUp()
    return started('f_phone')
end

---@param src integer
---@param title string
---@param body string
function links.notify(src, title, body)
    if not phoneUp() then return end
    pcall(function()
        exports['f_phone']:notify(src, { app = 'custom:crew', appId = 'crew', title = title, body = body })
    end)
end

---@param number any
---@return string? citizenid
function links.cidByNumber(number)
    if type(number) ~= 'string' and type(number) ~= 'number' then return nil end
    if not phoneUp() then return nil end
    local ok, cid = pcall(function() return exports['f_phone']:getIdentifierByNumber(tostring(number)) end)
    return ok and type(cid) == 'string' and cid or nil
end

return links
