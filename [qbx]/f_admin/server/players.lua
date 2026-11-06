---------------------------------------------------------------------------
-- Pemain online: daftar, detail, aksi bantuan & sanksi
---------------------------------------------------------------------------
local frozen = {}       -- [src] = true
local backPos = {}      -- [src] = vec3 posisi sebelum teleport (untuk Kembali / Kembalikan)
local spectating = {}   -- [staff] = { target, bucket }

local function ped(src) return GetPlayerPed(src) end

local function online(id)
    id = tonumber(id)
    return id and GetPlayerName(id) and id or nil
end

local function sameBucket(src, target)
    local b = GetPlayerRoutingBucket(target)
    if GetPlayerRoutingBucket(src) ~= b then SetPlayerRoutingBucket(src, b) end
end

local function teleport(src, coords)
    backPos[src] = GetEntityCoords(ped(src))
    SetEntityCoords(ped(src), coords.x, coords.y, coords.z, false, false, false, false)
end

local function summary(src)
    local p = exports.qbx_core:GetPlayer(src)
    local pd = p and p.PlayerData
    local role = GetRole(src)
    return {
        id = src,
        name = CharName(src),
        ooc = GetPlayerName(src),
        cid = pd and pd.citizenid or '-',
        job = pd and ('%s · %s'):format(pd.job.label, pd.job.grade.name or pd.job.grade.level) or 'Belum memilih karakter',
        ping = GetPlayerPing(src),
        role = role,
        dead = pd and (pd.metadata.isdead or pd.metadata.inlaststand) or false,
    }
end

