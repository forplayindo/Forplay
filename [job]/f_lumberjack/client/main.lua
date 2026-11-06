-- state & helper bersama untuk semua file client (world.lua, carry.lua, truck.lua, sawmill.lua)
FLJ = {
    config = require 'config.client',
    shared = require 'config.shared',
    crew = nil,         -- payload server terakhir, nil jika tidak dalam kru
}
local config, sharedConfig = FLJ.config, FLJ.shared

-- prop kayu: batang besar setelah tumbang, potongan (solo) — prop_log_01 kalau modelnya tidak ada di game
FLJ.models = {
    trunk = IsModelInCdimage(sharedConfig.trunk.model) and sharedConfig.trunk.model or `prop_log_01`,
    piece = IsModelInCdimage(sharedConfig.piece.model) and sharedConfig.piece.model or `prop_log_01`,
}

-- panjang model & putaran supaya sisi panjangnya searah heading (model memanjang di X diputar 90°)
local axisCache = {}
function FLJ.modelAxis(model)
    local a = axisCache[model]
    if not a then
        lib.requestModel(model, 5000)   -- dimensions read 0 while the model isn't loaded
        local mn, mx = GetModelDimensions(model)
        local sx, sy = mx.x - mn.x, mx.y - mn.y
        a = sx > sy and { len = sx, width = sy, yaw = 90.0 } or { len = sy, width = sx, yaw = 0.0 }
        a.height, a.bottom = mx.z - mn.z, mn.z
        axisCache[model] = a
    end
    return a
end

local menuOpen = false
local confirmCb
local outfitSaved
local promptText
local busy = false
local loopRunning = false

function FLJ.notify(msg, typ)
    exports.qbx_core:Notify(msg, typ or 'inform')
end
local notify = FLJ.notify

local function rupiah(n)
    return 'Rp ' .. lib.math.groupdigits(math.floor(n or 0), '.')
end

function FLJ.isLeader()
    return FLJ.crew ~= nil and FLJ.crew.leader == cache.serverId
end

function FLJ.working()
    return FLJ.crew ~= nil and FLJ.crew.phase == 'work'
end

function FLJ.truck()
    local crew = FLJ.crew
    if not crew or not crew.netId or not NetworkDoesEntityExistWithNetworkId(crew.netId) then return end
    local veh = NetToVeh(crew.netId)
    if veh ~= 0 and DoesEntityExist(veh) then return veh end
end

local function showPrompt(text)
    if promptText == text then return end
    promptText = text
    lib.showTextUI(text)
end

local function hidePrompt()
    if not promptText then return end
    promptText = nil
    lib.hideTextUI()
end

-- suara 3D sederhana lewat NUI: volume turun sesuai jarak
function FLJ.playSound(name, coords)
    local dist = #(GetEntityCoords(cache.ped) - vec3(coords.x, coords.y, coords.z))
    if dist > config.soundDistance then return end
    SendNUIMessage({ action = 'sound', name = name, volume = config.volume * (1.0 - dist / config.soundDistance) })
end

RegisterNetEvent('f_lumberjack:client:sound', function(name, coords)
    FLJ.playSound(name, coords)
end)

---------------------------------------------------------------------------
-- seragam: otomatis saat Mulai Kerja, baju asli kembali saat kerja selesai / batal
---------------------------------------------------------------------------
-- mapping komponen sama dengan f_garbagejob / f_mining (illenium LoadJobOutfit)
local OUTFIT_COMPONENTS = { pants = 4, arms = 3, ['t-shirt'] = 8, torso2 = 11, shoes = 6 }

local function myOutfit()
    local female = tonumber(QBX.PlayerData.charinfo and QBX.PlayerData.charinfo.gender) == 1
    return female and config.outfit.female or config.outfit.male
end

local function applyOutfit()
    if outfitSaved then return end
    local ok, appearance = pcall(function()
        return exports['illenium-appearance']:getPedAppearance(cache.ped)
    end)
    outfitSaved = ok and appearance or true
    for name, component in pairs(OUTFIT_COMPONENTS) do
        local part = myOutfit()[name]
        if part then SetPedComponentVariation(cache.ped, component, part.item, part.texture, 0) end
    end
end

local function restoreOutfit()
    if not outfitSaved then return end
    local saved = outfitSaved
    outfitSaved = nil
    if type(saved) == 'table' and pcall(function()
        exports['illenium-appearance']:setPedAppearance(cache.ped, saved)
    end) then return end
    TriggerEvent('illenium-appearance:client:reloadSkin', true)
end

