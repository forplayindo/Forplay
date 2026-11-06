---------------------------------------------------------------------------
-- Laporan warga (/lapor, /report). Disimpan di memori saja (hilang saat restart).
-- Warga melihat staff sebagai "Staff"; staff melihat nama asli.
---------------------------------------------------------------------------
local RC = Config.Report
local Reports = {}      -- [id] = report
local nextId = 1
local lastSent = {}     -- [license] = os.time()

local function license(src) return GetPlayerIdentifierByType(src, 'license2') or GetPlayerIdentifierByType(src, 'license') or ('src:' .. src) end
local function now() return os.date('%H:%M') end

-- report milik pemain yang sedang online dengan license ini
local function ownerSrc(r)
    if r.src and GetPlayerName(r.src) and license(r.src) == r.lic then return r.src end
    for _, s in ipairs(GetPlayers()) do
        if license(s) == r.lic then r.src = tonumber(s) return r.src end
    end
end

local function staffList()
    local out = {}
    for _, s in ipairs(GetPlayers()) do
        local id = tonumber(s)
        if Can(id, 'reports.manage') then out[#out + 1] = id end
    end
    return out
end

function OpenReportCount()
    local n = 0
    for _, r in pairs(Reports) do if r.status ~= 'done' then n += 1 end end
    return n
end

local function pushStaff()
    local n = OpenReportCount()
    for _, id in ipairs(staffList()) do TriggerClientEvent('f_admin:client:reports', id, n) end
end

local function pushOwner(r)
    local s = ownerSrc(r)
    if s then TriggerClientEvent('f_admin:client:lapor', s) end
end

local function notifyStaff(title, text, kind, only)
    for _, id in ipairs(only and { only } or staffList()) do
        Notify(id, text, kind or 'warning', title, RC.notifyMs)
    end
end

---------------------------------------------------------------- warga
local function activeCount(lic)
    local n = 0
    for _, r in pairs(Reports) do if r.lic == lic and r.status ~= 'done' then n += 1 end end
    return n
end

local function mineFor(src)
    local lic, out = license(src), {}
    for _, r in pairs(Reports) do
        if r.lic == lic then
            local msgs = {}
            for i, m in ipairs(r.msgs) do msgs[i] = { me = m.w, who = m.w and 'Kamu' or 'Staff', t = m.t, at = m.at } end
            out[#out + 1] = { id = r.id, cat = r.cat, status = r.status, unread = r.unreadW, msgs = msgs }
        end
    end
    table.sort(out, function(a, b) return a.id > b.id end)
    return out
end

---@return boolean ok, string msg
function SendReport(src, text, cat, target)
    text = tostring(text or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return false, 'Isi laporan dulu.' end
    text = text:sub(1, RC.maxLength)
    local lic = license(src)
    local wait = (lastSent[lic] or 0) + RC.cooldown - os.time()
    if wait > 0 then return false, ('Tunggu %d detik sebelum mengirim laporan lagi.'):format(wait) end
    if activeCount(lic) >= RC.maxActive then return false, ('Kamu masih punya %d laporan yang belum selesai.'):format(RC.maxActive) end
    if not lib.table.contains(RC.categories, cat) then cat = RC.categories[#RC.categories] end
    target = tonumber(target)
    if target and not GetPlayerName(target) then target = nil end

    local r = {
        id = nextId, src = src, lic = lic, name = CharName(src), ooc = GetPlayerName(src),
        cat = cat, target = target, status = 'wait', created = os.time(),
        msgs = { { w = true, t = text, at = now() } }, unreadS = 1, unreadW = 0,
    }
    Reports[r.id] = r
    nextId += 1
    lastSent[lic] = os.time()

    Notify(src, 'Staff akan segera membalas. Cek di /lapor → Laporan Saya.', 'success', ('Laporan #%d terkirim'):format(r.id), RC.notifyMs)
    notifyStaff(('Laporan baru #%d'):format(r.id), ('%s (ID %d) · %s: "%s"'):format(r.name, src, cat, text:sub(1, 90)), 'warning')
    pushStaff()
    return true, ('Laporan #%d terkirim'):format(r.id)
end

lib.callback.register('f_admin:lapor_mine', function(src)
    return { ok = true, mine = mineFor(src), staff = #staffList(), cats = RC.categories, max = RC.maxLength }
end)

lib.callback.register('f_admin:lapor_send', function(src, d)
    d = type(d) == 'table' and d or {}
    local ok, msg = SendReport(src, d.text, d.cat, d.target)
    return { ok = ok, msg = msg, mine = mineFor(src) }
end)

lib.callback.register('f_admin:lapor_read', function(src, d)
    local r = Reports[tonumber(type(d) == 'table' and d.id) or 0]
    if r and r.lic == license(src) then r.unreadW = 0 end
    return { ok = true }
end)

lib.callback.register('f_admin:lapor_reply', function(src, d)
    d = type(d) == 'table' and d or {}
    local r = Reports[tonumber(d.id) or 0]
    if not r or r.lic ~= license(src) then return { ok = false, msg = 'Laporan tidak ditemukan.' } end
    if r.status == 'done' then return { ok = false, msg = 'Laporan sudah selesai.' } end
    local text = tostring(d.text or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, RC.maxLength)
    if text == '' then return { ok = false } end
    r.msgs[#r.msgs + 1] = { w = true, t = text, at = now() }
    r.unreadS += 1
    local staff = r.claimedSrc and GetPlayerName(r.claimedSrc) and r.claimedSrc or nil
    notifyStaff(('Balasan warga #%d'):format(r.id), ('%s: "%s"'):format(r.name, text:sub(1, 90)), 'inform', staff)
    pushStaff()
    return { ok = true, mine = mineFor(src) }
end)

---------------------------------------------------------------- staff
local function staffView(r, full)
    local last = r.msgs[#r.msgs]
    local v = {
        id = r.id, from = r.name, ooc = r.ooc, pid = ownerSrc(r), cat = r.cat, target = r.target,
        status = r.status, claimed = r.claimed, unread = r.unreadS, ago = math.floor((os.time() - r.created) / 60),
        last = { w = last.w, who = last.who, t = last.t },
    }
    if full then v.msgs = r.msgs end
    return v
end

Handle('reports', 'reports.manage', function()
    local list = {}
    for _, r in pairs(Reports) do if r.status ~= 'done' then list[#list + 1] = staffView(r) end end
    table.sort(list, function(a, b) return a.id > b.id end)
    return { ok = true, reports = list }
end)

Handle('report_open', 'reports.manage', function(src, d)
    local r = Reports[tonumber(d.id) or 0]
    if not r then return { ok = false, msg = 'Laporan sudah tidak ada.' } end
    r.unreadS = 0
    return { ok = true, report = staffView(r, true) }
end)

local function claim(src, r)
    if r.claimed then return end
    r.claimed, r.claimedSrc, r.status = GetPlayerName(src), src, 'claimed'
end

Handle('report_claim', 'reports.manage', function(src, d)
    local r = Reports[tonumber(d.id) or 0]
    if not r or r.status == 'done' then return { ok = false, msg = 'Laporan sudah tidak ada.' } end
    claim(src, r)
    for _, id in ipairs(staffList()) do
        if id ~= src then Notify(id, ('Laporan #%d ditangani %s'):format(r.id, r.claimed), 'inform') end
    end
    pushStaff()
    pushOwner(r)
    return { ok = true, report = staffView(r, true) }
end)

Handle('report_reply', 'reports.manage', function(src, d)
    local r = Reports[tonumber(d.id) or 0]
    if not r or r.status == 'done' then return { ok = false, msg = 'Laporan sudah tidak ada.' } end
    local text = tostring(d.text or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, RC.maxLength)
    if text == '' then return { ok = false, msg = 'Balasan kosong.' } end
    claim(src, r)
    r.msgs[#r.msgs + 1] = { w = false, who = ('%s · %s'):format(GetPlayerName(src), RoleLabel[GetRole(src)] or 'Staff'), t = text, at = now() }
    r.unreadW += 1
    local owner = ownerSrc(r)
    if owner then
        Notify(owner, ('Staff: "%s"'):format(text:sub(1, 120)), 'inform', ('Balasan laporan #%d'):format(r.id), RC.notifyMs)
    end
    pushOwner(r)
    pushStaff()
    return { ok = true, report = staffView(r, true) }
end)

Handle('report_close', 'reports.manage', function(src, d)
    local r = Reports[tonumber(d.id) or 0]
    if not r or r.status == 'done' then return { ok = false, msg = 'Laporan sudah tidak ada.' } end
    r.status = 'done'
    if not r.claimed then r.claimed = GetPlayerName(src) end
    local owner = ownerSrc(r)
    if owner then
        Notify(owner, 'Ditutup oleh staff. Terima kasih sudah melapor.', 'success', ('Laporan #%d selesai'):format(r.id), RC.notifyMs)
    end
    Log(src, 'report', ('menutup laporan #%d dari **%s** (%s)'):format(r.id, r.name, r.cat))
    pushOwner(r)
    pushStaff()
    return { ok = true, msg = ('Laporan #%d selesai'):format(r.id) }
end)

-- laporan selesai disimpan 2 jam untuk riwayat warga, lalu dihapus
CreateThread(function()
    while true do
        Wait(600000)
        local cut = os.time() - 7200
        for id, r in pairs(Reports) do
            if r.status == 'done' and r.created < cut then Reports[id] = nil end
        end
    end
end)