Handle('players', false, function()
    local list = {}
    for _, s in ipairs(GetPlayers()) do list[#list + 1] = summary(tonumber(s)) end
    table.sort(list, function(a, b) return a.id < b.id end)
    return { ok = true, players = list }
end)

Handle('player', false, function(src, d)
    local id = online(d.id)
    if not id then return { ok = false, msg = 'Pemain sudah keluar.' } end
    local r = summary(id)
    local p = exports.qbx_core:GetPlayer(id)
    if p then
        local pd, md = p.PlayerData, p.PlayerData.metadata
        local st = Player(id).state
        r.gang = pd.gang.name ~= 'none' and ('%s · %s'):format(pd.gang.label, pd.gang.grade.name or pd.gang.grade.level) or '-'
        r.cash, r.bank = pd.money.cash or 0, pd.money.bank or 0
        r.food, r.water, r.stress = math.floor(md.hunger or 0), math.floor(md.thirst or 0), math.floor(md.stress or 0)
        r.armor = md.armor or 0
        r.phone = pd.charinfo.phone or '-'
        r.repc, r.repd = md.craftingrep or 0, md.dealerrep or 0
        r.firstname, r.lastname = pd.charinfo.firstname, pd.charinfo.lastname
        r.radio = st.radioChannel and st.radioChannel > 0 and tostring(st.radioChannel) or '-'
    end
    local pp = ped(id)
    r.hp = math.max(0, GetEntityHealth(pp) - 100)
    r.bucket = GetPlayerRoutingBucket(id)
    r.frozen = frozen[id] or false
    r.muted = MumbleIsPlayerMuted(id)
    r.canBack = backPos[id] ~= nil
    r.license = GetPlayerIdentifierByType(id, 'license2') or GetPlayerIdentifierByType(id, 'license') or '-'
    r.discord = GetPlayerIdentifierByType(id, 'discord') or '-'
    return { ok = true, player = r }
end)

---------------------------------------------------------------------------
-- Aksi ke pemain. need = kunci izin, rank = butuh role lebih tinggi dari target.
---------------------------------------------------------------------------
local A = {}

A['goto'] = { need = 'player.goto', fn = function(src, t)
    sameBucket(src, t)
    teleport(src, GetEntityCoords(ped(t)))
    Log(src, 'teleport', ('mendatangi **%s**'):format(Who(t)), t)
    return { ok = true, msg = 'Teleport ke ' .. CharName(t) }
end }

A.bring = { need = 'player.bring', fn = function(src, t)
    sameBucket(t, src)
    teleport(t, GetEntityCoords(ped(src)))
    Log(src, 'teleport', ('menarik **%s**'):format(Who(t)), t)
    return { ok = true, msg = CharName(t) .. ' ditarik ke posisimu' }
end }

A.sendback = { need = 'player.goto', fn = function(src, t)
    local pos = backPos[t]
    if not pos then return { ok = false, msg = 'Tidak ada posisi sebelumnya untuk pemain ini.' } end
    backPos[t] = nil
    SetEntityCoords(ped(t), pos.x, pos.y, pos.z, false, false, false, false)
    Log(src, 'teleport', ('mengembalikan **%s** ke posisi semula'):format(Who(t)), t)
    return { ok = true, msg = CharName(t) .. ' dikembalikan' }
end }

A.spectate = { need = 'player.spectate', fn = function(src, t)
    if t == src then return { ok = false, msg = 'Tidak bisa spectate diri sendiri.' } end
    if not spectating[src] then
        spectating[src] = { target = t, bucket = GetPlayerRoutingBucket(src), pos = GetEntityCoords(ped(src)) }
    else
        spectating[src].target = t
    end
    sameBucket(src, t)
    Log(src, 'spectate', ('spectate **%s**'):format(Who(t)), t)
    TriggerClientEvent('f_admin:client:spectate', src, t, GetEntityCoords(ped(t)), CharName(t))
    return { ok = true, close = true }
end }

A.revive = { need = 'player.revive', fn = function(src, t)
    TriggerClientEvent('f_medical:client:playerRevived', t)
    Log(src, 'revive', t == src and 'revive diri sendiri' or ('revive **%s**'):format(Who(t)), t ~= src and t or nil)
    return { ok = true, msg = (t == src and 'Kamu' or CharName(t)) .. ' di-revive' }
end }

A.heal = { need = 'player.revive', fn = function(src, t)
    TriggerClientEvent('f_medical:client:heal', t, 'full')
    SetPedArmour(ped(t), 100)
    Log(src, 'revive', t == src and 'heal diri sendiri' or ('heal **%s**'):format(Who(t)), t ~= src and t or nil)
    return { ok = true, msg = 'Darah & armor penuh' }
end }

A.freeze = { need = 'player.freeze', rank = true, fn = function(src, t)
    frozen[t] = not frozen[t] or nil
    FreezeEntityPosition(ped(t), frozen[t] == true)
    Log(src, 'freeze', ('%s **%s**'):format(frozen[t] and 'membekukan' or 'mencairkan', Who(t)), t)
    return { ok = true, msg = CharName(t) .. (frozen[t] and ' dibekukan' or ' dicairkan'), frozen = frozen[t] == true }
end }

A.dm = { need = 'player.dm', fn = function(src, t, d)
    local text = type(d.text) == 'string' and d.text:sub(1, 300) or ''
    if text:gsub('%s', '') == '' then return { ok = false, msg = 'Pesan kosong.' } end
    Notify(t, text, 'inform', 'Pesan dari Staff', 15000)
    Log(src, 'dm', ('mengirim pesan ke **%s**: %s'):format(Who(t), text), t)
    return { ok = true, msg = 'Pesan terkirim ke ' .. CharName(t) }
end }

A.fixveh = { need = 'vehicle.fix', fn = function(src, t)
    if GetVehiclePedIsIn(ped(t), false) == 0 then return { ok = false, msg = CharName(t) .. ' tidak di kendaraan.' } end
    TriggerClientEvent('f_admin:client:fixveh', t)
    return { ok = true, msg = 'Kendaraan ' .. CharName(t) .. ' diperbaiki' }
end }

A.sitveh = { need = 'player.sitveh', fn = function(src, t)
    local veh = GetVehiclePedIsIn(ped(t), false)
    if veh == 0 then return { ok = false, msg = CharName(t) .. ' tidak di kendaraan.' } end
    sameBucket(src, t)
    for seat = 0, 8 do
        if GetPedInVehicleSeat(veh, seat) == 0 then
            backPos[src] = GetEntityCoords(ped(src))
            SetPedIntoVehicle(ped(src), veh, seat)
            return { ok = true, msg = 'Duduk di kendaraan ' .. CharName(t) }
        end
    end
    return { ok = false, msg = 'Kursi kendaraan penuh.' }
end }

A.bucket = { need = 'player.bucket', rank = true, fn = function(src, t, d)
    local b = math.floor(tonumber(d.bucket) or -1)
    if b < 0 then return { ok = false, msg = 'Bucket tidak valid.' } end
    exports.qbx_core:SetPlayerBucket(t, b)
    Log(src, 'teleport', ('memindah **%s** ke routing bucket %d'):format(Who(t), b), t)
    return { ok = true, msg = CharName(t) .. ' dipindah ke bucket ' .. b }
end }

A.mute = { need = 'player.mute', rank = true, fn = function(src, t)
    local m = not MumbleIsPlayerMuted(t)
    MumbleSetPlayerMuted(t, m)
    Log(src, 'mute', ('%s suara **%s**'):format(m and 'mute' or 'unmute', Who(t)), t)
    if m then Notify(t, 'Suaramu di-mute oleh staff.', 'error') end
    return { ok = true, msg = CharName(t) .. (m and ' di-mute' or ' di-unmute'), muted = m }
end }

A.kill = { need = 'player.kill', rank = true, fn = function(src, t)
    TriggerClientEvent('f_admin:client:kill', t)
    Log(src, 'freeze', ('membunuh **%s**'):format(Who(t)), t)
    return { ok = true, msg = CharName(t) .. ' dibunuh' }
end }

A.kick = { need = 'player.kick', rank = true, fn = function(src, t, d)
    local reason = type(d.text) == 'string' and d.text:sub(1, 200) or ''
    if reason:gsub('%s', '') == '' then return { ok = false, msg = 'Isi alasan kick.' } end
    Log(src, 'kick', ('kick **%s**: %s'):format(Who(t), reason), t)
    DropPlayer(t, ('Kamu di-kick oleh staff.\nAlasan: %s'):format(reason))
    return { ok = true, msg = 'Pemain di-kick', gone = true }
end }

A.ban = { need = 'player.ban', rank = true, fn = function(src, t, d)
    local reason = type(d.text) == 'string' and d.text:sub(1, 200) or ''
    if reason:gsub('%s', '') == '' then return { ok = false, msg = 'Isi alasan ban.' } end
    local dur = 0
    if not d.perm then
        dur = (tonumber(d.hours) or 0) * 3600 + (tonumber(d.days) or 0) * 86400 + (tonumber(d.months) or 0) * 2592000
        if dur <= 0 then return { ok = false, msg = 'Isi lama ban atau centang Permanen.' } end
    end
    local name = Who(t)
    BanPlayer(t, reason, math.floor(dur), GetPlayerName(src))
    Log(src, 'ban', ('ban **%s** %s: %s'):format(name, dur == 0 and 'permanen' or DurationText(dur), reason), t)
    return { ok = true, msg = 'Pemain di-ban', gone = true }
end }

A.inventory = { need = 'player.inventory', rank = true, fn = function(src, t)
    exports.ox_inventory:forceOpenInventory(src, 'player', t)
    Log(src, 'inv', ('membuka inventaris **%s**'):format(Who(t)), t)
    return { ok = true, close = true }
end }

A.clothing = { need = 'player.clothing', fn = function(src, t)
    TriggerClientEvent('illenium-appearance:client:openClothingShopMenu', t, false)
    Log(src, 'inv', ('memberi menu pakaian ke **%s**'):format(Who(t)), t)
    return { ok = true, msg = 'Menu pakaian dibuka di layar ' .. CharName(t), close = t == src }
end }

Handle('player_act', false, function(src, d)
    local a = A[d.act]
    if not a then return { ok = false, msg = 'Aksi tidak dikenal.' } end
    if not Can(src, a.need) then return { ok = false, msg = 'Tidak punya izin untuk aksi ini.' } end
    local t = online(d.id)
    if not t then return { ok = false, msg = 'Pemain sudah keluar.' } end
    if a.rank and t ~= src and not Outranks(src, t) then
        return { ok = false, msg = 'Tidak bisa ke staff dengan role setara atau lebih tinggi.' }
    end
    return a.fn(src, t, d)
end)

-- berhenti spectate: kembali ke posisi & bucket semula
RegisterNetEvent('f_admin:server:spectateEnd', function()
    local src = source
    local s = spectating[src]
    if not s then return end
    spectating[src] = nil
    SetPlayerRoutingBucket(src, s.bucket)
    TriggerClientEvent('f_admin:client:spectateEnded', src, s.pos)
end)

-- posisi target yang sedang di-spectate (kalau keluar jangkauan stream)
lib.callback.register('f_admin:spectatePos', function(src)
    local s = spectating[src]
    if not s or not GetPlayerName(s.target) then return false end
    if GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(s.target) then sameBucket(src, s.target) end
    return GetEntityCoords(ped(s.target))
end)

---------------------------------------------------------------------------
-- Ubah data / job / gang
---------------------------------------------------------------------------
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, math.floor(tonumber(v) or lo))) end

