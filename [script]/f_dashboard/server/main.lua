-- Akses menu, kirim cache ke admin, jadwal hitung ulang. Buka menu = 0 query.
local function allowed(src)
    for _, ace in ipairs(Config.Aces) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    return false
end

local function dayStr(offset) return os.date('%Y-%m-%d', os.time() + (offset or 0) * 86400) end

local function flowPeriod(days)
    local tin, tout, cin, cout = Dash.SumFlows(days)
    local function list(map, dir)
        local out = {}
        for c, v in pairs(map) do out[#out + 1] = { id = c, label = Dash.CatLabel(dir, c), v = v } end
        table.sort(out, function(a, b) return a.v > b.v end)
        return out
    end
    return { tin = tin, tout = tout, ['in'] = list(cin, 'in'), out = list(cout, 'out') }
end

local function unknownList(dir)
    local out = {}
    for r, v in pairs(Dash.unknown[dir] or {}) do out[#out + 1] = { r = r, v = v } end
    table.sort(out, function(a, b) return a.v > b.v end)
    for i = #out, 11, -1 do out[i] = nil end
    return out
end

local function markOnline(list)
    for _, p in ipairs(list) do p.online = Dash.online[p.cid] ~= nil end
    return list
end

---Data untuk NUI, disusun dari cache + arus uang di memori (tanpa query)
local function payload()
    local c = Dash.cache
    if not c then return nil end

    local series, flow14 = {}, {}
    for i = 29, 0, -1 do
        local day = dayStr(-i)
        local s = Dash.days[day]
        if s then series[#series + 1] = { d = day, v = s.all } end
    end
    for i = 13, 0, -1 do
        local day = dayStr(-i)
        local f = Dash.flows[day]
        local tin, tout = 0, 0
        if f then
            for _, v in pairs(f['in']) do tin = tin + v end
            for _, v in pairs(f.out) do tout = tout + v end
        end
        flow14[#flow14 + 1] = { d = day, i = tin, o = tout }
    end

    local brackets, edges = {}, c.dist.edges
    for i, n in ipairs(c.dist.brackets) do
        brackets[i] = { lo = edges[i - 1] or 0, hi = edges[i], n = n }
    end

    return {
        now = os.time(),
        updated = c.updated,
        every = Config.RebuildMinutes,
        cooldown = Config.RefreshCooldown,
        lastBuild = Dash.lastBuild,
        status = c.status,
        thresholds = Config.Thresholds,
        inequality = Config.InequalityShare,
        snap = c.snap,
        base = c.base,
        excluded = c.excluded,
        top = {
            total = markOnline(c.top.total), bank = markOnline(c.top.bank),
            cash = markOnline(c.top.cash), dirty = markOnline(c.top.dirty),
        },
        jobs = c.jobs,
        gangs = c.gangs,
        series = series,
        flow14 = flow14,
        flows = { today = flowPeriod(1), d7 = flowPeriod(7), d30 = flowPeriod(30) },
        unknown = { ['in'] = unknownList('in'), out = unknownList('out') },
        dist = { median = c.dist.median, avg = c.dist.avg, top10 = c.dist.top10, bottom50 = c.dist.bottom50, gini = c.dist.gini, brackets = brackets },
    }
end

RegisterCommand(Config.Command, function(src)
    if src == 0 or not allowed(src) then return end
    local data = payload()
    if not data then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Ekonomi', description = 'Data sedang disiapkan, coba lagi sebentar.', type = 'inform' })
        return
    end
    TriggerClientEvent('f_dashboard:open', src, data)
end, false)

lib.callback.register('f_dashboard:refresh', function(src)
    if not allowed(src) then return false end
    local wait = Dash.lastBuild + Config.RefreshCooldown - os.time()
    if wait > 0 or Dash.building then return { wait = math.max(wait, 5) } end
    Dash.Rebuild()
    return { data = payload() }
end)

---------------------------------------------------------------- start

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_dashboard_daily (
        day DATE NOT NULL PRIMARY KEY,
        data TEXT NOT NULL
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_dashboard_flow (
        day DATE NOT NULL,
        dir VARCHAR(3) NOT NULL,
        category VARCHAR(32) NOT NULL,
        amount BIGINT NOT NULL DEFAULT 0,
        PRIMARY KEY (day, dir, category)
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_dashboard_alert (
        id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        citizenid VARCHAR(50) NOT NULL,
        name VARCHAR(100) DEFAULT NULL,
        amount BIGINT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        KEY created_at (created_at)
    )]])
    -- data lama (sekali saat start)
    MySQL.query('DELETE FROM f_dashboard_flow WHERE day < CURDATE() - INTERVAL 400 DAY')
    MySQL.query('DELETE FROM f_dashboard_alert WHERE created_at < NOW() - INTERVAL 90 DAY')

    Dash.LoadDays()
    Dash.LoadFlows()
    Dash.StartFlow()

    Wait(20000) -- biarkan server selesai start dulu
    while true do
        Dash.Rebuild()
        Dash.TrimDays()
        Wait(Config.RebuildMinutes * 60000)
    end
end)
