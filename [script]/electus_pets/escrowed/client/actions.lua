--[[
 ______     __         ______     ______     __   __     ______     _____        ______     __  __        __  __     ______     __   __   __     __   __    
/\  ___\   /\ \       /\  ___\   /\  __ \   /\ "-.\ \   /\  ___\   /\  __-.     /\  == \   /\ \_\ \      /\ \/ /    /\  ___\   /\ \ / /  /\ \   /\ "-.\ \   
\ \ \____  \ \ \____  \ \  __\   \ \  __ \  \ \ \-.  \  \ \  __\   \ \ \/\ \    \ \  __<   \ \____ \     \ \  _"-.  \ \  __\   \ \ \'/   \ \ \  \ \ \-.  \  
 \ \_____\  \ \_____\  \ \_____\  \ \_\ \_\  \ \_\\"\_\  \ \_____\  \ \____-     \ \_____\  \/\_____\     \ \_\ \_\  \ \_____\  \ \__|    \ \_\  \ \_\\"\_\ 
  \/_____/   \/_____/   \/_____/   \/_/\/_/   \/_/ \/_/   \/_____/   \/____/      \/_____/   \/_____/      \/_/\/_/   \/_____/   \/_/      \/_/   \/_/ \/_/ 
 ______   __     __  __     ______     _____        ______     __  __        __  __     ______     ______     __     __    __        __  __     ______     ______     ______     ______     ______     ______    
/\  ___\ /\ \   /\_\_\_\   /\  ___\   /\  __-.     /\  == \   /\ \_\ \      /\ \_\ \   /\  __ \   /\___  \   /\ \   /\ "-./  \      /\ \_\ \   /\  ___\   /\  == \   /\  == \   /\  ___\   /\  == \   /\  __ \   
\ \  __\ \ \ \  \/_/\_\/_  \ \  __\   \ \ \/\ \    \ \  __<   \ \____ \     \ \  __ \  \ \  __ \  \/_/  /__  \ \ \  \ \ \-./\ \     \ \  __ \  \ \  __\   \ \  __<   \ \  __<   \ \  __\   \ \  __<   \ \  __ \  
 \ \_\    \ \_\   /\_\/\_\  \ \_____\  \ \____-     \ \_____\  \/\_____\     \ \_\ \_\  \ \_\ \_\   /\_____\  \ \_\  \ \_\ \ \_\     \ \_\ \_\  \ \_____\  \ \_\ \_\  \ \_\ \_\  \ \_____\  \ \_\ \_\  \ \_\ \_\ 
  \/_/     \/_/   \/_/\/_/   \/_____/   \/____/      \/_____/   \/_____/      \/_/\/_/   \/_/\/_/   \/_____/   \/_/   \/_/  \/_/      \/_/\/_/   \/_____/   \/_/ /_/   \/_/ /_/   \/_____/   \/_/ /_/   \/_/\/_/ 
                                                                                                                                                                    
]]

local seatData = {}
seatData[1] = { bone = "seat_pside_f", index = 1, occupied = false }
seatData[2] = { bone = "seat_dside_r", index = 2, occupied = false }
seatData[3] = { bone = "seat_pside_r", index = 3, occupied = false }

function ReleasePetVehicleSeat(pet)
    pet.vehicleGeneration = (pet.vehicleGeneration or 0) + 1
    if pet.targetDoor and seatData[pet.targetDoor] then seatData[pet.targetDoor].occupied = false end
    pet.targetDoor, pet.subAction, pet.currentVehicle, pet.exitingVehicle, pet.approachVehicle = nil, nil, nil, nil, nil
end

local function checkUniqueAction(petData, actionToCheck)
    local action = petData.action
    if action and action == actionToCheck then
        return
    end
    AddXP(petData, Config.RewardsXP.uniqueActions)
end

AddEventHandler("entityDamaged", function(entity1, entity2, damage)
    local playerPed = PlayerPedId()
    if playerPed == entity1 and playerPed ~= entity2 then
        for i = 1, #CurrentPets do
            local pet = CurrentPets[i]
            if pet.abilities.autoAttack and pet.status.autoAttack then
                AttackPed(pet, entity2)
            end
        end
    end
end)

local function resumeAfterVehicleExit(pet)
    ReleasePetVehicleSeat(pet)
    if pet.action == 'follow' and DoesEntityExist(pet.petId) then
        TaskFollowToOffsetOfEntity(pet.petId, PlayerPedId(), -0.5, -0.5, 0.0, 3.0, -1, 1.0, true)
    end
end