Handle('set_data', 'player.setdata', function(src, d)
    local t = online(d.id)
    if not t then return { ok = false, msg = 'Pemain sudah keluar.' } end
    if t ~= src and not Outranks(src, t) then return { ok = false, msg = 'Tidak bisa ke staff dengan role setara atau lebih tinggi.' } end
    local p = exports.qbx_core:GetPlayer(t)
    if not p then return { ok = false, msg = 'Pemain belum memilih karakter.' } end

    local ci = p.PlayerData.charinfo
    local fn, ln = tostring(d.firstname or ''):sub(1, 24), tostring(d.lastname or ''):sub(1, 24)
    if fn ~= '' then ci.firstname = fn end
    if ln ~= '' then ci.lastname = ln end
    if type(d.phone) == 'string' and d.phone:match('^%d+$') and #d.phone <= 15 then ci.phone = d.phone end
    p.Functions.SetPlayerData('charinfo', ci)
    p.Functions.SetMetaData('hunger', clamp(d.food, 0, 100))
    p.Functions.SetMetaData('thirst', clamp(d.water, 0, 100))
    p.Functions.SetMetaData('stress', clamp(d.stress, 0, 100))
    local armor = clamp(d.armor, 0, 100)
    p.Functions.SetMetaData('armor', armor)
    SetPedArmour(ped(t), armor)
    p.Functions.SetMetaData('craftingrep', clamp(d.repc, 0, 100000))
    p.Functions.SetMetaData('dealerrep', clamp(d.repd, 0, 100000))
    local radio = tonumber(d.radio)
    if radio and radio >= 0 and GetResourceState('pma-voice') == 'started' then exports['pma-voice']:setPlayerRadio(t, radio) end

    Log(src, 'data', ('mengubah data **%s** (makan %s, minum %s, stres %s, armor %s)'):format(Who(t), clamp(d.food, 0, 100), clamp(d.water, 0, 100), clamp(d.stress, 0, 100), armor), t)
    return { ok = true, msg = 'Data ' .. CharName(t) .. ' disimpan' }
end)

