-- f_crew client: daftarkan app Crew ke f_phone dan teruskan panggilan UI ke server.
-- Tidak ada loop; semua berbasis event.

local APP_ID = 'crew'
local RES = GetCurrentResourceName()
local PHONE = 'f_phone'

local function phoneUp()
    return GetResourceState(PHONE) == 'started'
end

local function registerApp()
    if not phoneUp() then return end
    local okAdd, err = exports['f_phone']:addCustomApp({
        identifier = APP_ID,
        name = 'Crew',
        description = 'Buat atau gabung gang dan komunitas di kota.',
        developer = 'Kota',
        icon = ('https://cfx-nui-%s/web/icon.svg'):format(RES),
        ui = ('%s/web/index.html'):format(RES),
        defaultApp = true,
    })
    if not okAdd then lib.print.warn(('f_crew: gagal daftar app: %s'):format(err)) end
end

AddEventHandler('onClientResourceStart', function(res)
    if res == RES or res == PHONE then registerApp() end
end)

---Satu pintu untuk semua aksi UI: { action = string, payload = table }.
RegisterNUICallback('call', function(data, cb)
    local name = type(data) == 'table' and data.action or nil
    local res = lib.callback.await('f_crew:server:call', false, name, type(data) == 'table' and data.payload or nil)
    if name == 'gps' and type(res) == 'table' and res.ok and res.data then
        local x, y = res.data.x + 0.0, res.data.y + 0.0
        local pos = GetEntityCoords(cache.ped)
        -- GTA langsung menghapus waypoint yang dipasang di posisi pemain sendiri
        if #(vec2(pos.x, pos.y) - vec2(x, y)) < 40.0 then
            res = { ok = false, err = 'Kamu sudah berada di lokasi garasi.' }
        else
            SetNewWaypoint(x, y)
        end
    end
    cb(res or { ok = false, err = 'Server tidak merespons.' })
end)

---Hasil aksi di app (berhasil/gagal) -> notifikasi HP milik sendiri, lewat server.
RegisterNUICallback('notify', function(data, cb)
    cb(true)
    local msg = type(data) == 'table' and data.msg
    if type(msg) == 'string' and msg ~= '' then
        TriggerServerEvent('f_crew:server:selfNotify', msg)
    end
end)

---Server minta app menyegarkan data (anggota baru, lamaran, kas, dll).
RegisterNetEvent('f_crew:client:refresh', function()
    if not phoneUp() then return end
    exports['f_phone']:sendCustomAppMessage(APP_ID, { action = 'crew:refresh' })
end)