local function petEnterVehicle(petData, vehicle)
    local doorIndex = petData.targetDoor
    local vehicleConfig = Config.PetsAllowedInVehicle[petData.model]
    if not vehicleConfig or petData.exitingVehicle or not seatData[doorIndex]
        or not DoesEntityExist(petData.petId) or not DoesEntityExist(vehicle) then return end

    petData.currentVehicle = vehicle
    local generation = (petData.vehicleGeneration or 0) + 1
    petData.vehicleGeneration = generation
    local function current()
        return petData.vehicleGeneration == generation and petData.currentVehicle == vehicle
            and not petData.exitingVehicle and DoesEntityExist(petData.petId) and DoesEntityExist(vehicle)
    end
    local animDict = "creatures@rottweiler@in_vehicle@std_car"
    if vehicleConfig ~= 'teleport' then
        local loaded = pcall(lib.requestAnimDict, animDict, 3000)
        if not current() then return end
        if not loaded then
            ReleasePetVehicleSeat(petData)
            petData.action = 'idle'
            Notify(L('vehicleActionFailed'))
            return
        end
    end
    SetVehicleDoorOpen(vehicle, doorIndex, false, false)
    local boneIndex = GetEntityBoneIndexByName(vehicle, seatData[doorIndex].bone)
    local seatOffset = doorIndex == 2 and 180.0 or 0.0
    local seatRotation = doorIndex == 2 and 300 or 1000

    if vehicleConfig == 'teleport' then
        AttachEntityToEntity(petData.petId, vehicle, boneIndex, 0.0, 0.0, 0.35, 0.0, 0.0, 0.0, false, false, false, true, 2, true)
        AnimHandler(petData, 'layingDown')
        if current() then SetVehicleDoorShut(vehicle, doorIndex, false) end
        return
    end

    SetEntityCollision(petData.petId, false, true)
    local syncScene = NetworkCreateSynchronisedScene(0.0, 0.0, 0.0, 0.0, 0.0, seatOffset, 2, false, false, 1.0, 0.0, 1.0)
    NetworkAttachSynchronisedSceneToEntity(syncScene, vehicle, boneIndex)
    NetworkAddPedToSynchronisedScene(petData.petId, syncScene, animDict, 'get_in', 1.5, -4.0, 0, 0, 1000.0, 0)
    NetworkStartSynchronisedScene(syncScene)
    Wait(GetAnimDuration(animDict, 'get_in') * seatRotation)
    if not current() then return end
    AttachEntityToEntity(petData.petId, vehicle, boneIndex, 0.0, 0.0, 0.35, 0.0, 0.0, 0.0, false, false, false, true, 2, true)
    AnimHandler(petData, 'sit')
    if current() then SetVehicleDoorShut(vehicle, doorIndex, false) end
end

local function petExitVehicle(petData, vehicle)
    if petData.exitingVehicle then return end
    if not DoesEntityExist(petData.petId) then ReleasePetVehicleSeat(petData); return end
    petData.exitingVehicle = true
    local doorIndex = petData.targetDoor
    local generation = (petData.vehicleGeneration or 0) + 1
    petData.vehicleGeneration = generation
    local function current()
        return petData.vehicleGeneration == generation and petData.currentVehicle == vehicle and DoesEntityExist(petData.petId)
    end
    AnimHandler(petData)
    DetachEntity(petData.petId, true, true)
    SetEntityCollision(petData.petId, true, true)
    if not current() then return end

    if not DoesEntityExist(vehicle) or not seatData[doorIndex] then
        local coords = GetEntityCoords(PlayerPedId())
        SetEntityCoords(petData.petId, coords.x, coords.y, coords.z)
        resumeAfterVehicleExit(petData)
        return
    end

    local animDict = 'creatures@rottweiler@in_vehicle@std_car'
    local vehicleConfig = Config.PetsAllowedInVehicle[petData.model]
    local loaded = vehicleConfig == 'teleport' or pcall(lib.requestAnimDict, animDict, 3000)
    if not current() then return end
    if not DoesEntityExist(vehicle) then
        local coords = GetEntityCoords(PlayerPedId())
        SetEntityCoords(petData.petId, coords.x, coords.y, coords.z)
        resumeAfterVehicleExit(petData)
        return
    end
    if vehicleConfig == 'teleport' or not loaded then
        local doorPosition = GetEntryPositionOfDoor(vehicle, doorIndex)
        SetEntityCoords(petData.petId, doorPosition.x, doorPosition.y, doorPosition.z)
        SetVehicleDoorShut(vehicle, doorIndex, false)
        resumeAfterVehicleExit(petData)
        if not loaded then Notify(L('vehicleActionFailed')) end
        return
    end

    local boneIndex = GetEntityBoneIndexByName(vehicle, seatData[doorIndex].bone)
    local seatOffset = doorIndex == 2 and 180.0 or 0.0
    SetVehicleDoorOpen(vehicle, doorIndex, false, false)
    local syncScene = NetworkCreateSynchronisedScene(0.0, 0.0, 0.0, 0.0, 0.0, seatOffset, 2, false, false, 1.0, 0.0, 1.0)
    NetworkAttachSynchronisedSceneToEntity(syncScene, vehicle, boneIndex)
    NetworkAddPedToSynchronisedScene(petData.petId, syncScene, animDict, 'get_out', 1.5, -4.0, 0, 0, 1000.0, 0)
    NetworkStartSynchronisedScene(syncScene)
    Wait((GetAnimDuration(animDict, 'get_out') * 1000) + 1000)
    if not current() then return end
    if DoesEntityExist(vehicle) then SetVehicleDoorShut(vehicle, doorIndex, false) end
    resumeAfterVehicleExit(petData)
end

local function getEmptyPetSeat()
    for i = 1, #seatData do
        if not seatData[i].occupied then
            return i
        end
    end
    return nil
end

local function handlePetVehicleOnGoto(petData, vehicle, action)
    vehicle = vehicle or GetVehiclePedIsIn(PlayerPedId(), false)
    if petData.currentVehicle then
        if vehicle ~= petData.currentVehicle or not DoesEntityExist(petData.currentVehicle) then
            petExitVehicle(petData, petData.currentVehicle)
        end
        return
    end
    if vehicle == 0 or not DoesEntityExist(vehicle) or not Config.PetsAllowedInVehicle[petData.model] then return end
    if not petData.targetDoor then
        local seat = getEmptyPetSeat()
        if not seat then return end
        petData.targetDoor = seat
        seatData[seat].occupied = true
    end
    local door = GetEntryPositionOfDoor(vehicle, petData.targetDoor)
    if #(GetEntityCoords(petData.petId) - door) > 2.0 then
        if petData.subAction ~= 'walking' or petData.approachVehicle ~= vehicle then
            local offset = GetOffsetFromEntityGivenWorldCoords(vehicle, door.x, door.y, door.z)
            petData.subAction, petData.approachVehicle = 'walking', vehicle
            TaskFollowToOffsetOfEntity(petData.petId, vehicle, offset.x, offset.y, offset.z, 3.0, -1, 1.0, true)
        end
    elseif petData.action == action and not petData.exitingVehicle then
        -- This pet owns the reserved seat; occupied=true must not block its entry.
        petEnterVehicle(petData, vehicle)
        if action == 'goto' and petData.currentVehicle then petData.action = 'idle' end
    end
