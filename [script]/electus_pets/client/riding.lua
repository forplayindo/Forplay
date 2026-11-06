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

StoredPlayerPed = nil
ControlledRidingPet = nil

function PreventActionRiding()
	if StoredPlayerPed or ControlledRidingPet then
		Notify(L("ActionImpossibleRiding"))
		return true
	end
	return false
end

function StopRiding(pet)
	if ControlledRidingPet == pet then return StopRidingControlling(pet) end
	if not StoredPlayerPed then
		return
	end

	local prePedHealth = GetEntityHealth(StoredPlayerPed)
	local prePedArmour = GetPedArmour(StoredPlayerPed)

	pet.action = ""
	pet.petId = PlayerPedId()

	local index = GetIndexByPetId(pet.petId)

	DetachEntity(StoredPlayerPed, true, true)
	ChangePlayerPed(PlayerId(), StoredPlayerPed, true, false)

	CreateThread(function()
		Wait(1000)
		SetEntityHealth(PlayerPedId(), prePedHealth)
		SetPedArmour(PlayerPedId(), prePedArmour)
	end)

	ClearPedTasksImmediately(StoredPlayerPed)
	ClearPedTasksImmediately(PlayerPedId())

	SetPedFleeAttributes(pet.petId, 0, false)
	SetPedFleeAttributes(StoredPlayerPed, 0, false)

	SetBlockingOfNonTemporaryEvents(pet.petId, true)
	SetBlockingOfNonTemporaryEvents(StoredPlayerPed, true)

	ReloadPed()

	if Config.TargetSystem ~= "none" then
		PetTarget:RemoveTargetEntity(pet.petId)
	end

	HideHelpText()

	DeletePet(pet)
	StoredPlayerPed = nil
	SpawnPet(pet)
end

local stopRiding = false

local stopRidingKey = lib.addKeybind({
	name = "stop_riding",
	description = "Stop Riding",
	defaultKey = Config.KeyActions.stopRiding,
	onPressed = function(self)
		stopRiding = true
	end,
	onReleased = function(self)
		stopRiding = false
	end,
})

function StartRiding(pet)
	if Config.EnableControlledRiding then
		return StartRidingControlling(pet)
	end

	local variation = pet.variation
	local prePedHealth = GetEntityHealth(PlayerPedId())

	RequestModel(pet.model)
	while not HasModelLoaded(pet.model) do
		Wait(10)
	end

	RequestAnimDict("rcmjosh2")
	while not HasAnimDictLoaded("rcmjosh2") do
		Wait(0)
	end

	local ped = PlayerPedId()
	local playerPed = ClonePed(ped, true, true, false)

	DeleteEntity(pet.petId)
	SetPlayerModel(PlayerId(), GetHashKey(pet.model)) -- Set the player model to the pet model

	SetModelAsNoLongerNeeded(pet.model)
	SetEntityAsMissionEntity(playerPed, true, true)

	SetBlockingOfNonTemporaryEvents(PlayerPedId(), true)
	TaskSetBlockingOfNonTemporaryEvents(PlayerPedId(), true)
	SetPedKeepTask(PlayerPedId(), true)
	SetPedFleeAttributes(PlayerPedId(), 0, false)
	NetworkRegisterEntityAsNetworked(PlayerId())
	SetPedComponentVariation(PlayerPedId(), variation.componentId, 0, variation.textureId, 0)

	local ridingOffsets = Config.RidingOffsets[pet.model]
		or { offset = vector3(-0.3, 0.0, 0.3), rot = vector3(0.0, 0.0, 90.0) }

	AttachEntityToEntity(
		playerPed,
		PlayerPedId(),
		GetPedBoneIndex(PlayerPedId(), 24816),
		ridingOffsets.offset,
		ridingOffsets.rot,
		false,
		false,
		false,
		true,
		2,
		true
	)

	TaskPlayAnim(playerPed, "rcmjosh2", "josh_sitting_loop", 8.0, 1, -1, 2, 1.0, false, false, false)

	pet.action = "riding"
	StoredPlayerPed = playerPed

	SetEntityAsMissionEntity(playerPed, true, true)
	SetBlockingOfNonTemporaryEvents(playerPed, true)
	SetPedFleeAttributes(playerPed, 0, false)
	NetworkRegisterEntityAsNetworked(PlayerId())

	SetEntityHealth(playerPed, prePedHealth)

	CreateThread(function()
		local fallingOffTimer = 0

		HelpText(L("toStopRiding", { key = Config.KeyActions.stopRiding }))

		while pet.action == "riding" do
			Wait(0)
			if pet then
				DisableControlAction(0, 23, true)
				DisableControlAction(0, 24, true)
				DisableControlAction(0, 25, true)

				if Config.RidingClearEveryFrame then
					ClearPedTasks(PlayerPedId())
				else
					if
						GetScriptTaskStatus(PlayerPedId(), 0x87B9A382) ~= 7
						or GetScriptTaskStatus(PlayerPedId(), "SCRIPT_TASK_START_SCENARIO_IN_PLACE") ~= 7
						or GetScriptTaskStatus(PlayerPedId(), 0x8ECCBFB3) ~= 7
					then
						ClearPedTasksImmediately(PlayerPedId())
					end
				end

				if stopRiding then
					stopRiding = false
					StopRiding(pet)
					break
				end

				if pet.skills.obedience < 5 and (GetGameTimer() - fallingOffTimer) > 240 * 1000 then
					local rand = math.random(1, 100)
					local val = (5 - pet.skills.obedience) * 10
					fallingOffTimer = GetGameTimer()

					if rand < val then
						HideHelpText()
						Notify(L("youGotKickedOff"))
						StopRiding(pet)
						SetPedToRagdoll(PlayerPedId(), 1000, 1000, 0, 0, 0, 0)
						break
					end
				end

				if IsPedRagdoll(pet.petId) then
					StopRiding(pet)
					SetPedToRagdoll(PlayerPedId(), 1000, 1000, 0, 0, 0, 0)
					break
				end
			end
		end

		StopRiding(pet)

		for i = 1, #CurrentPets do
			Follow(CurrentPets[i])
		end
	end)
