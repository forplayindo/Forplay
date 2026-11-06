---@alias Direction 'right' | 'left' | 'front' | 'back' | nil

local config = lib.loadJson('f_vehiclepush.config')
local dict = 'missfinale_c2ig_11'
local clip = 'pushcar_offcliff_m'

-- tombol saat mendorong: W dorong, A/D belok, X berhenti
local KEY_PUSH, KEY_LEFT, KEY_RIGHT, KEY_STOP = 32, 34, 35, 73
local BLOCKED = { 21, 22, 23, 24, 25, 30, 31, 33, 36, 44, 140, 141, 142, 257, 263 }

---@type Direction
local pushingControl = nil
local pushing = false

---@param vehicle number
---@return boolean
local function checkClass(vehicle)
    local classes = config.blacklistedClasses
    local currentClass = GetVehicleClass(vehicle)

    for i = 1, #classes do
        if currentClass == classes[i] then
            return false
        end
    end

    return true
end

---@param vehicle number
---@param value Direction
local function vehicleControl(vehicle, value)
    if not pushingControl then -- initial loop for new owner
        local oldDirection = value -- save old front | back direction for new owner

        CreateThread(function()
            local ped = cache.ped
            local playerId = cache.playerId

            pushingControl = value

            while DoesEntityExist(vehicle) and pushingControl and NetworkGetEntityOwner(vehicle) == playerId do
                Wait(0)
                if pushingControl == 'left' then
                    TaskVehicleTempAction(ped, vehicle, 11, 1)
                elseif pushingControl == 'right' then
                    TaskVehicleTempAction(ped, vehicle, 10, 1)
                end

                SetVehicleForwardSpeed(vehicle, value == 'front' and -1.0 or 1.0)

                if HasEntityCollidedWithAnything(vehicle) then
                    SetVehicleOnGroundProperly(vehicle)
                end
            end

            if DoesEntityExist(vehicle) and NetworkGetEntityOwner(vehicle) ~= playerId and pushingControl then -- handle changing owner in the middle of pushing
                TriggerServerEvent('f_vehiclepush:server:push', {
                    direction = oldDirection,
                    netId = VehToNet(vehicle)
                })
            end
        end)
    end

    pushingControl = value
end

---@param vehicle number
local function isVehicleValid(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)

    return ((engineHealth >= 0 and engineHealth <= config.damageNeeded) or (Entity(vehicle).state.fuel or 100) < 3) and IsVehicleSeatFree(vehicle, -1) and checkClass(vehicle)
end

---@param vehicle number
---@param direction Direction
local function taskControlVehicle(vehicle, direction)
    if NetworkGetEntityOwner(vehicle) == cache.playerId then
        vehicleControl(vehicle, direction)
    else
        TriggerServerEvent('f_vehiclepush:server:push', {
            direction = direction,
            netId = VehToNet(vehicle)
        })
    end
end

---@param vehicle number
local function startPushing(vehicle)
    if pushing or cache.vehicle then return end
    if not isVehicleValid(vehicle) then
        return exports.qbx_core:Notify(locale('error.cannot_push'), 'error')
    end

    local ped = cache.ped
    pushing = true

    local pedCoords = GetEntityCoords(ped)
    local vehicleCoords = GetEntityCoords(vehicle)
    local boneIndex = GetPedBoneIndex(ped, 6286)
    local dimensions = GetModelDimensions(GetEntityModel(vehicle))
    local vehicleForwardVector = GetEntityForwardVector(vehicle)
    local isInFront = #(vehicleCoords - pedCoords + vehicleForwardVector) < #(vehicleCoords - pedCoords - vehicleForwardVector)

    if isInFront then
        AttachEntityToEntity(ped, vehicle, boneIndex, 0.0, dimensions.y * -1 + 0.1, dimensions.z + 1.0, 0.0, 0.0, 180.0,
            false, false, false, true, 0, true)
    else
        AttachEntityToEntity(ped, vehicle, boneIndex, 0.0, dimensions.y - 0.3, dimensions.z + 1.0, 0.0, 0.0, 0.0, false,
            false, false, true, 0, true)
    end

    lib.playAnim(ped, dict, clip, 2.0, -8.0, -1, 35, 0, false, false, false)
    lib.showTextUI(locale('actions.push_vehicle'))

    local direction = isInFront and 'front' or 'back'

    CreateThread(function()
        ---@type Direction
        local current = nil
        local nextCheck = 0

        while pushing and not cache.vehicle and DoesEntityExist(vehicle) do
            for i = 1, #BLOCKED do
                DisableControlAction(0, BLOCKED[i], true)
            end
            DisableControlAction(0, KEY_PUSH, true)
            DisableControlAction(0, KEY_LEFT, true)
            DisableControlAction(0, KEY_RIGHT, true)

            ---@type Direction
            local wanted = nil
            if IsDisabledControlPressed(0, KEY_PUSH) then
                if IsDisabledControlPressed(0, KEY_LEFT) then
                    wanted = 'left'
                elseif IsDisabledControlPressed(0, KEY_RIGHT) then
                    wanted = 'right'
                else
                    wanted = direction
                end
            end

            if wanted ~= current then
                -- dari diam selalu mulai dengan arah dorong, karena loop pemilik memakai nilai pertama untuk arah laju
                if not current and wanted ~= direction then
                    taskControlVehicle(vehicle, direction)
                end
                current = wanted
                taskControlVehicle(vehicle, wanted)
            end

            if IsDisabledControlJustPressed(0, KEY_STOP) or IsControlJustPressed(0, KEY_STOP) then
                pushing = false
            end

            local now = GetGameTimer()
            if now > nextCheck then
                nextCheck = now + 500
                if not isVehicleValid(vehicle) then pushing = false end
            end

            Wait(0)
        end

        if current and DoesEntityExist(vehicle) then
            taskControlVehicle(vehicle)
        end

        DetachEntity(ped, false, false)
        StopAnimTask(ped, dict, clip, 2.0)
        FreezeEntityPosition(ped, false)
        lib.hideTextUI()

        pushingControl = nil
        pushing = false
    end)
end

AddStateBagChangeHandler('pushVehicle', nil, function(bagName, _, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end

    if NetworkGetEntityOwner(entity) ~= cache.playerId then return end

    if not value then
        pushingControl = nil
        return
    end

    vehicleControl(entity, value)
end)

exports.ox_target:addGlobalVehicle({
    {
        name = 'f_vehiclepush:push',
        icon = 'fa-solid fa-hands',
        label = locale('target.push_vehicle'),
        distance = 2.5,
        canInteract = function(entity)
            return not pushing and not cache.vehicle and not IsEntityAttachedToEntity(cache.ped, entity) and isVehicleValid(entity)
        end,
        onSelect = function(data)
            startPushing(data.entity)
        end,
    },
})
