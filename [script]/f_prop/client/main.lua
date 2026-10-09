local props = {}   -- [id] = data dari server
local points = {}  -- [id] = lib.points
local spawned = {} -- [id] = entity
local placing = false

---------------------------------------------------------------------
-- Streaming: prop hanya dibuat saat player dalam Config.StreamDistance
---------------------------------------------------------------------

local function despawn(id)
    local ent = spawned[id]
    if ent then
        if DoesEntityExist(ent) then DeleteEntity(ent) end
        spawned[id] = nil
    end
end

local function onEnter(self)
    local p = self.prop
    CreateThread(function()
        local hash = joaat(p.model)
        if not IsModelInCdimage(hash) then return end
        if not pcall(lib.requestModel, hash, 10000) then return end

        -- player keburu keluar area / prop keburu dihapus saat model loading
        if not self.inside or points[p.id] ~= self or spawned[p.id] then
            SetModelAsNoLongerNeeded(hash)
            return
        end

        local ent = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
        SetEntityRotation(ent, p.rx, p.ry, p.rz, 2, false)
        FreezeEntityPosition(ent, true)
        SetModelAsNoLongerNeeded(hash)
        spawned[p.id] = ent
    end)
end

local function onExit(self)
    despawn(self.prop.id)
end

local function addProp(p)
    if points[p.id] then return end
    props[p.id] = p
    points[p.id] = lib.points.new({
        coords = vec3(p.x, p.y, p.z),
        distance = Config.StreamDistance,
        prop = p,
        onEnter = onEnter,
        onExit = onExit,
    })
end

local function removeProp(id)
    if points[id] then
        points[id]:remove()
        points[id] = nil
    end
    despawn(id)
    props[id] = nil
end

CreateThread(function()
    local all = lib.callback.await('f_prop:getAll', false) or {}
    for _, p in pairs(all) do addProp(p) end
end)

RegisterNetEvent('f_prop:add', function(p)
    if GetInvokingResource() then return end
    addProp(p)
end)

RegisterNetEvent('f_prop:remove', function(id)
    if GetInvokingResource() then return end
    removeProp(id)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(spawned) do despawn(id) end
end)

---------------------------------------------------------------------
-- Mode penempatan
---------------------------------------------------------------------

local function camRaycast(dist)
    local camCoords = GetFinalRenderedCamCoord()
    local rot = GetFinalRenderedCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local cx = math.abs(math.cos(rx))
    local dest = camCoords + vec3(-math.sin(rz) * cx, math.cos(rz) * cx, math.sin(rx)) * dist
    -- 1|16 = world + object, ignore 4 = entity tanpa collision (prop ghost)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(camCoords.x, camCoords.y, camCoords.z,
        dest.x, dest.y, dest.z, 17, cache.ped, 4)
    local _, hit, endCoords = GetShapeTestResult(handle)
    return hit == 1, endCoords
end

local disabledControls = { 14, 15, 16, 17, 24, 25, 37, 44, 140, 141, 142, 257, 263, 264 }

