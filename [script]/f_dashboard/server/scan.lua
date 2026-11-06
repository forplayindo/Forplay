-- Hitung ulang cache: semua karakter (offline dari DB, online dari memori qbx_core), rekening job/gang,
-- cash di penyimpanan, snapshot harian, dan status ekonomi. Jalan tiap Config.RebuildMinutes,
-- dipecah dengan Wait supaya tick server tidak tersendat. Menu admin hanya membaca hasilnya.
Dash = Dash or {}
Dash.days = {}   -- [day] = snapshot harian (60 hari terakhir)
Dash.cache = nil
Dash.building = false
Dash.lastBuild = 0

local QBX = exports.qbx_core
local CHUNK = 300

local LEVELS = {
    { id = 'lesu', label = 'Lesu', sev = 1, desc = 'Uang beredar menyusut, pemain kesulitan cari uang' },
    { id = 'sehat', label = 'Sehat', sev = 0, desc = 'Uang masuk dan keluar seimbang' },
    { id = 'waspada', label = 'Waspada', sev = 2, desc = 'Mulai condong ke inflasi, perlu dipantau' },
    { id = 'inflasi', label = 'Inflasi', sev = 3, desc = 'Uang terlalu banyak, harga mulai terasa murah' },
    { id = 'kritis', label = 'Kritis', sev = 4, desc = 'Uang naik sangat cepat, kemungkinan eksploit / bug' },
}

local function dayStr(offset) return os.date('%Y-%m-%d', os.time() + (offset or 0) * 86400) end

local function num(v) return math.floor(tonumber(v) or 0) end

local function pct(n) return (n > 0 and '+' or '') .. (('%.1f'):format(n):gsub('%.', ',')) .. '%' end

local function level(v, edges)
    if v < edges[1] then return 1 end
    if v <= edges[2] then return 2 end
    if v <= edges[3] then return 3 end
    if v <= edges[4] then return 4 end
    return 5
end

---------------------------------------------------------------- sumber data

local function loadPlayers()
    local rows = MySQL.query.await([[SELECT citizenid,
            JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS fn,
            JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) AS ln,
            CAST(COALESCE(JSON_EXTRACT(money, '$.cash'), 0) AS SIGNED) AS cash,
            CAST(COALESCE(JSON_EXTRACT(money, '$.bank'), 0) AS SIGNED) AS bank,
            CAST(COALESCE(JSON_EXTRACT(money, '$.dirty'), 0) AS SIGNED) AS dirty,
            UNIX_TIMESTAMP(COALESCE(last_logged_out, last_updated)) AS seen
        FROM players]]) or {}

    -- pemain online: angka di memori lebih baru dari DB
    local live = {}
    for _, pd in ipairs(QBX:GetPlayersData() or {}) do
        live[pd.citizenid] = pd
    end

    local list, now = {}, os.time()
    for i, r in ipairs(rows) do
        if not Dash.excluded[r.citizenid] then
            local pd = live[r.citizenid]
            local cash, bank, dirty, name = num(r.cash), num(r.bank), num(r.dirty), ((r.fn or '?') .. ' ' .. (r.ln or ''))
            if pd then
                cash, bank, dirty = num(pd.money.cash), num(pd.money.bank), num(pd.money.dirty)
                name = pd.charinfo.firstname .. ' ' .. pd.charinfo.lastname
            end
            dirty = math.min(math.max(dirty, 0), math.max(cash, 0))
            list[#list + 1] = {
                cid = r.citizenid, name = name,
                cash = cash - dirty, dirty = dirty, bank = bank, total = cash + bank,
                seen = pd and now or num(r.seen),
            }
        end
        if i % CHUNK == 0 then Wait(0) end
    end
    return list
end

