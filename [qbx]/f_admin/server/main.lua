local ROLE_LABEL = { owner = 'Owner', admin = 'Admin', support = 'Support' }
local ID_TYPES = { 'license', 'license2', 'fivem', 'discord' } -- identifier yang dipakai untuk principal staff
RoleLabel = ROLE_LABEL

function Notify(src, msg, kind, title, ms)
    TriggerClientEvent('ox_lib:notify', src, { title = title, description = msg, type = kind or 'inform', duration = ms })
end

---Nama karakter, atau nama FiveM kalau belum memilih karakter.
function CharName(src)
    local p = exports.qbx_core:GetPlayer(src)
    local ci = p and p.PlayerData.charinfo
    local char = ci and ('%s %s'):format(ci.firstname or '', ci.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return (char and char ~= '') and char or GetPlayerName(src) or ('ID %s'):format(src)
end

---"Budi Santoso (ID 4)" untuk log
function Who(src) return ('%s (ID %s)'):format(CharName(src), src) end

---Daftarkan callback NUI. need: kunci aksi, 'owner', atau false (cukup staff).
function Handle(name, need, fn)
    lib.callback.register('f_admin:' .. name, function(src, d)
        local role = GetRole(src)
        if not role then return { ok = false, msg = 'Kamu bukan staff.' } end
        if need == 'owner' then
            if role ~= 'owner' then return { ok = false, msg = 'Khusus Owner.' } end
        elseif need and not Can(src, need) then
            return { ok = false, msg = 'Tidak punya izin untuk aksi ini.' }
        end
        local ok, res = pcall(fn, src, type(d) == 'table' and d or {})
        if not ok then
            lib.print.error(('f_admin:%s gagal: %s'):format(name, res))
            return { ok = false, msg = 'Terjadi kesalahan di server.' }
        end
        return res or { ok = true }
    end)
end

local function staffIds(src)
    local ids = {}
    for _, t in ipairs(ID_TYPES) do
        local id = GetPlayerIdentifierByType(src, t)
        if id then ids[#ids + 1] = id end
    end
    return ids
end

-- staff yang sedang online: identifier -> server id
local function onlineIndex()
    local map = {}
    for _, src in ipairs(GetPlayers()) do
        for _, id in ipairs(GetPlayerIdentifiers(src)) do map[id] = tonumber(src) end
    end
    return map
end

local function staffOnline()
    local n = 0
    for _, src in ipairs(GetPlayers()) do
        if GetRole(src) then n += 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Buka panel
---------------------------------------------------------------------------
function OpenPanel(src)
    if not GetRole(src) or not Can(src, 'panel.open') then
        return Notify(src, 'Kamu tidak punya akses panel admin.', 'error')
    end
    TriggerClientEvent('f_admin:client:open', src)
end

local function stats()
    return {
        players = #GetPlayers(),
        maxPlayers = GetConvarInt('sv_maxclients', 48),
        staff = staffOnline(),
        reports = OpenReportCount(),
        pets = PendingPetCount and PendingPetCount() or 0,
        uptime = math.floor(GetGameTimer() / 60000),
    }
end

lib.callback.register('f_admin:open', function(src)
    local role = GetRole(src)
    if not role or not Can(src, 'panel.open') then return { ok = false, msg = 'Kamu tidak punya akses panel admin.' } end
    local can = {}
    for _, a in ipairs(Config.Actions) do can[a.key] = Can(src, a.key) end
    return {
        ok = true,
        role = role,
        roleLabel = ROLE_LABEL[role],
        me = { id = src, name = GetPlayerName(src) },
        can = can,
        stats = stats(),
        weapons = (function()
            local k = {}
            for cat in pairs(Config.WeaponList) do k[#k + 1] = cat end
            table.sort(k)
            return k
        end)(),
    }
end)

Handle('home', false, function() return { ok = true, stats = stats() } end)

---------------------------------------------------------------------------
-- Staff (Owner)
---------------------------------------------------------------------------
local function staffPayload()
    local online = onlineIndex()
    local list, isStaffSrc = {}, {}
    for _, s in ipairs(Staff) do
        local sid
        for _, id in ipairs(s.ids) do sid = sid or online[id] end
        if sid then isStaffSrc[sid] = true end
        list[#list + 1] = { uid = s.uid, name = s.name, role = s.role, ids = s.ids, by = s.by, at = s.at, online = sid }
    end
    local players, owners = {}, {}
    for _, src in ipairs(GetPlayers()) do
        local n = tonumber(src)
        local role = GetRole(n)
        if role == 'owner' then
            owners[#owners + 1] = { id = n, name = GetPlayerName(n) }
        elseif not isStaffSrc[n] and not role then
            players[#players + 1] = { id = n, name = CharName(n), ooc = GetPlayerName(n) }
        end
    end
    table.sort(players, function(a, b) return a.id < b.id end)
    return { ok = true, staff = list, players = players, owners = owners }
end

Handle('staff_list', 'owner', function() return staffPayload() end)

Handle('staff_add', 'owner', function(src, d)
    if not Config.Groups[d.role] then return { ok = false, msg = 'Role tidak valid.' } end

    local entry
    local target = tonumber(d.target)
    if target and GetPlayerName(target) then
        entry = { name = GetPlayerName(target), ids = staffIds(target) }
    elseif type(d.identifier) == 'string' then
        local id = d.identifier:gsub('%s', ''):lower()
        local t = id:match('^(%a+%d?):[%w]+$')
        if not t or not lib.table.contains(ID_TYPES, t) then
            return { ok = false, msg = 'Identifier harus license:, license2:, fivem: atau discord:' }
        end
        entry = { name = (type(d.name) == 'string' and d.name ~= '') and d.name:sub(1, 40) or id, ids = { id } }
    end
    if not entry or #entry.ids == 0 then return { ok = false, msg = 'Pilih pemain atau isi identifier.' } end

    for _, s in ipairs(Staff) do
        for _, a in ipairs(s.ids) do
            if lib.table.contains(entry.ids, a) then return { ok = false, msg = ('%s sudah terdaftar sebagai %s.'):format(s.name, ROLE_LABEL[s.role]) } end
        end
    end

    entry.role = d.role
    entry.by = GetPlayerName(src)
    entry.at = os.date('%Y-%m-%d %H:%M')
    AddStaff(entry)
    Log(src, 'staff', ('mengangkat **%s** menjadi %s'):format(entry.name, ROLE_LABEL[entry.role]), target)
    if target then Notify(target, ('Kamu sekarang %s. Buka panel dengan /%s'):format(ROLE_LABEL[entry.role], Config.Command), 'success') end
    local res = staffPayload()
    res.msg = ('%s diangkat menjadi %s.'):format(entry.name, ROLE_LABEL[entry.role])
    return res
end)

Handle('staff_role', 'owner', function(src, d)
    local s = FindStaff(tonumber(d.uid))
    if not s or not Config.Groups[d.role] then return { ok = false, msg = 'Data tidak valid.' } end
    if s.role ~= d.role then
        SetStaffRole(s, d.role)
        Log(src, 'staff', ('mengubah **%s** menjadi %s'):format(s.name, ROLE_LABEL[s.role]))
    end
    local res = staffPayload()
    res.msg = ('%s sekarang %s.'):format(s.name, ROLE_LABEL[s.role])
    return res
end)

Handle('staff_remove', 'owner', function(src, d)
    local s, i = FindStaff(tonumber(d.uid))
    if not s then return { ok = false, msg = 'Staff tidak ditemukan.' } end
    RemoveStaff(s, i)
    Log(src, 'staff', ('mencopot **%s** dari %s'):format(s.name, ROLE_LABEL[s.role]))
    local res = staffPayload()
    res.msg = ('%s dicopot.'):format(s.name)
    return res
end)

---------------------------------------------------------------------------
-- Daftar Command (Owner)
---------------------------------------------------------------------------
local function row(key, name, help, extra)
    local p = PermOf(key)
    local r = { key = key, name = name, help = help or '', a = p.a, s = p.s, money = p.money }
    if extra then for k, v in pairs(extra) do r[k] = v end end
    return r
end

Handle('perms_list', 'owner', function()
    local groups, byRes, public = {}, {}, {}
    local actions = {}
    for _, a in ipairs(Config.Actions) do actions[#actions + 1] = row('act:' .. a.key, a.key, a.label) end
    groups[1] = { name = 'Panel Admin', rows = actions }

    -- hanya command yang benar-benar terdaftar sekarang (resource yang jalan)
    for _, c in ipairs(GetRegisteredCommands()) do
        local res = c.resource
        if res and res ~= '' and res ~= 'internal' and not c.name:find('^[+-]') then
            local name = c.name:lower()
            local info = Scan[name]
            if info and not info.restricted and not IsMoneyCommand(name) then
                public[#public + 1] = { name = name, res = res, help = info.help }
            else
                byRes[res] = byRes[res] or {}
                byRes[res][#byRes[res] + 1] = row('cmd:' .. name, '/' .. name, info and info.help, { unknown = info == nil })
            end
        end
    end

    local resNames = {}
    for r in pairs(byRes) do resNames[#resNames + 1] = r end
    table.sort(resNames)
    for _, r in ipairs(resNames) do
        table.sort(byRes[r], function(a, b) return a.name < b.name end)
        groups[#groups + 1] = { name = r, rows = byRes[r] }
    end
    table.sort(public, function(a, b) return a.name < b.name end)
    return { ok = true, groups = groups, public = public }
end)

Handle('perms_set', 'owner', function(src, d)
    if type(d.key) ~= 'string' or (d.col ~= 'a' and d.col ~= 's') then return { ok = false, msg = 'Data tidak valid.' } end
    local kind, name = d.key:match('^(%a+):([%w_%.:%-]+)$')
    if kind ~= 'cmd' and not (kind == 'act' and ActionByKey[name]) then return { ok = false, msg = 'Kunci tidak dikenal.' } end

    local p = SetPerm(d.key, d.col, d.value == true)
    local label = kind == 'cmd' and ('/' .. name) or name
    Log(src, 'perms', ('mengubah izin %s: Admin %s · Support %s'):format(label, p.a and '✓' or '✗', p.s and '✓' or '✗'))
    return { ok = true, key = d.key, a = p.a, s = p.s, money = p.money }
end)

---------------------------------------------------------------------------
-- Log Discord (Owner)
---------------------------------------------------------------------------
Handle('logs_get', 'owner', function() return { ok = true, channels = LogChannels(), kinds = LogKinds() } end)

Handle('logs_set', 'owner', function(src, d)
    if not SetLogKind(d.key, d.on) then return { ok = false, msg = 'Jenis log tidak dikenal.' } end
    return { ok = true, key = d.key, on = d.on == true }
end)

Handle('logs_test', 'owner', function(src, d)
    if not TestWebhook(src, d.ch) then return { ok = false, msg = 'Webhook belum diisi di server.cfg (f_admin_webhook).' } end
    return { ok = true, msg = 'Pesan uji terkirim ke Discord.' }
end)