RegisterNetEvent('f_lumberjack:client:outfit', function(on)
    if on then applyOutfit() else restoreOutfit() end
end)

RegisterNetEvent('f_lumberjack:client:waypoint', function(at)
    SetNewWaypoint(at.x, at.y)
end)

---------------------------------------------------------------------------
-- HUD kanan tengah, hanya dikirim saat state server berubah
---------------------------------------------------------------------------
local function myShare(data)
    for _, m in ipairs(data.members) do
        if m.id == cache.serverId then return m.share end
    end
    return 0
end

local function hudStep(data)
    if data.unloading then return 'Mengolah kayu...', 'Batang masuk conveyor satu per satu' end
    if data.cargo > 0 then return 'Bawa papan ke markas', 'Bongkar papan di Mandor Paleto' end
    if data.output > 0 and data.bed == 0 then return 'Papan siap di sawmill', 'Pindahkan papan ke truk di ujung conveyor' end
    if data.bed >= data.cap then return 'Bak penuh, ke sawmill', 'Parkir di stasiun olah, tekan [E]' end
    return 'Tebang & muat kayu', #data.members > 1 and 'Angkat batang berdua ke bak truk' or 'Potong batang, panggul ke bak truk'
end

local function updateHud(data)
    if not data or data.phase ~= 'work' then
        return SendNUIMessage({ action = 'hud' })
    end
    local share = myShare(data)
    local pending = data.cargo + data.output
    local title, sub = hudStep(data)
    SendNUIMessage({
        action = 'hud',
        data = {
            title = title, sub = sub,
            bed = data.bed, cap = data.cap,
            ground = data.ground, groundLimit = sharedConfig.groundLimit,
            output = data.output, cargo = data.cargo,
            size = #data.members, share = share, bonus = data.bonus,
            mine = #data.members > 1 and math.floor(pending * share / 100) or pending,
        },
    })
end

---------------------------------------------------------------------------
-- prompt pengemudi truk: olah kayu di sawmill, selesai kerja di markas
---------------------------------------------------------------------------
local function openConfirm(data, cb)
    confirmCb = cb
    SendNUIMessage({ action = 'confirm', data = data })
    SetNuiFocus(true, true)
end

local function nearStation(veh)
    local pos = GetEntityCoords(veh)
    for i, s in ipairs(sharedConfig.stations) do
        if #(pos - s.xyz) < sharedConfig.stationRadius then return i end
    end
end

local function askProcess(index)
    local crew = FLJ.crew
    local bonus = crew.bonus or 0
    local papan = math.floor(crew.bed * sharedConfig.papanPerPiece * (1 + bonus / 100))
    openConfirm({
        title = 'Olah Kayu',
        rows = {
            { 'Kayu di bak', ('%s potong'):format(crew.bed) },
            { 'Hasil', ('%s papan%s'):format(papan, bonus > 0 and (' (bonus kru +%s%%)'):format(bonus) or '') },
        },
        note = 'Batang masuk conveyor satu per satu, truk dikunci sampai bak kosong. Papan muncul di ujung conveyor, pindahkan ke truk lalu bongkar di markas Paleto.',
        confirm = 'Olah',
    }, function()
        local res = lib.callback.await('f_lumberjack:server:process', false, index)
        if res and res.ok then
            notify(('Membongkar %s potong kayu ke conveyor...'):format(res.count), 'inform')
        elseif res and res.msg then
            notify(res.msg, 'error')
        end
    end)
end