end

local function follow(petData)
    if not petData or not DoesEntityExist(petData.petId) or petData.action == 'riding' then return false end
    NormalizePetStatus(petData)
    if petData.action == 'follow' and petData.followThreadGeneration and petData.followThreadGeneration == petData.followGeneration then return true end
    if not petData.currentVehicle then AnimHandler(petData) end
    local generation = (petData.followGeneration or 0) + 1
    petData.followGeneration, petData.followThreadGeneration = generation, generation
    local function following()
        return petData.followGeneration == generation and petData.action == 'follow' and DoesEntityExist(petData.petId)
    end
    checkUniqueAction(petData, 'follow')
    petData.action = 'follow'
    if not petData.currentVehicle then
        TaskFollowToOffsetOfEntity(petData.petId, PlayerPedId(), -0.5, -0.5, 0.0, 3.0, -1, 1.0, true)
        SetPedKeepTask(petData.petId, true)
    end
    CreateThread(function()
        while following() do
            Wait(0)
            if not following() then break end
            handlePetVehicleOnGoto(petData, nil, 'follow')
        end
        if petData.followThreadGeneration == generation then petData.followThreadGeneration = nil end
    end)
    CreateThread(function()
        while following() do
            local obedience = math.max(0, math.min(5, tonumber(petData.skills.obedience) or 0))
            if obedience >= 5 then break end
            Wait((5 - obedience) * math.random() * 5000)
            if not following() then break end
            if not petData.leash and not petData.currentVehicle and not petData.exitingVehicle and not IsPedInAnyVehicle(PlayerPedId(), false) then
                ClearPedTasks(petData.petId)
                TaskWanderStandard(petData.petId, 10.0, 10)
                Wait((5 - obedience) * math.random() * 2000)
                if not following() then break end
                if not petData.leash and not petData.currentVehicle and not petData.exitingVehicle and not IsPedInAnyVehicle(PlayerPedId(), false) then
                    TaskFollowToOffsetOfEntity(petData.petId, PlayerPedId(), -0.5, -0.5, 0.0, 3.0, -1, 1.0, true)
                    SetPedKeepTask(petData.petId, true)
                end
            end
        end
    end)
    return true
end

local function careForPet(pet, kind)
    if not pet or not DoesEntityExist(pet.petId) then return end
    if pet.pettingSession or pet.currentVehicle or (pet.action and pet.action ~= '' and pet.action ~= 'follow' and pet.action ~= 'idle') then
        Notify(L('fetchBusy')); return
    end
    NormalizePetStatus(pet)
    local feeding = kind == 'feed'
    if pet.status[feeding and 'hunger' or 'thirst'] >= 100 then Notify(L(feeding and 'notHungry' or 'notThirsty')); return end
    if not HasItem(feeding and Config.Items.petFood or Config.Items.petWater) then Notify(L(feeding and 'noFood' or 'noWater')); return end
    local previous = pet.action
    pet.action = kind
    CreateThread(function()
        local bowl
        local ok, err = pcall(function()
            local model = joaat(feeding and 'prop_cs_bowl_01b' or 'ex_mp_h_acc_bowl_ceramic_01')
            lib.requestModel(model, 3000)
            local player = PlayerPedId()
            local coords = GetOffsetFromEntityInWorldCoords(player, 0.0, 0.9, -0.9)
            bowl = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
            SetModelAsNoLongerNeeded(model)
            if not DoesEntityExist(bowl) then error('Could not create care bowl') end
            PlaceObjectOnGroundProperly(bowl)
            TaskPlayAnim(player, LoadDict('pickup_object'), 'pickup_low', 2.7, -2.7, 1000, 48, 0.0, false, false, false)
            TaskGoToEntity(pet.petId, bowl, -1, 0.8, 2.0, 1073741824.0, 0)
            local deadline = GetGameTimer() + 30000
            while pet.action == kind and DoesEntityExist(pet.petId) and DoesEntityExist(bowl) and not IsEntityDead(pet.petId) do
                if #(GetEntityCoords(pet.petId) - GetEntityCoords(bowl)) < 1.2 then
                    AnimHandler(pet, 'pickUp')
                    Wait(2000)
                    if pet.action ~= kind or not DoesEntityExist(pet.petId) or IsEntityDead(pet.petId) then return end
                    local response = lib.callback.await('electus_pets:careForPet', false, pet.name, kind)
                    if type(response) == 'table' and response.success then
                        DailyTaskCheck(pet, kind)
                    else
                        Notify(L(type(response) == 'table' and response.error or 'careFailed'))
                    end
                    return
                end
                if GetGameTimer() >= deadline then Notify(L('careFailed')); return end
                Wait(0)
            end
        end)
        if bowl and DoesEntityExist(bowl) then DeleteEntity(bowl) end
        if pet.action == kind then
            pet.action = previous or ''
            if DoesEntityExist(pet.petId) then
                if previous == 'follow' then Follow(pet) else ClearPedTasks(pet.petId) end
            end
        end
        if not ok then
            print(('electus_pets: pet care failed: %s'):format(err))
            Notify(L('careFailed'))
        end
    end)
end

local function feedPet(pet) careForPet(pet, 'feed') end
local function wetPet(pet) careForPet(pet, 'water') end

