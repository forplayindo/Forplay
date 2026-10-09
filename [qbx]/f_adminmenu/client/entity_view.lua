-- Entity View Mode (port konsep dari qb-adminmenu untuk Qbox)
-- Freeaim laser + tampilan info Object / Vehicle / Ped di sekitar

local ENTITY_TYPES = { [1] = 'Ped', [2] = 'Vehicle', [3] = 'Object' }
local POOLS = { objects = 'CObject', vehicles = 'CVehicle', peds = 'CPed' }

local ENTITY_VIEW_DISTANCES = { 5, 10, 15, 20, 25, 30, 35, 40, 45, 50 }

local viewDistance = 20
local freeaimActive = false
local poolActive = { objects = false, vehicles = false, peds = false }
local cachedEntities = { objects = {}, vehicles = {}, peds = {} }
local poolThreadRunning = false

-- ======================================================================
-- Helpers
-- ======================================================================

local function round(value, decimals)
    return qbx.math.round(value, decimals or 2)
end

local function addLongText(text)
    -- AddTextComponentSubstringPlayerName dibatasi 99 karakter per komponen
    for i = 1, #text, 99 do
        AddTextComponentSubstringPlayerName(text:sub(i, i + 98))
    end
end

local function drawText3D(coords, text, scale)
    SetTextScale(0.0, scale or 0.3)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    SetTextCentre(true)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    BeginTextCommandDisplayText('STRING')
    addLongText(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function drawText2D(x, y, text, scale)
    SetTextScale(0.0, scale or 0.35)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    SetTextJustification(1)
    BeginTextCommandDisplayText('STRING')
    addLongText(text)
    EndTextCommandDisplayText(x, y)
end

local function notifyToggle(label, state)
    local key = state and 'dev_options.toggle_on' or 'dev_options.toggle_off'
    exports.qbx_core:Notify(locale(key, label), state and 'success' or 'error')
end

local function getModelName(entity, model)
    if IsModelAVehicle(model) then
        return GetDisplayNameFromVehicleModel(model):lower()
    end

    local name = GetEntityArchetypeName(entity)
    if name and name ~= '' then return name end

    return 'unknown'
end

local function getEntityInfo(entity)
    local model = GetEntityModel(entity)
    local entityType = GetEntityType(entity)
    local isNetworked = NetworkGetEntityIsNetworked(entity)

    local info = {
        handle = entity,
        type = ENTITY_TYPES[entityType] or 'Unknown',
        model = model,
        name = getModelName(entity, model),
        coords = GetEntityCoords(entity),
        heading = GetEntityHeading(entity),
        rotation = GetEntityRotation(entity, 2),
        health = GetEntityHealth(entity),
        maxHealth = GetEntityMaxHealth(entity),
        netId = isNetworked and NetworkGetNetworkIdFromEntity(entity) or nil,
        owner = isNetworked and GetPlayerServerId(NetworkGetEntityOwner(entity)) or nil,
        isMission = IsEntityAMissionEntity(entity),
        isFrozen = IsEntityPositionFrozen(entity),
    }

    if entityType == 2 then
        info.plate = GetVehicleNumberPlateText(entity)
    elseif entityType == 1 then
        info.isPlayer = IsPedAPlayer(entity)
    end

    return info
end

local function formatCoords(info)
    local c = info.coords
    return ('vec4(%s, %s, %s, %s)'):format(round(c.x), round(c.y), round(c.z), round(info.heading))
end

local function formatRotation(info)
    local r = info.rotation
    return ('vec3(%s, %s, %s)'):format(round(r.x), round(r.y), round(r.z))
end

local function copyEntityInfo(info)
    local lines = {
        ('-- %s: %s'):format(info.type, info.name),
        ('model = `%s` -- hash: %s'):format(info.name, info.model),
        ('coords = %s'):format(formatCoords(info)),
        ('rotation = %s'):format(formatRotation(info)),
    }
    if info.netId then lines[#lines + 1] = ('-- netId: %s'):format(info.netId) end
    if info.plate then lines[#lines + 1] = ('-- plate: %s'):format(info.plate) end

    lib.setClipboard(table.concat(lines, '\n'))
    exports.qbx_core:Notify(locale('success.entity_info_copied'), 'success')
end

local function deleteEntity(entity)
    if not DoesEntityExist(entity) then return end

    if IsEntityAPed(entity) and IsPedAPlayer(entity) then
        exports.qbx_core:Notify(locale('error.cannot_delete_player'), 'error')
        return
    end

    if NetworkGetEntityIsNetworked(entity) then
        -- Entity networked dihapus dari server agar sinkron ke semua player
        local deleted = lib.callback.await('qbx_admin:server:deleteEntity', false, NetworkGetNetworkIdFromEntity(entity))
        if not deleted then return end
    else
        -- Entity lokal / prop map: hanya terhapus di client ini
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
    end

    exports.qbx_core:Notify(locale('success.entity_deleted'), 'success')
end

-- ======================================================================
-- Freeaim (laser)
-- ======================================================================

local function drawFreeaimPanel(info)
    local lines = {
        ('~o~Type: ~w~%s  ~o~Handle: ~w~%s'):format(info.type, info.handle),
        ('~o~Model: ~w~%s'):format(info.name),
        ('~o~Hash: ~w~%s'):format(info.model),
        ('~o~Coords: ~w~%s'):format(formatCoords(info)),
        ('~o~Rotation: ~w~%s'):format(formatRotation(info)),
        ('~o~Health: ~w~%s / %s'):format(info.health, info.maxHealth),
        ('~o~Net ID: ~w~%s  ~o~Owner: ~w~%s'):format(info.netId or 'local', info.owner or '-'),
        ('~o~Mission: ~w~%s  ~o~Frozen: ~w~%s'):format(info.isMission, info.isFrozen),
    }
    if info.plate then lines[#lines + 1] = ('~o~Plate: ~w~%s'):format(info.plate) end
    if info.isPlayer ~= nil then lines[#lines + 1] = ('~o~Is Player: ~w~%s'):format(info.isPlayer) end

    local y = 0.30
    for i = 1, #lines do
        drawText2D(0.015, y, lines[i], 0.35)
        y = y + 0.022
    end
    drawText2D(0.015, y + 0.01, locale('dev_options.freeaim_help'), 0.33)
end

local function startFreeaim()
    CreateThread(function()
        while freeaimActive do
            local hit, entity, endCoords = lib.raycast.fromCamera(511, 4, 1000.0)
            local origin = GetEntityCoords(cache.ped)
            local hasEntity = hit and entity and entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) ~= 0

            if hit then
                local r, g = hasEntity and 0 or 255, hasEntity and 255 or 0
                DrawLine(origin.x, origin.y, origin.z, endCoords.x, endCoords.y, endCoords.z, r, g, 0, 255)
                DrawMarker(28, endCoords.x, endCoords.y, endCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.05, 0.05, r, g, 0, 200, false, false, 2, false, nil, nil, false)
            end

            if hasEntity then
                local info = getEntityInfo(entity)
                drawFreeaimPanel(info)

                if IsDisabledControlJustPressed(0, 38) then -- E
                    copyEntityInfo(info)
                elseif IsDisabledControlJustPressed(0, 47) then -- G
                    deleteEntity(entity)
                end
            end

            Wait(0)
        end
    end)
end

function ToggleEntityFreeaim()
    freeaimActive = not freeaimActive
    notifyToggle(locale('dev_options.label7'), freeaimActive)
    if freeaimActive then startFreeaim() end
end

-- ======================================================================
-- Nearby Objects / Vehicles / Peds
-- ======================================================================

local function anyPoolActive()
    return poolActive.objects or poolActive.vehicles or poolActive.peds
end

local function refreshPools()
    local camCoords = GetFinalRenderedCamCoord()
    for key, pool in pairs(POOLS) do
        local list = {}
        if poolActive[key] then
            local all = GetGamePool(pool)
            for i = 1, #all do
                local entity = all[i]
                if entity ~= cache.ped and #(GetEntityCoords(entity) - camCoords) <= viewDistance then
                    list[#list + 1] = entity
                end
            end
        end
        cachedEntities[key] = list
    end
end

local function drawPoolEntity(entity)
    if not DoesEntityExist(entity) then return end

    local model = GetEntityModel(entity)
    local coords = GetEntityCoords(entity)
    local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or 'local'
    local text = ('~o~%s ~w~#%s~n~%s~n~~o~Hash: ~w~%s | ~o~Net: ~w~%s'):format(
        ENTITY_TYPES[GetEntityType(entity)] or '?', entity, getModelName(entity, model), model, netId)

    drawText3D(vec3(coords.x, coords.y, coords.z + 1.0), text, 0.28)
end

local function startPoolThreads()
    if poolThreadRunning then return end
    poolThreadRunning = true

    -- Refresh daftar entity tiap 500ms supaya tidak berat
    CreateThread(function()
        while anyPoolActive() do
            refreshPools()
            Wait(500)
        end
    end)

    -- Gambar teks tiap frame
    CreateThread(function()
        while anyPoolActive() do
            for _, list in pairs(cachedEntities) do
                for i = 1, #list do
                    drawPoolEntity(list[i])
                end
            end
            Wait(0)
        end
        cachedEntities = { objects = {}, vehicles = {}, peds = {} }
        poolThreadRunning = false
    end)
end

function ToggleEntityPoolView(key, label)
    poolActive[key] = not poolActive[key]
    notifyToggle(label, poolActive[key])
    if poolActive[key] then startPoolThreads() end
end

function SetEntityViewDistance(index)
    local distance = ENTITY_VIEW_DISTANCES[index]
    if not distance then return end
    viewDistance = distance
end