local function startPlacement(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then
        return lib.notify({ type = 'error', description = ('Model "%s" tidak ditemukan'):format(model) })
    end
    if not pcall(lib.requestModel, hash, 10000) then
        return lib.notify({ type = 'error', description = 'Gagal load model' })
    end

    placing = true
    local pos = GetEntityCoords(cache.ped)
    local ghost = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAlpha(ghost, 170, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)

    local heading = GetEntityHeading(cache.ped)
    local offsetZ = 0.0

    lib.showTextUI(('**%s**  \n[Scroll] Putar (SHIFT = halus)  \n[PgUp/PgDn] Naik/Turun  \n[G] Reset tinggi  \n[E] Simpan  \n[Backspace] Batal'):format(model))

    local confirmed = false
    while placing do
        for i = 1, #disabledControls do DisableControlAction(0, disabledControls[i], true) end

        local hit, coords = camRaycast(Config.PlaceDistance)
        if hit then
            SetEntityCoordsNoOffset(ghost, coords.x, coords.y, coords.z + offsetZ, false, false, false)
        end

        local step = IsControlPressed(0, 21) and Config.RotateStepFine or Config.RotateStep
        if IsDisabledControlJustPressed(0, 15) then heading += step end
        if IsDisabledControlJustPressed(0, 14) then heading -= step end
        heading = heading % 360.0
        SetEntityRotation(ghost, 0.0, 0.0, heading, 2, false)

        if IsControlPressed(0, 10) then offsetZ += Config.HeightStep end
        if IsControlPressed(0, 11) then offsetZ -= Config.HeightStep end
        if IsControlJustPressed(0, 47) then offsetZ = 0.0 end

        if IsControlJustPressed(0, 38) and hit then
            confirmed = true
            placing = false
        elseif IsControlJustPressed(0, 177) then
            placing = false
        end

        Wait(0)
    end

    lib.hideTextUI()
    local final = GetEntityCoords(ghost)
    local rot = GetEntityRotation(ghost, 2)
    DeleteEntity(ghost)

    if not confirmed then
        return lib.notify({ type = 'info', description = 'Penempatan dibatalkan' })
    end

    local ok, err = lib.callback.await('f_prop:save', false, {
        model = model,
        x = final.x, y = final.y, z = final.z,
        rx = rot.x, ry = rot.y, rz = rot.z,
    })
    lib.notify(ok and { type = 'success', description = 'Prop tersimpan' }
        or { type = 'error', description = err or 'Gagal simpan' })
end

local function placeModel(model)
    if placing then return end
    model = model and model:gsub('%s', ''):lower()
    if not model or model == '' or not model:match('^[%w_]+$') then
        return lib.notify({ type = 'error', description = 'Nama model tidak valid' })
    end
    CreateThread(function() startPlacement(model) end)
end

---------------------------------------------------------------------
-- Daftar prop tersimpan (urut dari yang terdekat)
---------------------------------------------------------------------

local function openList()
    local pos = GetEntityCoords(cache.ped)
    local list = {}
    for _, p in pairs(props) do
        list[#list + 1] = { p = p, dist = #(pos - vec3(p.x, p.y, p.z)) }
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)

    local options = {}
    for i = 1, math.min(#list, 100) do
        local p, dist = list[i].p, list[i].dist
        options[i] = {
            title = ('#%d  %s'):format(p.id, p.model),
            description = ('Jarak %.1f m'):format(dist),
            icon = 'cube',
            onSelect = function()
                lib.registerContext({
                    id = 'f_prop_item',
                    title = ('#%d  %s'):format(p.id, p.model),
                    menu = 'f_prop_list',
                    options = {
                        {
                            title = 'Teleport ke prop',
                            icon = 'location-arrow',
                            onSelect = function()
                                SetEntityCoords(cache.ped, p.x, p.y, p.z + 1.0, false, false, false, false)
                            end,
                        },
                        {
                            title = 'Hapus prop',
                            icon = 'trash',
                            iconColor = 'red',
                            onSelect = function()
                                local confirm = lib.alertDialog({
                                    header = 'Hapus prop?',
                                    content = ('#%d %s akan dihapus permanen.'):format(p.id, p.model),
                                    centered = true,
                                    cancel = true,
                                })
                                if confirm ~= 'confirm' then return end
                                local ok, err = lib.callback.await('f_prop:delete', false, p.id)
                                lib.notify(ok and { type = 'success', description = 'Prop dihapus' }
                                    or { type = 'error', description = err or 'Gagal hapus' })
                            end,
                        },
                    },
                })
                lib.showContext('f_prop_item')
            end,
        }
    end

    if #options == 0 then
        options[1] = { title = 'Belum ada prop tersimpan', disabled = true }
    end

    lib.registerContext({
        id = 'f_prop_list',
        title = ('Prop Tersimpan (%d)'):format(#list),
        options = options,
    })
    lib.showContext('f_prop_list')
end

---------------------------------------------------------------------
-- Menu /prop
---------------------------------------------------------------------

local categoryMenus -- dibuat sekali saat menu pertama kali dibuka

local function buildCategoryMenus()
    categoryMenus = {}
    for i, cat in ipairs(PropCategories) do
        local options = {}
        for _, item in ipairs(cat.props) do
            -- model yang tidak ada di game tidak ditampilkan
            if IsModelInCdimage(joaat(item.model)) then
                options[#options + 1] = {
                    title = item.label,
                    description = item.model,
                    icon = 'cube',
                    onSelect = function() placeModel(item.model) end,
                }
            end
        end

        if #options > 0 then
            local id = 'f_prop_cat_' .. i
            lib.registerContext({ id = id, title = cat.label, menu = 'f_prop_menu', options = options })
            categoryMenus[#categoryMenus + 1] = { id = id, label = cat.label, icon = cat.icon, count = #options }
        end
    end
end

local function openPropMenu()
    if not categoryMenus then buildCategoryMenus() end

    local options = {
        {
            title = 'Ketik nama prop',
            description = 'Untuk prop yang tidak ada di daftar',
            icon = 'keyboard',
            onSelect = function()
                local input = lib.inputDialog('Nama Prop', {
                    { type = 'input', label = 'Nama model', placeholder = 'contoh: prop_bench_01a', required = true },
                })
                if input then placeModel(input[1]) end
            end,
        },
        {
            title = 'Prop tersimpan',
            description = 'Lihat, teleport & hapus prop',
            icon = 'list',
            onSelect = openList,
        },
    }

    for _, cat in ipairs(categoryMenus) do
        options[#options + 1] = {
            title = cat.label,
            description = ('%d prop'):format(cat.count),
            icon = cat.icon or 'folder',
            menu = cat.id,
            arrow = true,
        }
    end

    lib.registerContext({ id = 'f_prop_menu', title = 'Pasang Prop', options = options })
    lib.showContext('f_prop_menu')
end

RegisterCommand('prop', function(_, args)
    if placing then return end
    if not lib.callback.await('f_prop:canUse', false) then
        return lib.notify({ type = 'error', description = 'Tidak punya izin' })
    end
    if args[1] then
        placeModel(args[1])
    else
        openPropMenu()
    end
end, false)

RegisterCommand('proplist', function()
    if not lib.callback.await('f_prop:canUse', false) then
        return lib.notify({ type = 'error', description = 'Tidak punya izin' })
    end
    openList()
end, false)

TriggerEvent('chat:addSuggestion', '/prop', 'Buka menu prop (atau langsung: /prop nama_model)', { { name = 'model', help = 'Opsional: nama model prop' } })
TriggerEvent('chat:addSuggestion', '/proplist', 'Daftar & hapus prop tersimpan')