local function goTo(petData, targetCoords)
    local closestVehicle, closestVehicleDist = GetClosestVehicleDist(targetCoords)
    checkUniqueAction(petData, "goto")
    AnimHandler(petData)
    petData.action = "goto"

    if closestVehicle ~= 0 and closestVehicleDist < 2.0 and Config.PetsAllowedInVehicle[petData.model] then
        CreateThread(function()
            while true do
                if petData.action ~= "goto" or not DoesEntityExist(petData.petId) then
                    break
                end
                Wait(0)
                if petData.action ~= 'goto' or not DoesEntityExist(petData.petId) then break end
                handlePetVehicleOnGoto(petData, closestVehicle, "goto")
            end
        end)
    else
        if petData.currentVehicle then
            petExitVehicle(petData, petData.currentVehicle)
        end
        TaskGoToCoordAnyMeans(petData.petId, targetCoords.x, targetCoords.y, targetCoords.z, 3.0, 0, false, 786603, 0.0)
        CreateThread(function()
            while DoesEntityExist(petData.petId) do
                local distance = #(GetEntityCoords(petData.petId) - targetCoords)
                if not (distance > 1.0) then
                    break
                end
                if petData.action ~= "goto" then
                    break
                end
                Wait(0)
            end
            if petData.action == "goto" and DoesEntityExist(petData.petId) then
                Wait(500)
                if petData.action == 'goto' and DoesEntityExist(petData.petId) then AnimHandler(petData, 'sit') end
            end
        end)
    end
end

local seatIndexes = {
    wheel_lf = 0,
    wheel_rf = 1,
    wheel_lr = 4,
    wheel_rr = 5
}

local function attackWheel(petData, vehicle, wheelIndex, wheelCoords)
    if not petData.abilities.attackWheels then
        Notify(L("noAbility"))
        return
    end

    petData.action = "attachWheel"
    TaskGoToCoordAnyMeans(petData.petId, wheelCoords.x, wheelCoords.y, wheelCoords.z, 3.0, 0, false, 786603, 0.0)

    CreateThread(function()
        while true do
            if petData.action ~= "attachWheel" then
                break
            end
            Wait(0)

            local petCoords = GetEntityCoords(petData.petId)
            local boneIndex = GetEntityBoneIndexByName(vehicle, wheelIndex)
            local wheelPosition = GetWorldPositionOfEntityBone(vehicle, boneIndex)
            local distanceToWheel = #(wheelPosition - petCoords)

            if distanceToWheel > 0.2 then
                wheelCoords = wheelPosition
                TaskGoToCoordAnyMeans(petData.petId, wheelCoords.x, wheelCoords.y, wheelCoords.z, 3.0, 0, false, 786603, 0.0)
            end

            local distanceToTarget = #(wheelCoords - petCoords)
            if distanceToTarget < 1.0 then
                local vehicleSpeed = GetEntitySpeed(vehicle)
                if vehicleSpeed < 0.1 then
                    local angle = GetHeadingFromVector_2d(wheelCoords.x - petCoords.x, wheelCoords.y - petCoords.y)
                    petData.action = "follow"
                    TaskAchieveHeading(petData.petId, angle, -1)
                    AnimHandler(petData, "attack")
                    SetVehicleTyreBurst(vehicle, seatIndexes[wheelIndex], true)
                    AddXP(petData, Config.RewardsXP.attackWheel)
                    DailyTaskCheck(petData, "attachWheel")
                    Notify(L("successfulAttachWheel"))
                    follow(petData)
                end
            end
        end
    end)
end

local function getClosestWheelDist(vehicle)
    local playerPed = PlayerPedId()
    local closestPedDist, closestPed = GetClosestPedDist(vehicle, false)
    local closestWheelDist, closestWheelIndex, closestWheelCoords, closestWheelBoneDist = GetClosestWheelDist(vehicle)
    return closestWheelDist, closestWheelIndex, closestWheelCoords, closestWheelBoneDist
end

local function attackPed(petData, targetPed)
    if not Config.AllowPlayerAttack then
        if IsPedAPlayer(targetPed) then
            Notify(L("cantAttackPlayer"))
            return
        end
    end

    local randomAction = math.random(1, 5)
    petData.action = "attack"

    local bravery = petData.skills.bravery
    if randomAction <= bravery then
        TaskCombatPed(petData.petId, targetPed, 0, -16)
        CreateThread(function()
            while true do
                if petData.action ~= "attack" then
                    break
                end
                Wait(0)
                if GetEntityHealth(targetPed) == 0 then
                    local wasDamaged = HasEntityBeenDamagedByEntity(targetPed, petData.petId, true)
                    if wasDamaged then
                        petData.action = "follow"
                        AddXP(petData, Config.RewardsXP.successfulAttack)
                        DailyTaskCheck(petData, "attack")
                        Notify(L("successfulAttack"))
                        break
                    end
                end
                local alertness = GetPedAlertness(petData.petId)
                if alertness == 1 then
                    TaskSmartFleePed(petData.petId, targetPed, 20.0, -1, true, true)
                    petData.action = "follow"
                    break
                end
            end
        end)
    else
        Notify(L("youPetGotScared"))
        TaskSmartFleePed(petData.petId, targetPed, 20.0, -1, true, true)
    end
end