end

function StartRidingControlling(pet)
    local player = PlayerPedId()
    local offsets = pet and Config.RidingOffsets[pet.model]
    if not pet or not offsets or not Config.CanBeRidden[pet.model] then return false end
    if StoredPlayerPed or ControlledRidingPet or not DoesEntityExist(pet.petId) or IsEntityDead(pet.petId)
        or IsPedInAnyVehicle(player, false) or pet.currentVehicle or pet.pettingSession
        or #(GetEntityCoords(player) - GetEntityCoords(pet.petId)) > 3.0
        or (pet.action and pet.action ~= '' and pet.action ~= 'follow' and pet.action ~= 'idle') then
        Notify(L('cannotRideNow')); return false
    end
    local deadline = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(pet.petId) do
        if GetGameTimer() >= deadline or not DoesEntityExist(pet.petId) then Notify(L('cannotRideNow')); return false end
        NetworkRequestControlOfEntity(pet.petId)
        Wait(0)
    end
    local ok = pcall(lib.requestAnimDict, 'rcmjosh2', 3000)
    if not ok then Notify(L('cannotRideNow')); return false end
    local bone = GetPedBoneIndex(pet.petId, 24816)
    if bone == -1 then bone = 0 end
    local offset, rotation = offsets.offset, offsets.rot
    AttachEntityToEntity(player, pet.petId, bone, offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z, false, false, false, true, 2, true)
    TaskPlayAnim(player, 'rcmjosh2', 'josh_sitting_loop', 2.0, -2.0, -1, 1, 0.0, false, false, false)
    SetPedKeepTask(player, true)
    pet.previousRidingAction, pet.action = pet.action, 'riding'
    ControlledRidingPet, stopRiding = pet, false
    CreateThread(function()
        local ok, err = pcall(function()
            local fallingOffTimer = GetGameTimer()
            local lastX, lastY, lastSpeed, target, moving
            local nextTaskAt = 0
            HelpText(L('toStopRiding', { key = Config.KeyActions.stopRiding }))
            while ControlledRidingPet == pet and pet.action == 'riding' do
                Wait(0)
                if stopRiding or not DoesEntityExist(pet.petId) or IsEntityDead(pet.petId) or IsEntityDead(player) then break end
                for _, control in ipairs({23, 24, 25}) do DisableControlAction(0, control, true) end
                local obedience = tonumber(pet.skills.obedience) or 0
                if obedience < 5 and GetGameTimer() - fallingOffTimer > 240000 then
                    fallingOffTimer = GetGameTimer()
                    if math.random(1, 100) < (5 - obedience) * 10 then
                        Notify(L('youGotKickedOff'))
                        StopRidingControlling(pet)
                        SetPedToRagdoll(player, 1000, 1000, 0, false, false, false)
                        break
                    end
                end
                if IsPedRagdoll(pet.petId) then break end
                local x, y = GetControlNormal(2, 218), GetControlNormal(2, 219)
                local speed = IsControlPressed(0, 21) and 3.0 or 2.0
                if math.abs(x) + math.abs(y) < 0.08 then
                    if moving then TaskStandStill(pet.petId, 10000) end
                    moving, target = false, nil
                elseif GetGameTimer() >= nextTaskAt then
                    local changed = not moving or math.abs(x - (lastX or 0)) > 0.12
                        or math.abs(y - (lastY or 0)) > 0.12 or speed ~= lastSpeed
                    if changed or not target or #(GetEntityCoords(pet.petId) - target) < 4.0 then
                        target = GetOffsetFromEntityInWorldCoords(pet.petId, x * 20.0, -y * 20.0, 0.0)
                        local coords = GetEntityCoords(pet.petId)
                        local heading = GetHeadingFromVector_2d(target.x - coords.x, target.y - coords.y)
                        TaskGoStraightToCoord(pet.petId, target.x, target.y, target.z, speed, -1, heading, 0.5)
                        lastX, lastY, lastSpeed = x, y, speed
                        moving, nextTaskAt = true, GetGameTimer() + 200
                    end
                end
            end
        end)
        StopRidingControlling(pet)
        if not ok then print(('electus_pets: riding failed: %s'):format(err)) end
    end)
    return true
end

function StopRidingControlling(pet)
    if ControlledRidingPet ~= pet then return end
    ControlledRidingPet, stopRiding = nil, false
    HideHelpText()
    StopAnimTask(PlayerPedId(), 'rcmjosh2', 'josh_sitting_loop', 2.0)
    DetachEntity(PlayerPedId(), true, true)
    local previous = pet.previousRidingAction
    pet.previousRidingAction = nil
    if pet.action == 'riding' then
        pet.action = previous or ''
        if DoesEntityExist(pet.petId) and not IsEntityDead(pet.petId) then
            if previous == 'follow' then Follow(pet) else ClearPedTasks(pet.petId) end
        end
    end
end
