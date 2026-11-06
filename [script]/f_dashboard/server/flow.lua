-- Arus uang: uang masuk (faucet) dan keluar (sink) per kategori, dijumlahkan di memori.
-- Tidak ada baris per transaksi. Ke DB hanya total per hari + kategori (tiap Config.FlushMinutes).
-- Perpindahan uang (setor/tarik bank, transfer, bayar ke rekening job, kasih/simpan cash) tidak dihitung:
--   * masuk + keluar dengan jumlah sama di tick yang sama dipasangkan = perpindahan
--   * cash item yang dipindah lewat ox_inventory (hook swapItems) = perpindahan
Dash = Dash or {}

local QBX = exports.qbx_core
local excluded = {}
for _, cid in ipairs(Config.Exclude) do excluded[cid] = true end
Dash.excluded = excluded

Dash.flows = {}    -- [day] = { ['in'] = { [cat] = amount }, out = { ... } }
Dash.unknown = {}  -- [dir] = { [reason] = amount } (hari ini, untuk melengkapi kata kunci)
Dash.alerts = {}   -- { at, cid, name, amount } 48 jam terakhir
Dash.online = {}   -- [citizenid] = src

local pending = {} -- [day|dir|cat] = amount belum tersimpan
local last = {}    -- [src] = { cid, cash, bank }
local moved = {}   -- [src] = GetGameTimer() terakhir cash item dipindah lewat inventory
local gain = {}    -- [cid] = uang masuk jam ini
local alerted = {} -- [cid] = true jam ini
local unknownDay, unknownCount

local function today() return os.date('%Y-%m-%d') end

local function categorize(dir, reason)
    local r = (reason or ''):lower()
    for _, c in ipairs(Config.Categories[dir]) do
        for _, k in ipairs(c.keys) do
            if r:find(k, 1, true) then return c.id end
        end
    end
    return 'other'
end

local function rp(n)
    local s = tostring(math.floor(n or 0)):reverse():gsub('(%d%d%d)', '%1.'):reverse()
    if s:sub(1, 1) == '.' then s = s:sub(2) end
    return 'Rp ' .. s
end

local function sendAlert(a)
    MySQL.insert('INSERT INTO f_dashboard_alert (citizenid, name, amount) VALUES (?, ?, ?)', { a.cid, a.name, a.amount })
    if Config.Alert.webhook == '' then return end
    PerformHttpRequest(Config.Alert.webhook, function() end, 'POST', json.encode({
        username = 'Dashboard Ekonomi',
        embeds = { {
            title = 'Uang masuk tidak wajar',
            description = ('**%s** (%s) mendapat **%s** dalam 1 jam terakhir.\nCek log transaksi pemain ini.'):format(a.name, a.cid, rp(a.amount)),
            color = 16729402,
            footer = { text = os.date('%d/%m/%Y %H:%M') },
        } },
    }), { ['Content-Type'] = 'application/json' })
end