local carryingBall = false
local function fetchBall(petData)
    if carryingBall or not petData or petData.pettingSession or petData.currentVehicle
        or (petData.action and petData.action ~= '' and petData.action ~= 'follow' and petData.action ~= 'idle') then
        Notify(L('fetchBusy')); return
    end
    if not (Config.PetAnims[petData.model] or {}).pickUp then Notify(L('fetchUnsupported')); return end
    local player = PlayerPedId()
    if not DoesEntityExist(petData.petId) or IsEntityDead(petData.petId) or IsEntityDead(player)
        or IsPedInAnyVehicle(player, false) or #(GetEntityCoords(player) - GetEntityCoords(petData.petId)) > 10.0 then
        Notify(L('fetchTooFar')); return
    end
    carryingBall = true
    local previousAction = petData.action
    petData.action = 'fetch'
    CreateThread(function()
        local ball, token, completed, started, petNetworkLocked
        local settings = Config.Fetch
        local cancel = Config.Keys[Config.KeyActions.cancelKey]
        local function valid()
            return petData.action == 'fetch' and DoesEntityExist(petData.petId) and not IsEntityDead(petData.petId)
                and not IsEntityDead(player) and not IsPedInAnyVehicle(player, false)
                and not (cancel and IsControlJustReleased(0, cancel.key))
        end
        local ok, err = pcall(function()
            local response = lib.callback.await('electus_pets:startFetch', false, petData.name)
            if type(response) ~= 'table' or not response.token then
                Notify(L(type(response) == 'table' and (response.recovered and 'fetchRecovered' or response.error or 'fetchUnavailable') or 'fetchUnavailable'))
                return
            end
            token, started = response.token, GetGameTimer()
            IsInPetMenu = false
            ToggleNuiFrame(false)
            local deadline = GetGameTimer() + 2000
            while not NetworkHasControlOfEntity(petData.petId) do
                if GetGameTimer() >= deadline or not valid() then return end
                NetworkRequestControlOfEntity(petData.petId)
                Wait(0)
            end
            SetNetworkIdCanMigrate(petData.netId, false)
            petNetworkLocked = true
            local model = joaat(settings.model or 'prop_tennis_ball')
            lib.requestModel(model, 3000)
            lib.requestAnimDict(settings.throwDict, 3000)
            local pickup = Config.PetAnims[petData.model].pickUp
            lib.requestAnimDict(pickup.dict, 3000)
            if GetAnimDuration(settings.throwDict, settings.throwAnim) <= 0 then error('Missing fetch throw animation') end
            if not valid() then return end
            local origin = GetOffsetFromEntityInWorldCoords(player, 0.25, 0.5, 1.0)
            ball = CreateObject(model, origin.x, origin.y, origin.z, true, true, false)
            SetModelAsNoLongerNeeded(model)
            if not DoesEntityExist(ball) then error(('Could not create fetch prop %s'):format(settings.model or 'prop_tennis_ball')) end
            SetEntityAsMissionEntity(ball, true, true)
            SetEntityVisible(ball, true, false)
            ResetEntityAlpha(ball)
            SetEntityLodDist(ball, 300)
            SetEntityLoadCollisionFlag(ball, true, 1)
            SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(ball), false)
            AttachEntityToEntity(ball, player, GetPedBoneIndex(player, 57005), 0.1, 0.0, 0.0,
                0.0, 0.0, 0.0, true, true, false, true, 1, true)
            TaskStandStill(petData.petId, 2500)
            TaskPlayAnim(player, settings.throwDict, settings.throwAnim, 3.0, -3.0, 1200, 48, 0.0, false, false, false)
            Wait(600)
            if not valid() then return end
            DetachEntity(ball, true, true)
            -- Release ahead of the body, even if the throw clip turns the hand inward.
            local release = GetOffsetFromEntityInWorldCoords(player, 0.25, 0.8, 0.6)
            SetEntityCoordsNoOffset(ball, release.x, release.y, release.z, false, false, false)
            SetEntityCollision(ball, true, true)
            SetEntityNoCollisionEntity(ball, player, false)
            SetEntityNoCollisionEntity(ball, petData.petId, false)
            SetEntityHasGravity(ball, true)
            SetEntityDynamic(ball, true)
            ActivatePhysics(ball)
            local forward = GetEntityForwardVector(player)
            SetEntityVelocity(ball, forward.x * 9.0, forward.y * 9.0, 3.5)
            Notify(L('fetchStarted'))
            Wait(2000)
            local deadline = GetGameTimer() + math.min(settings.timeout or 30000, 30000)
            -- An entity target tracks the rolling ball without restarting the run.
            TaskGoToEntity(petData.petId, ball, -1, 1.0, settings.runSpeed or 3.0, 1073741824.0, 0)
            SetPedKeepTask(petData.petId, true)
            while valid() and DoesEntityExist(ball) do
                local target = GetEntityCoords(ball)
                if #(GetEntityCoords(petData.petId) - target) < 1.4 then break end
                if GetGameTimer() >= deadline then return end
                Wait(0)
            end
            if not valid() or not DoesEntityExist(ball) then return end
            local pickupDuration = math.min(4000, math.max(1000, GetAnimDuration(pickup.dict, pickup.anim) * 1000))
            petData.anim = 'pickUp'
            TaskPlayAnim(petData.petId, pickup.dict, pickup.anim, 2.0, -2.0, pickupDuration, 0, 0.0, false, false, false)
            local graspTime = math.floor(pickupDuration * 0.5)
            Wait(graspTime)
            if not valid() or not DoesEntityExist(ball) then return end
            local mouthBone = GetPedBoneIndex(petData.petId, 17188)
            if mouthBone == -1 then mouthBone = GetPedBoneIndex(petData.petId, 31086) end
            AttachEntityToEntity(ball, petData.petId, mouthBone,
                0.12, 0.01, 0.01, 5.0, 150.0, 0.0, true, true, false, true, 1, true)
            SetEntityVisible(ball, true, false)
            Wait(pickupDuration - graspTime + 200)
            if not valid() or not DoesEntityExist(ball) then return end
            petData.anim = nil
            TaskGoToEntity(petData.petId, player, -1, 1.4, settings.returnSpeed or 2.5, 1073741824.0, 0)
            deadline = GetGameTimer() + math.min(settings.timeout or 30000, 30000)
            while valid() and DoesEntityExist(ball) do
                if #(GetEntityCoords(petData.petId) - GetEntityCoords(player)) < 2.0 then
                    completed = true; break
                end
                if GetGameTimer() >= deadline then return end
                Wait(0)
            end
            if completed then
                -- Leave the returned ball visible briefly instead of deleting it mid-stride.
                Wait(650)
                if not valid() or not DoesEntityExist(ball) then completed = false; return end
                while GetGameTimer() - started < 4500 do
                    if not valid() then completed = false; return end
                    Wait(0)
                end
            end
        end)
        if ball and DoesEntityExist(ball) then DeleteEntity(ball) end
        if petNetworkLocked and DoesEntityExist(petData.petId) then SetNetworkIdCanMigrate(petData.netId, true) end
        if petData.anim == 'pickUp' then petData.anim = nil end
        StopAnimTask(player, settings.throwDict, settings.throwAnim, 2.0)
        if token then
            local returned, result = pcall(lib.callback.await, 'electus_pets:finishFetch', false, token, completed == true)
            if not returned or type(result) ~= 'table' then Notify(L('fetchUnavailable'))
            elseif result.error then Notify(L(result.error))
            else
                Notify(L(result.completed and 'fetchReturned' or 'fetchFailed'))
                if result.completed then DailyTaskCheck(petData, 'fetchBall') end
            end
        end
        if petData.action == 'fetch' then
            petData.action = previousAction or ''
            if DoesEntityExist(petData.petId) and NetworkHasControlOfEntity(petData.petId) then
                if previousAction == 'follow' then Follow(petData) else ClearPedTasks(petData.petId) end
            end
        end
        carryingBall = false
        if not ok then print(('electus_pets: fetch failed: %s'):format(err)) end
    end)