local function groupList(all)
    local out = {}
    for name, g in pairs(all) do
        local grades = {}
        for lvl, gr in pairs(g.grades or {}) do grades[#grades + 1] = { level = tonumber(lvl), name = gr.name } end
        table.sort(grades, function(a, b) return a.level < b.level end)
        out[#out + 1] = { name = name, label = g.label or name, grades = grades }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

Handle('jobs', 'player.setjob', function()
    return { ok = true, jobs = groupList(exports.qbx_core:GetJobs()), gangs = groupList(exports.qbx_core:GetGangs()) }
end)

Handle('set_job', 'player.setjob', function(src, d)
    local t = online(d.id)
    if not t then return { ok = false, msg = 'Pemain sudah keluar.' } end
    local p = exports.qbx_core:GetPlayer(t)
    if not p then return { ok = false, msg = 'Pemain belum memilih karakter.' } end
    local grade = math.floor(tonumber(d.grade) or 0)
    local okSet, err
    if d.kind == 'gang' then
        okSet, err = exports.qbx_core:SetGang(p.PlayerData.citizenid, d.name, grade)
    else
        okSet, err = exports.qbx_core:SetJob(p.PlayerData.citizenid, d.name, grade)
    end
    if okSet == false then return { ok = false, msg = type(err) == 'table' and err.message or 'Gagal mengubah.' } end
    Log(src, 'job', ('mengubah %s **%s** → %s (grade %d)'):format(d.kind == 'gang' and 'gang' or 'job', Who(t), tostring(d.name), grade), t)
    return { ok = true, msg = ('%s %s diubah ke %s'):format(d.kind == 'gang' and 'Gang' or 'Job', CharName(t), tostring(d.name)) }
end)

---------------------------------------------------------------------------
-- Aksi diri sendiri (mode staff). Server memeriksa izin & mencatat log, client yang menjalankan.
---------------------------------------------------------------------------
local SELF = {
    noclip = { need = 'self.noclip', log = 'noclip', label = 'noclip' },
    god = { need = 'self.godmode', log = 'self', label = 'god mode' },
    invis = { need = 'self.invisible', log = 'self', label = 'mode tidak terlihat' },
    names = { need = 'self.names' },
    blips = { need = 'self.blips' },
    vehgod = { need = 'self.vehgod', log = 'self', label = 'godmode kendaraan' },
    ammo = { need = 'self.ammo', log = 'self', label = 'amunisi tak terbatas' },
    cuff = { need = 'self.cuff', log = 'self', label = 'borgol diri sendiri' },
    ped = { need = 'self.ped', log = 'self', label = 'ganti model ped' },
    tpm = { need = 'self.teleport' },
    fix = { need = 'vehicle.fix' },
    dv = { need = 'vehicle.delete' },
    tune = { need = 'vehicle.tune' },
    announce = { need = 'server.announce', log = 'server', label = 'pengumuman' },
    dev = { need = 'dev.tools' },
}

lib.callback.register('f_admin:self', function(src, key, state, extra)
    local s = SELF[key]
    if not s or not GetRole(src) or not Can(src, s.need) then return false end
    if key == 'tpm' and type(extra) == 'vector3' then backPos[src] = extra end
    -- lepas borgol harus dari server (f_police menolak client yang melepas sendiri)
    if key == 'cuff' and not state and GetResourceState('f_police') == 'started' then exports.f_police:ReleaseCuffs(src) end
    if s.log then
        if key == 'ped' then
            Log(src, s.log, ('mengganti model ped ke %s'):format(tostring(extra)))
        elseif key == 'announce' then
            Log(src, s.log, ('membuat pengumuman: %s'):format(tostring(extra):sub(1, 200)))
        else
            Log(src, s.log, ('%s %s'):format(state and 'menyalakan' or 'mematikan', s.label))
        end
    end
    return true
end)

Handle('self_back', 'self.teleport', function(src)
    local pos = backPos[src]
    if not pos then return { ok = false, msg = 'Belum ada posisi sebelumnya.' } end
    backPos[src] = nil
    SetEntityCoords(ped(src), pos.x, pos.y, pos.z, false, false, false, false)
    return { ok = true, msg = 'Kembali ke posisi sebelumnya' }
end)

-- Nama & blip pemain (mode staff). Posisi dari server supaya pemain jauh tetap terlihat di peta.
lib.callback.register('f_admin:radar', function(src)
    if not (Can(src, 'self.names') or Can(src, 'self.blips')) then return false end
    local out = {}
    for _, s in ipairs(GetPlayers()) do
        local id = tonumber(s)
        if id ~= src then
            local pp = ped(id)
            out[#out + 1] = { id = id, name = CharName(id), c = GetEntityCoords(pp), h = math.floor(GetEntityHeading(pp)), v = GetVehiclePedIsIn(pp, false) ~= 0 }
        end
    end
    return out
end)

AddEventHandler('playerDropped', function()
    local src = source
    frozen[src], backPos[src], spectating[src] = nil, nil, nil
end)
