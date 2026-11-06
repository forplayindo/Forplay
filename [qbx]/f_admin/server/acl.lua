---------------------------------------------------------------------------
-- Role & izin. Semua lewat ACE FiveM supaya command script lain (ox_lib
-- restricted = 'group.admin') ikut aturan tanpa diubah:
--   Owner   : group.owner (server.cfg)  -> semua, termasuk uang
--   Admin   : group.admin               -> semua command (server.cfg "command allow"),
--                                          command yang dicabut + uang diberi "deny"
--   Support : group.support             -> hanya command/aksi yang dicentang ("allow")
-- Aksi panel memakai ACE 'f_admin.<key>'. ACE hanya hidup di memori server, jadi
-- dipasang ulang dari data/*.json setiap resource start dan dicabut saat stop.
---------------------------------------------------------------------------
local RESOURCE = GetCurrentResourceName()

local function loadJson(path, fallback)
    local raw = LoadResourceFile(RESOURCE, path)
    local ok, data = pcall(json.decode, raw or '')
    return ok and type(data) == 'table' and data or fallback
end

local function saveJson(path, data)
    SaveResourceFile(RESOURCE, path, json.encode(data, { indent = true }), -1)
end

Scan = loadJson('data/commands.json', {})   -- hasil _tools/scan_commands.py
Staff = loadJson('data/staff.json', {})     -- { uid, name, role, ids = {...}, by, at }
local Perms = loadJson('data/perms.json', {}) -- ['cmd:tp'] = { a = true, s = true }

ActionByKey = {}
for _, a in ipairs(Config.Actions) do ActionByKey[a.key] = a end

local isMoney, supportDefault = {}, {}
for _, c in ipairs(Config.MoneyCommands) do isMoney[c] = true end
for _, c in ipairs(Config.SupportCommands) do supportDefault[c] = true end

function IsMoneyCommand(name) return isMoney[name] == true end

---------------------------------------------------------------------------
-- Izin per kunci ('cmd:<command>' / 'act:<aksi>')
---------------------------------------------------------------------------
---@return { a: boolean, s: boolean, money: boolean? }
function PermOf(key)
    local kind, name = key:match('^(%a+):(.+)$')
    if kind == 'cmd' and isMoney[name] then return { a = false, s = false, money = true } end
    local act = kind == 'act' and ActionByKey[name]
    if act and act.money then return { a = false, s = false, money = true } end

    local p = Perms[key]
    if p then return { a = p.a == true, s = p.s == true } end
    if act then return { a = act.a == true, s = act.s == true } end
    return { a = true, s = supportDefault[name] == true }
end

local admin, support = Config.Groups.admin, Config.Groups.support

-- ACE yang harus aktif untuk satu kunci, sebagai daftar "principal object allow|deny".
local function wanted(key)
    local kind, name = key:match('^(%a+):(.+)$')
    local p, out = PermOf(key), {}
    if kind == 'cmd' then
        local obj = 'command.' .. name
        if not p.a then out[#out + 1] = ('%s %s deny'):format(admin, obj) end
        if p.s and not p.money then out[#out + 1] = ('%s %s allow'):format(support, obj) end
    elseif kind == 'act' and ActionByKey[name] and not p.money then
        local obj = 'f_admin.' .. name
        if p.a then out[#out + 1] = ('%s %s allow'):format(admin, obj) end
        if p.s then out[#out + 1] = ('%s %s allow'):format(support, obj) end
    end
    return out
end

local applied = {} -- [key] = { "principal object mode", ... } yang sedang terpasang

local function applyKey(key)
    local want, have = wanted(key), applied[key] or {}
    local wantSet, haveSet = {}, {}
    for _, l in ipairs(want) do wantSet[l] = true end
    for _, l in ipairs(have) do haveSet[l] = true end
    for _, l in ipairs(have) do
        if not wantSet[l] then ExecuteCommand('remove_ace ' .. l) end
    end
    for _, l in ipairs(want) do
        if not haveSet[l] then ExecuteCommand('add_ace ' .. l) end
    end
    applied[key] = #want > 0 and want or nil
end

---@param key string
---@param col 'a'|'s'
---@param value boolean
---@return { a: boolean, s: boolean, money: boolean? }
function SetPerm(key, col, value)
    local p = PermOf(key)
    if p.money then return p end
    p[col] = value
    -- Support tidak boleh melebihi Admin
    if col == 'a' and not value then p.s = false end
    if col == 's' and value then p.a = true end
    Perms[key] = { a = p.a, s = p.s }
    saveJson('data/perms.json', Perms)
    applyKey(key)
    return p
end

---------------------------------------------------------------------------
-- Staff -> add_principal identifier.<id> group.<role>
---------------------------------------------------------------------------
local function principals(entry, cmd)
    local group = Config.Groups[entry.role]
    if not group then return end
    for _, id in ipairs(entry.ids) do
        ExecuteCommand(('%s identifier.%s %s'):format(cmd, id, group))
    end
end

function SaveStaff() saveJson('data/staff.json', Staff) end

function AddStaff(entry)
    local uid = 0
    for _, s in ipairs(Staff) do uid = math.max(uid, s.uid or 0) end
    entry.uid = uid + 1
    Staff[#Staff + 1] = entry
    principals(entry, 'add_principal')
    SaveStaff()
    return entry
end

function FindStaff(uid)
    for i, s in ipairs(Staff) do
        if s.uid == uid then return s, i end
    end
end

function SetStaffRole(entry, role)
    principals(entry, 'remove_principal')
    entry.role = role
    principals(entry, 'add_principal')
    SaveStaff()
end

function RemoveStaff(entry, index)
    principals(entry, 'remove_principal')
    table.remove(Staff, index)
    SaveStaff()
end

---------------------------------------------------------------------------
-- Cek role / izin (juga diekspor untuk script lain)
---------------------------------------------------------------------------
---@return 'owner'|'admin'|'support'|nil
function GetRole(src)
    src = tostring(src)
    if IsPlayerAceAllowed(src, 'f_admin.owner') then return 'owner' end
    if IsPlayerAceAllowed(src, 'f_admin.role.admin') then return 'admin' end
    if IsPlayerAceAllowed(src, 'f_admin.role.support') then return 'support' end
end

---@param key string aksi panel, mis. 'player.bring'
function Can(src, key)
    return IsPlayerAceAllowed(tostring(src), 'f_admin.' .. key)
end

local RANK = { owner = 3, admin = 2, support = 1 }

---@return integer 0 = warga biasa
function Rank(src) return RANK[GetRole(src)] or 0 end

---Sanksi (kick, ban, bekukan, dll.) hanya ke pemain dengan role lebih rendah.
function Outranks(src, target) return Rank(src) > Rank(target) end

exports('GetRole', GetRole)
exports('Can', Can)
exports('IsStaff', function(src) return GetRole(src) ~= nil end)

---------------------------------------------------------------------------
-- Pasang semua saat start, cabut saat stop
---------------------------------------------------------------------------
local roleAces = {
    ('%s f_admin.role.admin allow'):format(admin),
    ('%s f_admin.role.support allow'):format(support),
}

CreateThread(function()
    for _, l in ipairs(roleAces) do ExecuteCommand('add_ace ' .. l) end

    local keys = {}
    for _, c in ipairs(Config.MoneyCommands) do keys['cmd:' .. c] = true end
    for _, c in ipairs(Config.SupportCommands) do keys['cmd:' .. c] = true end
    for _, a in ipairs(Config.Actions) do keys['act:' .. a.key] = true end
    for k in pairs(Perms) do keys[k] = true end
    for k in pairs(keys) do applyKey(k) end

    for _, s in ipairs(Staff) do principals(s, 'add_principal') end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RESOURCE then return end
    for _, lines in pairs(applied) do
        for _, l in ipairs(lines) do ExecuteCommand('remove_ace ' .. l) end
    end
    for _, l in ipairs(roleAces) do ExecuteCommand('remove_ace ' .. l) end
    for _, s in ipairs(Staff) do principals(s, 'remove_principal') end
end)