end

local function canBeCarried(petData)
    local model = type(petData) == 'table' and petData.model or petData
    return Config.CarryParameters[model] ~= nil
end

local isCarryingPet = false
local function carryPet(petData)
    if not canBeCarried(petData) then return end
    if isCarryingPet then
        return
    end
    isCarryingPet = true
    CarriesPet = true

    local carryAnim = Config.CarryParameters[petData.model].carryAnim
    if carryAnim then
        LoadDict("anim@heists@box_carry@")
        TaskPlayAnim(PlayerPedId(), "anim@heists@box_carry@", "idle", 8.0, -8.0, -1, 49, -1, false, false, false)
    end

    HelpText(L("dropPet", { key = Config.KeyActions.dropPet }))

    CreateThread(function()
        while true do
            if not isCarryingPet or petData.action == 'removed' or not DoesEntityExist(petData.petId) then
                isCarryingPet, CarriesPet = false, false
                HideHelpText()
                break
            end
            Wait(0)
            DisableControlAction(0, 24, true) -- Enter
            DisableControlAction(0, 23, true) -- Forward
            DisableControlAction(0, 25, true) -- Backward

            if not IsEntityPlayingAnim(PlayerPedId(), "anim@heists@box_carry@", "idle", 3) then
                if carryAnim then
                    TaskPlayAnim(PlayerPedId(), "anim@heists@box_carry@", "idle", 8.0, -8.0, -1, 49, -1, false, false, false)
                end
            end

            if IsControlJustReleased(0, Config.Keys[Config.KeyActions.dropPet].key) then
                isCarryingPet = false
                CarriesPet = false
                HideHelpText()
                local playerForwardVector = GetEntityForwardVector(PlayerPedId())
                local petCoords = GetEntityCoords(PlayerPedId())
                local droppedPosition = petCoords + playerForwardVector
                DetachEntity(petData.petId, true, true)
                SetEntityCoords(petData.petId, droppedPosition.x, droppedPosition.y, droppedPosition.z)
                ClearPedTasksImmediately(PlayerPedId())
                AnimHandler(petData)
                ClearPedTasksImmediately(petData.petId)
                follow(petData)
            end
        end
    end)

    if carryAnim then
        AttachEntityToEntity(petData.petId, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 57005), Config.CarryParameters[petData.model].coords.x, Config.CarryParameters[petData.model].coords.y, Config.CarryParameters[petData.model].coords.z, Config.CarryParameters[petData.model].rot.x, Config.CarryParameters[petData.model].rot.y, Config.CarryParameters[petData.model].rot.z, true, true, false, true, 1, true)
    else
        AttachEntityToEntity(petData.petId, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 10706), Config.CarryParameters[petData.model].coords.x, Config.CarryParameters[petData.model].coords.y, Config.CarryParameters[petData.model].coords.z, Config.CarryParameters[petData.model].rot.x, Config.CarryParameters[petData.model].rot.y, Config.CarryParameters[petData.model].rot.z, true, true, false, true, 1, true)
    end
    AnimHandler(petData, "layingDown")
    if false == AnimHandler(petData, "sitAnim") then
        AnimHandler(petData, "sitAnim")
    end
end

local function getCoordsInfrontOfEntityWithDistance(entity, distance, angleOffset)
    local currentCoords = GetEntityCoords(entity)
    local currentHeading = GetEntityHeading(entity) + (angleOffset or 0.0)
    local radHeading = currentHeading * math.pi / 180.0
    local x = currentCoords.x + distance * math.sin(-radHeading)
    local y = currentCoords.y + distance * math.cos(-radHeading)
    local z = currentCoords.z
    return vector3(x, y, z)
end

local function getIndexByPetId(petId)
    for i, pet in ipairs(CurrentPets) do
        if pet.petId == petId then
            return i
        end
    end
    return nil
end

local peePoopOffsets = {
    a_c_rottweiler = { boneIndex = 11816, offset = vector3(0.0, -0.3, -0.1), rot = vector3(-60.0, -60.0, 0.0), scale = 0.75 },
    a_c_deer = { boneIndex = 11816, offset = vector3(0.0, -0.3, -0.1), rot = vector3(0.0, 0.0, 0.0), scale = 2.25 }
}

local peePoopOffsetsFemale = {
    a_c_rottweiler = { boneIndex = 11816, offset = vector3(0.0, -0.3, -0.1), rot = vector3(0.0, 0.0, 0.0), scale = 0.75 },
    a_c_deer = { boneIndex = 11816, offset = vector3(0.0, -0.3, -0.1), rot = vector3(0.0, 0.0, 0.0), scale = 2.25 }
}