local function record(dir, amount, reason, cid, src)
    local day = today()
    local cat = categorize(dir, reason)
    local d = Dash.flows[day]
    if not d then
        d = { ['in'] = {}, out = {} }
        Dash.flows[day] = d
    end
    d[dir][cat] = (d[dir][cat] or 0) + amount
    local key = day .. '|' .. dir .. '|' .. cat
    pending[key] = (pending[key] or 0) + amount

    if cat == 'other' then
        if unknownDay ~= day then
            unknownDay = day
            Dash.unknown = { ['in'] = {}, out = {} }
            unknownCount = { ['in'] = 0, out = 0 }
        end
        local list = Dash.unknown[dir]
        local r = (reason and reason ~= '') and reason:sub(1, 48) or '(tanpa alasan)'
        if list[r] then
            list[r] = list[r] + amount
        elseif unknownCount[dir] < 40 then -- batasi memori
            unknownCount[dir] = unknownCount[dir] + 1
            list[r] = amount
        end
    end

    if dir == 'in' and cid then
        gain[cid] = (gain[cid] or 0) + amount
        if gain[cid] >= Config.Alert.amount and not alerted[cid] then
            alerted[cid] = true
            local p = src and QBX:GetPlayer(src)
            local ci = p and p.PlayerData.charinfo
            local a = { at = os.time(), cid = cid, name = ci and (ci.firstname .. ' ' .. ci.lastname) or cid, amount = gain[cid] }
            Dash.alerts[#Dash.alerts + 1] = a
            sendAlert(a)
        end
    end
end

---------------------------------------------------------------- pasangkan per tick

local tick, scheduled = {}, false

local function process()
    scheduled = false
    local evs = tick
    tick = {}
    local removes = {}
    for i, e in ipairs(evs) do
        if e.dir == 'out' then
            local l = removes[e.amount]
            if not l then l = {}; removes[e.amount] = l end
            l[#l + 1] = i
        end
    end
    for _, e in ipairs(evs) do
        if e.dir == 'in' then
            local l = removes[e.amount]
            if l and #l > 0 then
                evs[table.remove(l, 1)].paired = true
                e.paired = true
            end
        end
    end
    for _, e in ipairs(evs) do
        if not e.paired then record(e.dir, e.amount, e.reason, e.cid, e.src) end
    end
end

local function push(e)
    if e.amount <= 0 then return end
    tick[#tick + 1] = e
    if not scheduled then
        scheduled = true
        SetTimeout(0, process)
    end
end

---------------------------------------------------------------- sumber event

local function remember(src)
    local p = QBX:GetPlayer(src)
    if not p then return end
    local pd = p.PlayerData
    last[src] = { cid = pd.citizenid, cash = pd.money.cash or 0, bank = pd.money.bank or 0 }
    Dash.online[pd.citizenid] = src
end

local function forget(src)
    local l = last[src]
    if l and Dash.online[l.cid] == src then Dash.online[l.cid] = nil end
    last[src] = nil
    moved[src] = nil
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    remember(player.PlayerData.source)
end)
AddEventHandler('qbx_core:server:playerLoggedOut', forget)
AddEventHandler('playerDropped', function() forget(source) end)

AddEventHandler('QBCore:Server:OnMoneyChange', function(src, moneyType, amount, action, reason)
    if moneyType ~= 'cash' and moneyType ~= 'bank' then return end
    local l = last[src]
    if not l then return remember(src) end
    local p = QBX:GetPlayer(src)
    if not p then return end
    local now = p.PlayerData.money[moneyType] or 0
    local before = l[moneyType]
    l[moneyType] = now
    if excluded[l.cid] then return end

    local diff
    if action == 'add' then
        diff = amount
    elseif action == 'remove' then
        diff = -amount
    else
        -- 'set': sinkron cash item ox_inventory atau set admin. Cash yang baru dipindah antar inventory = perpindahan.
        if moneyType == 'cash' and moved[src] and GetGameTimer() - moved[src] < 1500 then return end
        diff = now - before
        reason = (reason and reason:find('Sync', 1, true)) and 'item uang (script)' or reason
    end
    if diff == 0 then return end
    push({ dir = diff > 0 and 'in' or 'out', amount = math.abs(math.floor(diff)), reason = reason, cid = l.cid, src = src })
end)

-- Renewed-Banking (patch): perubahan saldo rekening job/gang/bersama
AddEventHandler('f_dashboard:account', function(account, amount, dir, resource)
    amount = tonumber(amount)
    if not amount then return end
    push({ dir = dir == 'add' and 'in' or 'out', amount = math.floor(amount), reason = ('%s (%s)'):format(resource or 'Renewed-Banking', account) })
end)

local function hookInventory()
    local inv = exports.ox_inventory
    inv:registerHook('swapItems', function(payload)
        if payload.fromType == 'player' then moved[tonumber(payload.fromInventory)] = GetGameTimer() end
        if payload.toType == 'player' then moved[tonumber(payload.toInventory)] = GetGameTimer() end
        return true
    end, { itemFilter = { money = true } })

    inv:registerHook('buyItem', function(payload)
        if payload.currency == 'money' and payload.totalPrice and payload.totalPrice > 0 then
            local l = last[payload.source]
            if l and not excluded[l.cid] then
                moved[payload.source] = GetGameTimer()
                record('out', math.floor(payload.totalPrice), 'shop:' .. tostring(payload.shopType), l.cid, payload.source)
            end
        end
        return true
    end)
end

---------------------------------------------------------------- simpan & muat

function Dash.FlushFlows()
    local values, params = {}, {}
    for key, amount in pairs(pending) do
        local day, dir, cat = key:match('^(.-)|(.-)|(.+)$')
        values[#values + 1] = '(?, ?, ?, ?)'
        params[#params + 1] = day
        params[#params + 1] = dir
        params[#params + 1] = cat
        params[#params + 1] = amount
    end
    if #values == 0 then return end
    pending = {}
    MySQL.query(('INSERT INTO f_dashboard_flow (day, dir, category, amount) VALUES %s ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)')
        :format(table.concat(values, ', ')), params)
end

function Dash.LoadFlows()
    local rows = MySQL.query.await([[SELECT DATE_FORMAT(day, '%Y-%m-%d') AS day, dir, category, amount
        FROM f_dashboard_flow WHERE day >= CURDATE() - INTERVAL 31 DAY]]) or {}
    for _, r in ipairs(rows) do
        local d = Dash.flows[r.day]
        if not d then
            d = { ['in'] = {}, out = {} }
            Dash.flows[r.day] = d
        end
        d[r.dir][r.category] = (d[r.dir][r.category] or 0) + tonumber(r.amount)
    end
    local al = MySQL.query.await([[SELECT UNIX_TIMESTAMP(created_at) AS at, citizenid AS cid, name, amount
        FROM f_dashboard_alert WHERE created_at >= NOW() - INTERVAL 48 HOUR ORDER BY created_at]]) or {}
    for _, a in ipairs(al) do
        Dash.alerts[#Dash.alerts + 1] = { at = tonumber(a.at), cid = a.cid, name = a.name, amount = tonumber(a.amount) }
    end
end

function Dash.StartFlow()
    hookInventory()
    for _, src in ipairs(GetPlayers()) do remember(tonumber(src)) end

    -- simpan arus uang berkala
    CreateThread(function()
        while true do
            Wait(Config.FlushMinutes * 60000)
            Dash.FlushFlows()
        end
    end)

    -- reset hitungan alert tiap jam, buang data lama dari memori
    CreateThread(function()
        while true do
            Wait(3600000)
            gain, alerted = {}, {}
            local cutoff = os.time() - 48 * 3600
            local keep = {}
            for _, a in ipairs(Dash.alerts) do
                if a.at >= cutoff then keep[#keep + 1] = a end
            end
            Dash.alerts = keep
            local old = os.date('%Y-%m-%d', os.time() - 32 * 86400)
            for day in pairs(Dash.flows) do
                if day < old then Dash.flows[day] = nil end
            end
        end
    end)
end

-- simpan sebelum restart/stop
AddEventHandler('txAdmin:events:serverShuttingDown', function() Dash.FlushFlows() end)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then Dash.FlushFlows() end
end)