local function loadAccounts()
    local rows = MySQL.query.await('SELECT id, amount FROM bank_accounts_new') or {}
    local jobs, gangs = QBX:GetJobs() or {}, QBX:GetGangs() or {}
    local crew = {}
    local ok, crows = pcall(MySQL.query.await, 'SELECT name, label FROM crew_gangs WHERE name IS NOT NULL')
    if ok and crows then
        for _, c in ipairs(crows) do crew[c.name] = c.label end
    end

    local out = { jobs = {}, gangs = {}, other = 0 }
    for _, r in ipairs(rows) do
        local id, bal = r.id, num(r.amount)
        if jobs[id] then
            out.jobs[#out.jobs + 1] = { id = id, label = jobs[id].label or id, bal = bal }
        elseif gangs[id] or crew[id] then
            out.gangs[#out.gangs + 1] = { id = id, label = crew[id] or (gangs[id] and gangs[id].label) or id, bal = bal }
        else
            out.other = out.other + bal
        end
    end
    table.sort(out.jobs, function(a, b) return a.bal > b.bal end)
    table.sort(out.gangs, function(a, b) return a.bal > b.bal end)
    return out
end

local function countMoney(data)
    if not data or data == '' then return 0 end
    local ok, items = pcall(json.decode, data)
    if not ok or type(items) ~= 'table' then return 0 end
    local n = 0
    for _, it in pairs(items) do
        if type(it) == 'table' and it.name == 'money' then n = n + num(it.count) end
    end
    return n
end

local function loadStorage()
    if not Config.CountStorage then return 0, 0 end
    local total = 0
    local queries = {
        [[SELECT data AS d FROM ox_inventory WHERE data LIKE '%"money"%']],
        [[SELECT trunk AS d FROM player_vehicles WHERE trunk LIKE '%"money"%']],
        [[SELECT glovebox AS d FROM player_vehicles WHERE glovebox LIKE '%"money"%']],
    }
    for _, q in ipairs(queries) do
        local ok, rows = pcall(MySQL.query.await, q)
        if ok and rows then
            for i, r in ipairs(rows) do
                total = total + countMoney(r.d)
                if i % 100 == 0 then Wait(0) end
            end
        end
    end
    local ok, dirty = pcall(MySQL.scalar.await, 'SELECT COALESCE(SUM(amount), 0) FROM f_dirtymoney_inv')
    return total, ok and num(dirty) or 0
end

---------------------------------------------------------------- statistik

local function topBy(list, key)
    local copy = {}
    for i = 1, #list do copy[i] = list[i] end
    table.sort(copy, function(a, b) return a[key] > b[key] end)
    local out = {}
    for i = 1, math.min(10, #copy) do
        local p = copy[i]
        out[i] = { cid = p.cid, name = p.name, cash = p.cash, bank = p.bank, dirty = p.dirty, total = p.total }
    end
    return out
end

local function distribution(list)
    local vals = {}
    for i = 1, #list do vals[i] = math.max(0, list[i].total) end
    table.sort(vals)
    local n, sum = #vals, 0
    for i = 1, n do sum = sum + vals[i] end

    local median = 0
    if n > 0 then
        median = n % 2 == 1 and vals[(n + 1) // 2] or (vals[n // 2] + vals[n // 2 + 1]) / 2
    end

    local function shareTop(frac)
        local k = math.max(1, math.floor(n * frac + 0.5))
        local s = 0
        for i = n - k + 1, n do s = s + vals[i] end
        return sum > 0 and s / sum * 100 or 0
    end
    local function shareBottom(frac)
        local k = math.floor(n * frac)
        local s = 0
        for i = 1, k do s = s + vals[i] end
        return sum > 0 and s / sum * 100 or 0
    end

    -- Gini dari data terurut
    local gini = 0
    if n > 0 and sum > 0 then
        local acc = 0
        for i = 1, n do acc = acc + (2 * i - n - 1) * vals[i] end
        gini = acc / (n * sum)
    end

    local edges = Config.Brackets
    local counts = {}
    for i = 1, #edges + 1 do counts[i] = 0 end
    for i = 1, n do
        local b = #edges + 1
        for j = 1, #edges do
            if vals[i] < edges[j] then b = j; break end
        end
        counts[b] = counts[b] + 1
    end

    return {
        median = median, avg = n > 0 and sum / n or 0,
        top10 = n > 0 and shareTop(0.1) or 0, bottom50 = n > 0 and shareBottom(0.5) or 0,
        gini = gini, brackets = counts, edges = edges,
    }
end

---------------------------------------------------------------- status

local function sumFlows(days)
    local tin, tout, cin, cout = 0, 0, {}, {}
    for i = 0, days - 1 do
        local d = Dash.flows[dayStr(-i)]
        if d then
            for c, v in pairs(d['in']) do tin = tin + v; cin[c] = (cin[c] or 0) + v end
            for c, v in pairs(d.out) do tout = tout + v; cout[c] = (cout[c] or 0) + v end
        end
    end
    return tin, tout, cin, cout
end
Dash.SumFlows = sumFlows

local function catLabel(dir, id)
    for _, c in ipairs(Config.Categories[dir]) do
        if c.id == id then return c.label end
    end
    return 'Lainnya'
end
Dash.CatLabel = catLabel

local function biggest(map, total, dir)
    local best, bv = nil, -1
    for c, v in pairs(map) do
        if v > bv then best, bv = c, v end
    end
    if not best or total <= 0 then return nil end
    return ('%s (%d%%)'):format(catLabel(dir, best), math.floor(bv / total * 100 + 0.5))
end

local function baseSnapshot()
    -- snapshot paling baru yang umurnya >= Config.MinDays hari
    local target = dayStr(-Config.MinDays)
    local best
    for day in pairs(Dash.days) do
        if day <= target and (not best or day > best) then best = day end
    end
    return best and Dash.days[best]
end

local function buildStatus(snap)
    local th = Config.Thresholds
    local base = baseSnapshot()
    local count = 0
    for _ in pairs(Dash.days) do count = count + 1 end

    local growth = base and base.perActive > 0 and (snap.perActive / base.perActive - 1) * 100 or nil
    local tin, tout, cin, cout = sumFlows(7)
    local ratio = tout > 0 and tin / tout or (tin > 0 and 99 or nil)

    local cutoff = os.time() - 86400
    local alerts = {}
    for _, a in ipairs(Dash.alerts) do
        if a.at >= cutoff then alerts[#alerts + 1] = a end
    end

    local st = { growth = growth, ratio = ratio, days = count, minDays = Config.MinDays, flags = {}, rec = {} }
    local lv
    if growth then lv = level(growth, th.growth) end
    if ratio then
        local r = level(ratio, th.ratio)
        if not lv or LEVELS[r].sev > LEVELS[lv].sev then lv = r end
    end
    if #alerts > 0 then lv = 5 end

    if #alerts == 0 and (not base or not lv) then
        st.id, st.label, st.desc = 'kumpul', 'Mengumpulkan data', ('Status muncul setelah ada data %d hari (sekarang %d hari)'):format(Config.MinDays, count)
    else
        local L = LEVELS[lv]
        st.id, st.label, st.desc = L.id, L.label, L.desc
    end

    -- penanda tambahan
    if snap.top10 > Config.InequalityShare then
        st.flags[#st.flags + 1] = { t = 'warn', text = ('Ketimpangan tinggi · 10%% teratas kuasai %d%%'):format(math.floor(snap.top10 + 0.5)) }
    end
    if base and base.median > 0 and snap.median < base.median and snap.all > base.all then
        st.flags[#st.flags + 1] = { t = 'warn', text = ('Median turun %s saat total naik'):format(pct((snap.median / base.median - 1) * 100)) }
    end
    if #alerts > 0 then
        st.flags[#st.flags + 1] = { t = 'bad', text = ('%d alert uang tidak wajar (24 jam)'):format(#alerts) }
    end

    -- rekomendasi
    local rec = st.rec
    local ratioTxt = ratio and (('%.2f'):format(ratio):gsub('%.', ',')) .. '×' or '-'
    local topIn, topOut = biggest(cin, tin, 'in'), biggest(cout, tout, 'out')
    if st.id == 'kumpul' then
        rec[#rec + 1] = 'Data belum cukup untuk menilai. Biarkan server berjalan beberapa hari.'
        if topIn then rec[#rec + 1] = ('Sementara ini sumber uang terbesar: <b>%s</b>.'):format(topIn) end
    elseif st.id == 'kritis' then
        if growth then rec[#rec + 1] = ('Uang per pemain aktif naik <b>%s</b> dalam 7 hari, jauh di atas normal.'):format(pct(growth)) end
        if #alerts > 0 then
            local ids = {}
            for i = 1, math.min(3, #alerts) do ids[#ids + 1] = '<b>' .. alerts[i].cid .. '</b>' end
            rec[#rec + 1] = ('<b>%d alert</b> uang tidak wajar dalam 24 jam. Cek log Discord untuk %s.'):format(#alerts, table.concat(ids, ', '))
        end
        rec[#rec + 1] = 'Kemungkinan ada <b>eksploit atau bug</b> pada script job/penjualan. Periksa sebelum menyesuaikan harga.'
        if topIn then rec[#rec + 1] = ('Sumber uang terbesar: <b>%s</b>.'):format(topIn) end
    elseif st.id == 'inflasi' then
        rec[#rec + 1] = ('Uang masuk <b>%s</b> lebih besar dari yang keluar.'):format(ratioTxt)
        if topIn then rec[#rec + 1] = ('Sumber terbesar: <b>%s</b>. Pertimbangkan <b>turunkan bayaran 10–15%%</b> di sumber ini.'):format(topIn) end
        rec[#rec + 1] = ('Tambah pengeluaran (pajak, biaya servis, garasi).%s'):format(topOut and (' Pengeluaran terbesar saat ini hanya <b>' .. topOut .. '</b>.') or '')
    elseif st.id == 'waspada' then
        rec[#rec + 1] = ('Uang masuk <b>%s</b> lebih besar dari yang keluar.'):format(ratioTxt)
        if topIn then rec[#rec + 1] = ('Belum perlu tindakan besar. Pantau sumber terbesar: <b>%s</b>.'):format(topIn) end
        rec[#rec + 1] = 'Siapkan rencana pengeluaran baru (pajak kendaraan, biaya garasi) kalau tren berlanjut.'
    elseif st.id == 'lesu' then
        rec[#rec + 1] = ('Uang keluar lebih besar dari uang masuk (rasio <b>%s</b>).'):format(ratioTxt)
        rec[#rec + 1] = 'Pertimbangkan <b>menaikkan bayaran job</b> atau gaji, terutama job yang paling banyak dikerjakan.'
        if topOut then rec[#rec + 1] = ('Cek pengeluaran yang terlalu mahal: <b>%s</b> paling besar.'):format(topOut) end
    else
        rec[#rec + 1] = ('Uang masuk dan keluar seimbang (rasio <b>%s</b>).'):format(ratioTxt)
        rec[#rec + 1] = 'Tidak perlu perubahan. Pantau lagi minggu depan.'
    end
    return st, base
end

---------------------------------------------------------------- hitung ulang

function Dash.Rebuild()
    if Dash.building then return false end
    Dash.building = true
    local ok, err = pcall(function()
        local players = loadPlayers()
        Wait(0)
        local acc = loadAccounts()
        Wait(0)
        local storage, storageDirty = loadStorage()

        local cash, bank, dirty, active = 0, 0, 0, 0
        local activeSince = os.time() - Config.ActiveDays * 86400
        for i, p in ipairs(players) do
            cash, bank, dirty = cash + p.cash, bank + p.bank, dirty + p.dirty
            if p.seen >= activeSince then active = active + 1 end
            if i % CHUNK == 0 then Wait(0) end
        end
        local jobs, gangs = 0, 0
        for _, a in ipairs(acc.jobs) do jobs = jobs + a.bal end
        for _, a in ipairs(acc.gangs) do gangs = gangs + a.bal end

        local dist = distribution(players)
        Wait(0)
        local all = cash + bank + dirty + storage + jobs + gangs + acc.other
        local snap = {
            all = all, cash = cash, bank = bank, dirty = dirty, storage = storage, storageDirty = storageDirty,
            jobs = jobs, gangs = gangs, other = acc.other,
            players = #players, active = active, perActive = all / math.max(active, 1),
            median = dist.median, avg = dist.avg, top10 = dist.top10, bottom50 = dist.bottom50, gini = dist.gini,
        }

        local day = dayStr()
        Dash.days[day] = snap
        MySQL.query('INSERT INTO f_dashboard_daily (day, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', { day, json.encode(snap) })

        local status, base = buildStatus(snap)
        Dash.cache = {
            updated = os.time(),
            snap = snap,
            base = base,
            status = status,
            dist = dist,
            top = { total = topBy(players, 'total'), bank = topBy(players, 'bank'), cash = topBy(players, 'cash'), dirty = topBy(players, 'dirty') },
            jobs = acc.jobs,
            gangs = acc.gangs,
            excluded = #Config.Exclude,
        }
    end)
    Dash.building = false
    Dash.lastBuild = os.time()
    if not ok then print(('^1[f_dashboard] gagal hitung ulang: %s^0'):format(err)) end
    return ok
end

function Dash.LoadDays()
    local rows = MySQL.query.await([[SELECT DATE_FORMAT(day, '%Y-%m-%d') AS day, data FROM f_dashboard_daily
        WHERE day >= CURDATE() - INTERVAL 60 DAY]]) or {}
    for _, r in ipairs(rows) do
        local ok, d = pcall(json.decode, r.data)
        if ok and d then Dash.days[r.day] = d end
    end
end

-- buang snapshot lama dari memori (DB tetap menyimpan)
function Dash.TrimDays()
    local old = dayStr(-61)
    for day in pairs(Dash.days) do
        if day < old then Dash.days[day] = nil end
    end
end