local function peeOrPoop(petData, isPoop)
    if IsPedInAnyVehicle(petData.petId) then
        return
    end

    local animDict = "core"
    local animName = "ent_amb_peeing"
    if isPoop then
        animDict = "scr_amb_chop"
        animName = "ent_anim_dog_poo"
    end

    RequestNamedPtfxAsset(animDict)
    while not HasNamedPtfxAssetLoaded(animDict) do
        Wait(0)
        RequestNamedPtfxAsset(animDict)
    end

    SetPtfxAssetNextCall(animDict)
    local boneIndex = GetPedBoneIndex(petData.petId, 11816)
    local offset = vector3(0.0, -0.25, -0.1)
    local rotation = vector3(0.0, 0.0, 0.0)
    local scale = 1.0

    local offsetData = peePoopOffsets[petData.model]
    local rotData = peePoopOffsets[petData.model]
    local scaleData = peePoopOffsets[petData.model].scale
    if isPoop then
        offsetData = peePoopOffsetsFemale[petData.model]
        rotData = peePoopOffsetsFemale[petData.model]
        scaleData = peePoopOffsetsFemale[petData.model].scale
    end

    local particleHandle = StartParticleFxLoopedOnPedBone(animName, petData.petId, offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z, boneIndex, scale, false, false, false)
    Wait(3500)
    StopParticleFxLooped(particleHandle, false)
    ClearPedTasks(petData.petId)
end

RegisterNetEvent("electus_pets:syncPeeOrPoop")
AddEventHandler("electus_pets:syncPeeOrPoop", function(pedNetId, model, isPoop)
    local ped = NetToPed(pedNetId)
    peeOrPoop(ped, model, isPoop)
end)

local function peeOrPoopSynced(petData, model, isPoop)
    local animDict = "core"
    local animName = "ent_amb_peeing"
    if isPoop then
        animDict = "scr_amb_chop"
        animName = "ent_anim_dog_poo"
    end

    RequestNamedPtfxAsset(animDict)
    while not HasNamedPtfxAssetLoaded(animDict) do
        Wait(0)
        RequestNamedPtfxAsset(animDict)
    end

    SetPtfxAssetNextCall(animDict)
    local boneIndex = GetPedBoneIndex(petData, 11816)
    local offset = vector3(0.0, -0.25, -0.1)
    local rotation = vector3(0.0, 0.0, 0.0)
    local scale = 1.0

    local offsetData = peePoopOffsets[model]
    local rotData = peePoopOffsets[model]
    local scaleData = peePoopOffsets[model].scale
    if isPoop then
        offsetData = peePoopOffsetsFemale[model]
        rotData = peePoopOffsetsFemale[model]
        scaleData = peePoopOffsetsFemale[model].scale
    end

    local particleHandle = StartParticleFxLoopedOnPedBone(animName, petData, offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z, boneIndex, scale, false, false, false)
    Wait(3500)
    StopParticleFxLooped(particleHandle, false)
    ClearPedTasks(petData)
end

local function playEmote(request)
    local pet = CurrentPets[PetIndexInSkillMenu]
    if not pet or not DoesEntityExist(pet.petId) or type(request) ~= 'table' then return false end
    if pet.currentVehicle or pet.pettingSession or (pet.action and pet.action ~= '' and pet.action ~= 'idle'
        and pet.action ~= 'follow' and pet.action ~= 'emote') then Notify(L('fetchBusy')); return false end
    local definition
    for _, candidate in ipairs(Config.Emotes[pet.model] or {}) do
        if candidate.dict == request.dict and candidate.anim == request.anim then definition = candidate; break end
    end
    if not definition then return false end
    local previous = pet.action == 'emote' and pet.previousEmoteAction or pet.action
    pet.previousEmoteAction, pet.action = previous, 'emote'
    local generation = (pet.animationGeneration or 0) + 1
    local played = PlayPetEmote(pet, definition)
    local function finish()
        if pet.action ~= 'emote' or pet.animationGeneration ~= generation or not DoesEntityExist(pet.petId) then return end
        pet.action, pet.previousEmoteAction = previous or '', nil
        if previous == 'follow' then Follow(pet) else ClearPedTasks(pet.petId) end
    end
    if not played then finish(); return false end
    if definition.loop ~= 1 then
        CreateThread(function()
            Wait(math.min(30000, math.max(1, GetAnimDuration(definition.dict, definition.anim) * 1000)))
            finish()
        end)
    end
    DailyTaskCheck(pet, 'playEmote')
    UpdatePetUI()
    return true
end

local function searchEntity(pet, coords)
    if not DoesHaveRequiredJob(GetJobName(), 'sniff') or not (Config.Pets[pet.model] or {}).sniff then return end
    local entity, distance = GetClosestEntity(coords)
    if not entity or entity == 0 or distance > 3.0 then return end
    if IsEntityAPed(entity) then SearchPed(pet, entity) else SearchVehicle(pet, entity) end
end

local function searchVehicle(petData, vehicle)
    if not petData.abilities.searchVehicle then
        Notify(L("noAbility"))
        return
    end

    local plateText = GetVehicleNumberPlateText(vehicle)
    local trimmedPlate = trim(plateText, vehicle)
    local hasSniffedItem = DoesVehicleHaveSniffedItem(trimmedPlate, petData)

    if hasSniffedItem then
        local randomAction = math.random(1, 5)
        local bravery = petData.skills.sniff
        if randomAction <= bravery then
            AnimHandler(petData, "sit")
            Notify(L("foundSniffedItem"))
            DailyTaskCheck(petData, "sniffItem")
            AddXP(petData, Config.RewardsXP.successfulSearch)
            UpdatePetUI()
            Wait(500)
            AnimHandler(petData)
        end
    else
        Notify(L("sniffedItemNotFound"))
    end
end