local function askFinish()
    local crew = FLJ.crew
    local rows = {}
    local pending = crew.cargo + crew.output
    if pending > 0 then
        rows[#rows + 1] = { 'Papan belum dibongkar', ('%s papan (langsung masuk gudang)'):format(pending) }
    end
    if crew.bed > 0 then
        rows[#rows + 1] = { 'Kayu di bak', ('%s potong (hilang, belum diolah)'):format(crew.bed) }
    end
    if #rows == 0 then rows[1] = { 'Truk', 'dikembalikan' } end
    local note = 'Truk dikembalikan dan baju asli dipakai lagi. Kru tetap utuh, bicara dengan Mandor untuk mulai lagi.'
    openConfirm({ title = 'Selesai Kerja', rows = rows, note = note, confirm = 'Selesai' }, function()
        local res = lib.callback.await('f_lumberjack:server:finish', false)
        if res and not res.ok and res.msg then notify(res.msg, 'error') end
    end)
end

local function workLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        local frozen
        while FLJ.working() do
            local wait = 1000
            local veh = FLJ.truck()
            local driving = veh and cache.vehicle == veh and cache.seat == -1
            local crew = FLJ.crew

            if driving then
                -- the driver owns the truck: hold it still while the bed is being unloaded
                if crew.unloading ~= (frozen == veh) then
                    FreezeEntityPosition(veh, crew.unloading)
                    frozen = crew.unloading and veh or nil
                end
                local station = not crew.unloading and crew.bed > 0 and nearStation(veh)
                local atFinish = #(GetEntityCoords(veh) - sharedConfig.depot.coords) < sharedConfig.depot.radius
                if station then
                    wait = 0
                    showPrompt('[E] Olah Kayu')
                    if IsControlJustPressed(0, 38) and not busy and not menuOpen then askProcess(station) end
                elseif atFinish and not crew.unloading then
                    wait = 0
                    showPrompt('[E] Selesai Kerja')
                    if IsControlJustPressed(0, 38) and not busy and not menuOpen then askFinish() end
                else
                    hidePrompt()
                end
            else
                if frozen and DoesEntityExist(frozen) then FreezeEntityPosition(frozen, false) end
                frozen = nil
                hidePrompt()
            end
            Wait(wait)
        end
        if frozen and DoesEntityExist(frozen) then FreezeEntityPosition(frozen, false) end
        hidePrompt()
        loopRunning = false
    end)
end

---------------------------------------------------------------------------
-- server state
---------------------------------------------------------------------------
local refreshMenu

-- panel Alur Kerja (f_panduan), opsional
local function panduan(fn, ...)
    if GetResourceState('f_panduan') == 'started' then exports.f_panduan[fn](exports.f_panduan, ...) end
end

AddEventHandler('f_panduan:client:requestStep', function(job)
    if job ~= 'kayu' or not FLJ.working() then return end
    local c = FLJ.crew
    local n = 1
    if c.cargo > 0 then n = 5
    elseif c.output > 0 and c.bed == 0 then n = 4
    elseif c.unloading or c.bed >= c.cap then n = 3
    elseif c.bed > 0 or c.ground > 0 then n = 2 end
    panduan('SetStep', 'kayu', n)
end)

RegisterNetEvent('f_lumberjack:client:sync', function(data)
    local was = FLJ.working()
    FLJ.crew = data
    if data.phase == 'work' then workLoop() end
    if data.phase == 'work' and not was then panduan('Start', 'kayu')
    elseif data.phase ~= 'work' and was then panduan('Stop', 'kayu') end
    updateHud(data)
    if menuOpen then refreshMenu() end
end)

RegisterNetEvent('f_lumberjack:client:ended', function(reason)
    FLJ.crew = nil
    panduan('Stop', 'kayu')
    updateHud()
    hidePrompt()
    restoreOutfit()
    if FLJ.stopCarry then FLJ.stopCarry() end
    if reason then notify(reason, 'inform') end
    if menuOpen then refreshMenu() end
end)

RegisterNetEvent('f_lumberjack:client:invite', function(leaderName)
    local answer = lib.alertDialog({
        header = 'Ajakan Kerja Penebang Kayu',
        content = ('%s mengajakmu bergabung ke kru penebang kayu. Papan hasil kru dibagi sesuai persen yang diatur ketua.'):format(leaderName),
        centered = true,
        cancel = true,
        labels = { confirm = 'Terima', cancel = 'Tolak' },
    })
    lib.callback.await('f_lumberjack:server:respond', false, answer == 'confirm')
end)

RegisterNetEvent('f_lumberjack:client:copyPos', function()
    local c, h = GetEntityCoords(cache.ped), GetEntityHeading(cache.ped)
    local feet = c.z - GetEntityHeightAboveGround(cache.ped)
    local text = ('vec4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, feet, h)
    lib.setClipboard(text)
    notify(('Disalin (z kaki): %s'):format(text), 'success')
end)

---------------------------------------------------------------------------
-- menu (NPC Mandor)
---------------------------------------------------------------------------
local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function refreshMenu()
    local data = lib.callback.await('f_lumberjack:server:getMenu', false)
    if not data or data.err then return closeMenu() end
    SendNUIMessage({ action = 'update', data = data })
end

local function openMenu()
    if menuOpen then return end
    local data = lib.callback.await('f_lumberjack:server:getMenu', false)
    if not data then return end
    if data.err then return notify(data.err, 'error') end
    menuOpen = true
    SendNUIMessage({ action = 'open', data = data })
    SetNuiFocus(true, true)
end

RegisterNetEvent('f_lumberjack:client:menuRefresh', function()
    if menuOpen then refreshMenu() end
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb(1)
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(lib.callback.await('f_lumberjack:server:getMenu', false) or {})
end)

RegisterNUICallback('invite', function(data, cb)
    cb(lib.callback.await('f_lumberjack:server:invite', false, data.id) or { ok = false })
end)

RegisterNUICallback('shares', function(data, cb)
    cb(lib.callback.await('f_lumberjack:server:setShares', false, data.shares) or { ok = false })
end)

RegisterNUICallback('start', function(_, cb)
    local res = lib.callback.await('f_lumberjack:server:start', false) or { ok = false }
    if res.ok then closeMenu() end
    cb(res)
end)

RegisterNUICallback('leave', function(_, cb)
    lib.callback.await('f_lumberjack:server:leave', false)
    cb(lib.callback.await('f_lumberjack:server:getMenu', false) or {})
end)

---------------------------------------------------------------------------
-- Gudang Kayu (stok papan pribadi, diambil ke tas)
---------------------------------------------------------------------------
local function openGudang()
    if menuOpen then return end
    local data = lib.callback.await('f_lumberjack:server:gudang', false)
    if not data then return end
    if data.err then return notify(data.err, 'error') end
    menuOpen = true
    SendNUIMessage({ action = 'gudang', data = data })
    SetNuiFocus(true, true)
end

RegisterNUICallback('takeGudang', function(data, cb)
    cb(lib.callback.await('f_lumberjack:server:takeGudang', false, data.amount) or { ok = false })
end)

RegisterNUICallback('confirm', function(data, cb)
    SetNuiFocus(false, false)
    local fn = confirmCb
    confirmCb = nil
    cb(1)
    if data.ok and fn then
        busy = true
        fn()
        busy = false
    end
end)

---------------------------------------------------------------------------
-- NPC Mandor (Paleto) & Bongkar papan
---------------------------------------------------------------------------
local npc

local function spawnNpc()
    local n = sharedConfig.npc
    lib.requestModel(n.model, 5000)
    npc = CreatePed(4, n.model, n.coords.x, n.coords.y, n.coords.z, n.coords.w, false, true)
    SetModelAsNoLongerNeeded(n.model)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    TaskStartScenarioInPlace(npc, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    exports.ox_target:addLocalEntity(npc, {
        {
            name = 'flj_menu', icon = 'fas fa-tree', label = 'Kerja Penebang Kayu', distance = 2.5,
            onSelect = openMenu,
        },
        {
            name = 'flj_chainsaw', icon = 'fas fa-gears', distance = 2.5,
            label = ('Beli Chainsaw (%s)'):format(rupiah(sharedConfig.chainsawPrice)),
            onSelect = function()
                local res = lib.callback.await('f_lumberjack:server:buyChainsaw', false)
                if res and res.ok then notify('Chainsaw dibeli.', 'success')
                elseif res and res.msg then notify(res.msg, 'error') end
            end,
        },
        {
            name = 'flj_gudang', icon = 'fas fa-boxes-stacked', label = 'Gudang Kayu', distance = 2.5,
            onSelect = openGudang,
        },
    })
end

local function deleteNpc()
    if not npc then return end
    exports.ox_target:removeLocalEntity(npc)
    if DoesEntityExist(npc) then DeletePed(npc) end
    npc = nil
end

lib.points.new({
    coords = sharedConfig.npc.coords.xyz,
    distance = 60.0,
    onEnter = spawnNpc,
    onExit = deleteNpc,
})

-- Bongkar papan: truk kru yang membawa papan, di parkir markas Paleto
exports.ox_target:addGlobalVehicle({
    {
        name = 'flj_unload', icon = 'fas fa-boxes-stacked', label = 'Bongkar papan', distance = 3.0,
        canInteract = function(entity)
            local crew = FLJ.crew
            return FLJ.working() and crew.cargo > 0 and entity == FLJ.truck()
                and #(GetEntityCoords(entity) - sharedConfig.depot.coords) < sharedConfig.depot.radius
        end,
        onSelect = function()
            if busy then return end
            busy = true
            local ok = lib.progressBar({
                duration = 3000, label = 'Membongkar papan ke gudang...', canCancel = true,
                disable = { move = true, car = true, combat = true },
                anim = { dict = 'anim@heists@box_carry@', clip = 'idle' },
            })
            if ok then
                local res = lib.callback.await('f_lumberjack:server:unloadPlanks', false)
                if res and not res.ok and res.msg then notify(res.msg, 'error') end
            end
            busy = false
        end,
    },
})

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    hidePrompt()
    deleteNpc()
    restoreOutfit()
    exports.ox_target:removeGlobalVehicle('flj_unload')
    if menuOpen or confirmCb then SetNuiFocus(false, false) end
end)
