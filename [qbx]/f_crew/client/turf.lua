-- f_crew client: blip wilayah gang di map + status perebutan di bawah tengah layar.
-- Blip dibuat saat server mengirim data (hanya ke anggota gang bertag 'gang') dan diperbarui per
-- zona saat ada perubahan. Semua waktu dihitung server dan dikirim ulang tiap tick; client hanya
-- menampilkan. Loop 1 detik hanya berjalan untuk anggota gang tersebut.
--
-- Layar: pilihan [J] Rebut / [X] Abaikan (setelah 1 menit di zona gang lain / bebas) ->
-- hitung mundur persiapan -> hitung mundur perebutan -> nama pemenang (5 detik).

local zoneList = require 'shared.zones'

local UNOWNED_COLOR = 0
local WAR_COLOR = 1
local DEATH_BAG = 'f_medical:deathState'
local RESULT_MS = 5000

---@type table<string, { areas: integer[], label: integer?, name: string }>
local Blips = {}
---@type table<string, { o: string?, c: integer?, w: boolean }>
local ZoneState = {}
local cfg
---@type { zone: string, own: boolean, prompt: boolean, join: boolean, prepAt: integer?, warAt: integer? }?
local presence
---@type { text: string, kind: string?, untilAt: integer }?
local result
local declined = {}  -- zona yang dipilih "Abaikan"; direset saat keluar zona
local promptZone     -- zona yang pilihannya sedang tampil
local lastZone
local looping = false
local shownText

-- Kotak zona yang sudah dirapikan, untuk tahu zona tempat pemain berada.
local ZoneBoxes = {}
for i = 1, #zoneList do
    local def = zoneList[i]
    local boxes = {}
    for j = 1, #def.boxes do
        local b = def.boxes[j]
        boxes[j] = { math.min(b[1], b[3]), math.min(b[2], b[4]), math.max(b[1], b[3]), math.max(b[2], b[4]) }
    end
    ZoneBoxes[i] = { id = def.id, label = def.label, boxes = boxes }
end

local function zoneAt(x, y)
    for i = 1, #ZoneBoxes do
        local z = ZoneBoxes[i]
        for j = 1, #z.boxes do
            local r = z.boxes[j]
            if x >= r[1] and x <= r[3] and y >= r[2] and y <= r[4] then return z end
        end
    end
end

-- Text UI ox_lib dipakai bersama script lain (prompt garasi dll): jangan menimpa / menutup milik mereka.
local ICONS = {
    war = { 'crosshairs', '#e5484d' },
    prep = { 'hourglass-half', '#e0a100' },
    prompt = { 'flag', nil },
    done = { 'trophy', '#e0a100' },
    error = { 'circle-exclamation', '#e5484d' },
}

local function showMine(text, kind)
    local open, current = lib.isTextUIOpen()
    if open and current ~= shownText then return end
    local ic = ICONS[kind] or ICONS.prompt
    lib.showTextUI(text, { position = 'bottom-center', icon = ic[1], iconColor = ic[2] })
    shownText = text
end

local function hideMine()
    if not shownText then return end
    local open, current = lib.isTextUIOpen()
    if open and current == shownText then lib.hideTextUI() end
    shownText = nil
end