local function dailyTaskCheck(petData, taskId)
    for _, task in ipairs(petData.dailyTasks or {}) do
        if task.id == taskId then
            if task.progress then
                if task.times > task.progress then
                    task.progress = task.progress + 1
                    TriggerServerEvent("electus_pets:updateDailyTasks", petData)
                    if task.progress == task.times then
                        local reward = 0
                        for _, taskConfig in ipairs(Config.DailyTasks.tasks) do
                            if taskConfig.id == taskId then
                                reward = taskConfig.reward
                                break
                            end
                        end
                        AddXP(petData, reward)
                        Notify(L("taskCompleted", { task = task.label }))
                    end
                end
            end
            break
        end
    end
end

local isRenamingPet = false
local function enterNewPetName(petData, otherPetData)
    if not otherPetData then return end
    local playerPed = PlayerPedId()
    local animDict = "creatures@rottweiler@amb@"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(0)
    end

    local playerCoords = GetOffsetFromEntityInWorldCoords(petData.petId, 0.13, -2.2, -0.1)
    local playerRotation = GetEntityRotation(petData.petId)
    local targetRotation = vector3(0.0, 0.0, 16.0)
    local finalRotation = playerRotation + targetRotation

    local playerOffsetCoords = GetOffsetFromEntityInWorldCoords(petData.petId, 0.0, 0.0, 0.0)
    local playerHeading = GetEntityHeading(petData.petId)
    local scene1 = NetworkCreateSynchronisedScene(playerCoords.x, playerCoords.y, playerCoords.z, finalRotation.x, finalRotation.y, finalRotation.z, 2, false, false, 1.0, 0.0, 1.0)
    local scene2 = NetworkCreateSynchronisedScene(playerOffsetCoords.x, playerOffsetCoords.y, playerOffsetCoords.z, 0.0, 0.0, playerHeading, 2, false, true, 1.0, 0.0, 1.0)

    NetworkAddPedToSynchronisedScene(petData.petId, scene1, "creatures@rottweiler@amb@", "hump_enter_chop", 8.0, -8.0, 0.0, 0, 1000.0, 0)
    NetworkStartSynchronisedScene(scene1)
    NetworkAddPedToSynchronisedScene(otherPetData.petId, scene2, "creatures@rottweiler@amb@", "hump_enter_ladydog", 8.0, -8.0, 0.0, 0, 1000.0, 0)
    NetworkStartSynchronisedScene(scene2)

    Wait(GetAnimDuration("creatures@rottweiler@amb@", "hump_enter_chop") * 950)

    local playerCoords2 = GetOffsetFromEntityInWorldCoords(otherPetData.petId, 0.0, -0.75, 0.0)
    local playerRotation2 = GetEntityRotation(otherPetData.petId)
    local targetRotation2 = vector3(0.0, 0.0, 13.0)
    local finalRotation2 = playerRotation2 + targetRotation2

    local scene3 = NetworkCreateSynchronisedScene(playerCoords2.x, playerCoords2.y, playerCoords2.z, 0.0, 0.0, finalRotation2.z, 2, false, false, 1.0, 0.0, 1.0)
    NetworkAddPedToSynchronisedScene(petData.petId, scene3, "creatures@rottweiler@amb@", "hump_exit_chop", 8.0, -8.0, 0.0, 0, 1000.0, 0)
    NetworkAddPedToSynchronisedScene(otherPetData.petId, scene3, "creatures@rottweiler@amb@", "hump_exit_ladydog", 8.0, -8.0, 0.0, 0, 1000.0, 0)
    NetworkStartSynchronisedScene(scene3)

    Wait(GetAnimDuration("creatures@rottweiler@amb@", "hump_exit_chop") * 950)

    HelpText(L("toEnterName", { key = Config.KeyActions.toEnterName }))

    while true do
        Wait(0)
        if isRenamingPet then
            isRenamingPet = false
            HideHelpText()
            local randomPet = math.random(1, 2)
            local petToReceive = randomPet == 1 and petData.model or otherPetData.model
            local success = lib.callback.await("electus_pets:confirmDogHump", false)
            if success then
                ReceivePet(petToReceive)
            end
            break
        end
    end
end

local function receivePet(petData)
    SendReactMessage("updateComponent", { component = "receivePet", model = petData })
    ToggleNuiFrame(true)
end

RegisterNetEvent("electus_pets:receivePet")
AddEventHandler("electus_pets:receivePet", function(petData)
    receivePet(petData)
end)

local function dogHump(petData, otherPetData)
    enterNewPetName(petData, otherPetData)
end

local function sendReactMessage(event, data)
    TriggerEvent("react:sendMessage", event, data)
end

local function toggleNuiFrame(state)
    SendNUIMessage({ type = "toggleFrame", state = state })
end

-- Public action API shared by the menu, riding and framework modules.
Follow = follow
FeedPet = feedPet
WetPet = wetPet
GoTo = goTo
AttackPed = attackPed
AttackWheel = attackWheel
FetchBall = fetchBall
CanBeCarried = canBeCarried
CarryPet = carryPet
GetIndexByPetId = getIndexByPetId
PeeOrPoop = peeOrPoop
PeeOrPoopSynced = peeOrPoopSynced
PlayEmote = playEmote
SearchEntity = searchEntity
SearchVehicle = searchVehicle
DailyTaskCheck = dailyTaskCheck
ReceivePet = receivePet
DogHump = dogHump
EnterVehicle = petEnterVehicle
ExitVehicle = petExitVehicle

function Attack(pet, coords)
    if not DoesHaveRequiredJob(GetJobName(), 'attack') or not (Config.Pets[pet.model] or {}).attack then return end
    local entity, distance = GetClosestEntity(coords)
    if entity and entity ~= 0 and distance <= 3.0 and IsEntityAPed(entity) then AttackPed(pet, entity) end
end