local function mmss(ms)
    local s = math.max(0, math.ceil(ms / 1000))
    return ('%02d:%02d'):format(s // 60, s % 60)
end

local function hudLoop()
    if looping then return end
    looping = true
    CreateThread(function()
        while cfg do
            local now = GetGameTimer()
            local state = LocalPlayer.state[DEATH_BAG]
            local z
            if state == nil or state == 1 then
                local pos = GetEntityCoords(cache.ped)
                z = zoneAt(pos.x, pos.y)
            end
            -- keluar / pindah zona: pilihan "Abaikan" hanya berlaku sampai keluar zona itu
            local zid = z and z.id
            if zid ~= lastZone then
                if lastZone then declined[lastZone] = nil end
                lastZone = zid
            end
            promptZone = nil

            if result and now < result.untilAt then
                showMine(result.text, result.kind)
            elseif not z then
                result = nil
                hideMine()
            else
                result = nil
                local st = ZoneState[z.id] or {}
                local p = presence
                if p and p.zone ~= z.id then p = nil end
                -- perebutan / persiapan hanya dikirim server ke gang peserta
                if p and p.warAt then
                    showMine(('PEREBUTAN WILAYAH %s - %s'):format(z.label, mmss(p.warAt - now)), 'war')
                elseif p and p.prepAt then
                    local ms = p.prepAt - now
                    showMine(('Persiapan rebut %s - %s  \nPoin tidak dihitung sebelum waktu persiapan habis'):format(
                        z.label, ms > 0 and mmss(ms) or 'memulai...'), 'prep')
                elseif p and p.prompt and not p.own and not declined[z.id] then
                    promptZone = z.id
                    if p.join then
                        showMine(('%s sedang disiapkan untuk direbut  \n[J] Ikut rebut   [X] Abaikan'):format(z.label), 'prompt')
                    else
                        showMine(('%s (%s)  \n[J] Rebut wilayah   [X] Abaikan'):format(z.label, st.o or 'Bebas'), 'prompt')
                    end
                else
                    hideMine()
                end
            end
            Wait(1000)
        end
        hideMine()
        looping = false
    end)
end

local function removeAll()
    for _, b in pairs(Blips) do
        for i = 1, #b.areas do
            if DoesBlipExist(b.areas[i]) then RemoveBlip(b.areas[i]) end
        end
        if b.label and DoesBlipExist(b.label) then RemoveBlip(b.label) end
    end
    Blips = {}
end

local function build()
    for i = 1, #ZoneBoxes do
        local def = ZoneBoxes[i]
        local areas = {}
        local bestArea, cx, cy = -1, 0.0, 0.0
        for j = 1, #def.boxes do
            local r = def.boxes[j]
            local w, h = r[3] - r[1], r[4] - r[2]
            local x, y = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
            local blip = AddBlipForArea(x, y, 0.0, w, h)
            SetBlipRotation(blip, 0)
            -- display diatur di apply(): zona bebas hanya di peta besar, yang dikuasai / perang juga di minimap
            -- short range: kalau tidak, GTA menempelkan setiap kotak di luar layar sebagai titik di tepi minimap
            SetBlipAsShortRange(blip, true)
            areas[#areas + 1] = blip
            -- ikon nama diletakkan di tengah kotak terbesar
            if w * h > bestArea then bestArea, cx, cy = w * h, x, y end
        end
        local label
        if cfg.labels then
            label = AddBlipForCoord(cx, cy, 0.0)
            SetBlipSprite(label, cfg.sprite)
            SetBlipScale(label, cfg.scale)
            SetBlipAsShortRange(label, true)
        end
        Blips[def.id] = { areas = areas, label = label, name = def.label }
    end
end

local function apply(id, data)
    local b = Blips[id]
    if not b or type(data) ~= 'table' then return end
    ZoneState[id] = { o = data.o, c = data.c, w = data.w == true }
    local color = data.w and WAR_COLOR or data.c or UNOWNED_COLOR
    local marked = data.w or data.o ~= nil
    local alpha = marked and cfg.alpha or math.floor(cfg.alpha / 2)
    for i = 1, #b.areas do
        local blip = b.areas[i]
        -- warna kotak hanya di peta pause menu (3). Di minimap HUD lapisan warna area tidak pas dengan
        -- bingkai minimap kotak, jadi di sana cukup ikon zona (lihat label di bawah).
        SetBlipDisplay(blip, 3)
        SetBlipColour(blip, color)
        SetBlipAlpha(blip, alpha)
        SetBlipFlashes(blip, data.w == true)
        if data.w then SetBlipFlashInterval(blip, 500) end
    end
    if b.label then
        -- ikon zona dikuasai / diperebutkan juga di minimap (2), zona bebas hanya di peta besar (3)
        SetBlipDisplay(b.label, marked and 2 or 3)
        SetBlipColour(b.label, color)
        SetBlipFlashes(b.label, data.w == true)
        local key = 'FCREW_TURF_' .. id
        local text = b.name .. ' - ' .. (data.w and 'PEREBUTAN' or data.o or 'Bebas')
        AddTextEntry(key, text)
        BeginTextCommandSetBlipName(key)
        EndTextCommandSetBlipName(b.label)
    end
end

---Data lengkap (atau nil = hapus semua, mis. keluar gang).
RegisterNetEvent('f_crew:turf:all', function(payload)
    if type(payload) ~= 'table' then
        cfg, presence = nil, nil
        ZoneState = {}
        removeAll()
        hideMine()
        return
    end
    local rebuild = not cfg or cfg.labels ~= payload.labels or next(Blips) == nil
    cfg = { alpha = payload.alpha or 90, labels = payload.labels == true, sprite = payload.sprite or 84, scale = payload.scale or 0.6 }
    if rebuild then
        removeAll()
        build()
    end
    for id, data in pairs(payload.zones or {}) do apply(id, data) end
    hudLoop()
end)

RegisterNetEvent('f_crew:turf:zone', function(id, data)
    if cfg then apply(id, data) end
end)

---Dari server tiap tick saat berada di zona (nil = keluar zona).
---info: own = zona milik gang sendiri, prompt = boleh tampil pilihan Rebut, prep / war = sisa detik.
RegisterNetEvent('f_crew:turf:presence', function(id, info)
    if type(id) ~= 'string' or type(info) ~= 'table' then
        presence = nil
        return
    end
    local now = GetGameTimer()
    presence = {
        zone = id,
        own = info.own == true,
        prompt = info.prompt == true,
        join = info.join == true,
        prepAt = info.prep and now + info.prep * 1000 or nil,
        warAt = info.war and now + info.war * 1000 or nil,
    }
end)

---Teks sementara dari server (pemenang / alasan gagal), tampil 5 detik.
RegisterNetEvent('f_crew:turf:result', function(text, kind)
    if type(text) ~= 'string' then return end
    result = { text = text, kind = kind, untilAt = GetGameTimer() + RESULT_MS }
    if presence then
        -- status lama tidak berlaku lagi; tick server berikutnya mengirim yang baru
        presence.warAt, presence.prepAt, presence.prompt = nil, nil, false
    end
    if kind == 'error' and lastZone then declined[lastZone] = true end
end)

-- Pilihan di layar. Tombol bisa diganti pemain di Settings > Key Bindings > FiveM.
lib.addKeybind({
    name = 'fcrew_turf_yes',
    description = 'Wilayah gang: rebut zona',
    defaultKey = 'J', -- Y sudah dipakai cruise control
    onPressed = function()
        if not promptZone then return end
        TriggerServerEvent('f_crew:turf:approve', promptZone)
        declined[promptZone] = true -- jangan tampil lagi selagi menunggu balasan server
        promptZone = nil
        if presence then presence.prompt = false end
    end,
})

lib.addKeybind({
    name = 'fcrew_turf_no',
    description = 'Wilayah gang: abaikan zona',
    defaultKey = 'X',
    onPressed = function()
        if not promptZone then return end
        declined[promptZone] = true
        promptZone = nil
        hideMine()
    end,
})

-- Blip tidak otomatis hilang saat resource berhenti: tanpa ini setiap restart f_crew meninggalkan
-- satu set blip lama (warna lama) di map.
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeAll()
    hideMine()
end)

-- Setelah resource (re)start, data dari server bisa terkirim sebelum script ini siap: minta ulang.
CreateThread(function()
    Wait(5000)
    TriggerServerEvent('f_crew:turf:request')
end)
