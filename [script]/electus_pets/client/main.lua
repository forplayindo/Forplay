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

CurrentPets = {}
IsInPetMenu = false
PetIndexInSkillMenu = nil
PetMenuSelection = nil
CarriesPet = false
Action = nil
local petSessionGeneration = 0


function HasItems(items)
	local filteredItems = lib.callback.await("electus_pets:hasItems", false, items)

	if not filteredItems then
		return {}
	end
	for i = 1, #filteredItems do
		filteredItems[i] =
			{ name = filteredItems[i], label = GetAccessoryLabel(filteredItems[i]) or GetItemLabel(filteredItems[i]) }
	end

	return filteredItems
end

function HasItem(item)
	local hasItem = lib.callback.await("electus_pets:hasItem", false, item)
	return hasItem
end

local singleSequence =
	{ { 0.75, 0.0 }, { 0.75, 0.75 }, { 0.0, 0.75 }, { -0.75, 0.0 }, { -0.75, -0.75 }, { 0.0, -0.75 } }

lib.callback.register("electus_pets:setPetData", function(pet)
	local session = petSessionGeneration
	local function current()
		return session == petSessionGeneration and (not pet.owner or GetIdentifier() == pet.owner)
	end
	if not current() then return false end
	local timedOutTimer = GetGameTimer() + 20000

	while not NetworkDoesNetworkIdExist(pet.netId) do
		Wait(150)
		if not current() or GetGameTimer() > timedOutTimer then
			return
		end
	end
	if not current() then return false end

	local petId = NetworkGetEntityFromNetworkId(pet.netId)
	pet.petId = petId

	while not NetworkHasControlOfEntity(pet.petId) do
		if not current() or GetGameTimer() > timedOutTimer then return false end
		NetworkRequestControlOfEntity(pet.petId)
		Wait(150)
	end
	if not current() then return false end

	SetRelationshipBetweenGroups(3, GetPedRelationshipGroupHash(petId), GetHashKey("PLAYER"))
	SetRelationshipBetweenGroups(3, GetHashKey("PLAYER"), GetPedRelationshipGroupHash(petId))
	PlaceObjectOnGroundProperly(petId)
	SetEntityAsMissionEntity(petId, true, true)
	SetBlockingOfNonTemporaryEvents(petId, true)
	SetPedFleeAttributes(petId, 0, false)
	NetworkRegisterEntityAsNetworked(petId)

	NormalizePetStatus(pet)
	SetEntityMaxHealth(petId, PetMaxHealth(pet))
	SetEntityHealth(petId, pet.status.health)

	local componentId = pet.variation.componentId
	local textureId = pet.variation.textureId
	SetPedComponentVariation(petId, componentId, 0, textureId, 0)

	local maxIndex = #CurrentPets + 1

	CurrentPets[maxIndex] = {
		petId = petId,
		netId = pet.netId,
		model = pet.model,
		owner = pet.owner,
		sniffedItems = pet.sniffedItems,
		status = pet.status,
		skills = pet.skills,
		name = pet.name,
		bornAt = pet.bornAt,
		accessories = pet.accessories,
		stored = pet.stored,
		dailyTasks = pet.dailyTasks,
		abilities = pet.abilities,
		variation = pet.variation,
		breedingSeed = pet.breedingSeed,
		numOfBreedings = pet.numOfBreedings,
		sex = pet.sex,
	}

	UpdateAccessories(maxIndex)
	if pet.status.tracker then AddBlipForPet(CurrentPets[maxIndex]) end

	if Config.TargetSystem ~= "none" then
		PetTarget:RemoveTargetEntity(petId)

		if Config.TargetSystem == "qb-target" then
			PetTarget:AddTargetEntity(petId, {
				options = {
					{
						name = pet.name,
						event = "electus_pets:interact",
						label = L("petMenu"),
						pet = CurrentPets[maxIndex],
					},
					{
						icon = "fas fa-paw",
						label = L("petDog"),
						action = function(entity)
							local net = PedToNet(entity)

							if not NetworkDoesNetworkIdExist(net) then
								return
							end

							TriggerServerEvent("electus_pets:petDog", PedToNet(entity))
						end,
						canInteract = function(entity)
							return GetPetByNetId(PedToNet(entity))
								and Config.PettableDogs[GetPetByNetId(PedToNet(entity)).model] ~= nil
						end,
					},
					{
						icon = "fas fa-suitcase",
						label = L("petBag"),
						action = function(entity)
							SendReactMessage("updateComponent", {
								component = "bagLock",
								bagData = {
									owner = GetPetByNetId(PedToNet(entity)).owner,
									petName = GetPetByNetId(PedToNet(entity)).name,
								},
							})
							ToggleNuiFrame(true)
						end,
						canInteract = function(entity)
							return Config.EnablePetBags
								and GetPetByNetId(PedToNet(entity))
								and GetPetByNetId(PedToNet(entity)).hasBag
						end,
					},
				},
				distance = 2.5,
			})
		else
			PetTarget:AddTargetEntity(petId, {
				options = {
					{
						name = pet.name,
						event = "electus_pets:interact",
						label = L("petMenu"),
						pet = CurrentPets[maxIndex],
					},
				},
				distance = 2.5,
			})
		end
	end

	TriggerEvent("electus_pets:petSpawned", CurrentPets[maxIndex])
	Follow(CurrentPets[maxIndex])
	return true
end)

function SpawnPet(pet)
	if type(pet) ~= 'table' then return false end
	local hash = EnsurePetModel(pet.model)
	if not hash then return false end
	local ped = PlayerPedId()
	local forward = GetEntityForwardVector(ped)
	local coords = GetEntityCoords(ped)

	local spawnCoords = coords
		+ vector3(singleSequence[#CurrentPets % 6 + 1][1], singleSequence[#CurrentPets % 6 + 1][2], 0.0)
	local ret, spawnCoordsZ = GetGroundZFor_3dCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, false)

	if spawnCoords.z - spawnCoordsZ > 0.75 then
		spawnCoords = coords
	end

	local ok, spawned = pcall(lib.callback.await, "electus_pets:spawnPet", false, pet, spawnCoords)
	SetModelAsNoLongerNeeded(hash)
	if not ok then print(('electus_pets: spawn request failed: %s'):format(spawned)); return false end
	return spawned == true
end

RegisterNetEvent("electus_pets:spawnPet", function(pet)
	SpawnPet(pet)
end)

CreateThread(function()
	local hasBeenMsged = false
	while Config.TargetSystem == "none" do
		Wait(500)
		if #CurrentPets > 0 then
			local closest, petIndex = GetClosestPet()
			local pet = CurrentPets[petIndex]

			if closest < 2.0 and not CarriesPet and not hasBeenMsged then
				hasBeenMsged = true
				local text = L("open2", { ["open"] = Config.KeyActions.interactWithPet })

				if pet.hasBag then
					text = text .. "\n" .. L("openPetBag", { ["open"] = Config.KeyActions.petBag })
				end

				if Config.PettableDogs[pet.model] then
					text = text .. "\n" .. L("petDogKey", { ["key"] = Config.KeyActions.petDog })
				end
				local isOpen = lib.isTextUIOpen()

				if not isOpen then
					HelpText(text)
				end
			elseif closest > 2.0 and hasBeenMsged then
				hasBeenMsged = false
			end
		end
	end
end)

CreateThread(function()
	RegisterCommand(Config.Commands.petMenu, function(source, args)
		local closest, pet = GetClosestPet()
		if closest < 2.0 and not IsInPetMenu and not CarriesPet and not IsPedInAnyVehicle(PlayerPedId(), true) then
			if CurrentPets[pet] then
				OpenPetMenu(CurrentPets[pet])
			end
		end
	end, false)
end)

RegisterNetEvent('electus_pets:syncPet', function(saved)
    for _, pet in ipairs(CurrentPets) do
        if pet.name == saved.name then
            local hadTracker = pet.status and pet.status.tracker == true
            for _, key in ipairs({'skills','status','abilities','accessories','sniffedItems'}) do
                if saved[key] then pet[key] = saved[key] end
            end
            NormalizePetStatus(pet)
            if DoesEntityExist(pet.petId) then SetEntityMaxHealth(pet.petId, PetMaxHealth(pet)) end
            if hadTracker ~= pet.status.tracker then
                if pet.status.tracker then AddBlipForPet(pet) else RemoveBlipForPet(pet.name) end
            end
            if PetIndexInSkillMenu and CurrentPets[PetIndexInSkillMenu] == pet then UpdatePetUI() end
            break
        end
    end
end)

RegisterNetEvent("electus_pets:updateStatus", function(pet)
	TriggerEvent('electus_pets:syncPet', pet)
end)

RegisterNetEvent('electus_pets:applyHealth', function(name, netId, target, delta, revision)
    local index = GetPetIndex(name)
    local pet = index and CurrentPets[index]
    if not pet or pet.netId ~= netId then return end
    local function current()
        return CurrentPets[GetPetIndex(name)] == pet and (not revision or revision > (pet.healthRevision or 0))
    end
    if not current() then return end
    local deadline = GetGameTimer() + 2000
    while DoesEntityExist(pet.petId) and not NetworkHasControlOfEntity(pet.petId) do
        if GetGameTimer() >= deadline or not current() then return end
        NetworkRequestControlOfEntity(pet.petId)
        Wait(0)
    end
    if not current() or not DoesEntityExist(pet.petId) or GetEntityHealth(pet.petId) <= 0 then return end
    if revision then pet.healthRevision = revision end
    SetEntityMaxHealth(pet.petId, PetMaxHealth(pet))
    local current = GetEntityHealth(pet.petId)
    -- A delayed status message must not erase damage taken in the meantime.
    local health = delta > 0 and math.min(target, current + delta) or math.min(target, current)
    SetEntityHealth(pet.petId, math.max(0, math.min(PetMaxHealth(pet), health)))
    pet.status.health = GetEntityHealth(pet.petId)
    UpdatePetUI()
end)

function GetPetIndex(name)
	for i = 1, #CurrentPets do
		if CurrentPets[i].name == name then
			return i
		end
	end
end

function OpenPetMenu(pet)
	if type(pet) ~= 'table' then return end
	local index = GetPetIndex(pet.name)
	if not index or not CurrentPets[index] or GetEntityHealth(CurrentPets[index].petId) == 0 then
		return
	end

	IsInPetMenu = true
	PetIndexInSkillMenu = index
	PetMenuSelection = CurrentPets[index]
	local canAttack = false
	local canSniff = false

	local definition = Config.Pets[CurrentPets[index].model] or {}
	canAttack, canSniff = definition.attack == true, definition.sniff == true

	local health = GetEntityHealth(CurrentPets[index].petId)

	SendReactMessage("updateComponent", {
		component = "petMenu",
		pet = {
			pet = CurrentPets[index],
			health = health,
			canAttack = canAttack,
			canSniff = canSniff,
			canBeCarried = CanBeCarried(CurrentPets[index].model),
			canBeRidden = Config.CanBeRidden[CurrentPets[index].model] ~= nil,
			dailyTasks = CurrentPets[index].dailyTasks,
		},
	})

	ToggleNuiFrame(true)
	SetNuiFocusKeepInput(true)
	-- SetNuiFocus(false, true)
	-- SendReactMessage('setVisible', true)
	DisableIdleCamera(true)
	CreateThread(function()
		while IsInPetMenu do
			Wait(0)
			-- disable punching
			DisableControlAction(0, 24, true)
			DisableControlAction(0, 25, true)
			DisableControlAction(0, 69, true)
			DisableControlAction(0, 70, true)
			DisableControlAction(0, 91, true)
			DisableControlAction(0, 92, true)
			DisableControlAction(0, 106, true)
			DisableControlAction(0, 114, true)
			DisableControlAction(0, 140, true)
			DisableControlAction(0, 141, true)
			DisableControlAction(0, 142, true)
			DisableControlAction(0, 257, true)
			DisableControlAction(0, 263, true)
			DisableControlAction(0, 264, true)
			DisableControlAction(0, 330, true)
			DisableControlAction(0, 331, true)
			DisablePlayerFiring(PlayerId(), true)

			-- disable ESC
			DisableControlAction(0, 199, true)
			DisableControlAction(0, 200, true)

			-- disable looking around
			DisableControlAction(0, 1, true)
			DisableControlAction(0, 2, true)

			-- disable chat
			DisableControlAction(0, 245, true)

			-- disable scrollwheel
			DisableControlAction(0, 14, true)
			DisableControlAction(0, 15, true)
			DisableControlAction(0, 16, true)
			DisableControlAction(0, 17, true)
			DisableControlAction(0, 37, true)
			DisableControlAction(0, 50, true)
			DisableControlAction(0, 99, true)
			DisableControlAction(0, 115, true)
			DisableControlAction(0, 180, true)
			DisableControlAction(0, 181, true)
			DisableControlAction(0, 198, true)
			DisableControlAction(0, 241, true)
			DisableControlAction(0, 242, true)
			DisableControlAction(0, 261, true)
			DisableControlAction(0, 262, true)

			-- disable radio (scrollwheel down is not enough)
			DisableControlAction(0, 85, true)
		end
	end)
end

function DoesHaveRequiredJob(job, Action)
	if Config.JobRestrictions[Action] == "none" then
		return true
	end

	local hasJob = false
	if type(Config.JobRestrictions[Action]) == "table" then
		for i = 1, #Config.JobRestrictions[Action] do
			if Config.JobRestrictions[Action][i] == job then
				hasJob = true
				break
			end
		end
	else
		hasJob = Config.JobRestrictions[Action] == job
	end

	return hasJob
end

RegisterCommand(Config.Commands.petSettings, function()
	SendReactMessage("updateComponent", {
		component = "settings",
	})
	ToggleNuiFrame(true)
end, false)

-- RegisterCommand(Config.Commands.petInteract, function()
-- 	if not DoesInteract and #CurrentPets > 0 then
-- 		DoesInteract = true
-- 		SendReactMessage("updateComponent", {
-- 			component = "commandBar",
-- 		})
-- 		ToggleNuiFrame(true)
-- 		Interact()
-- 	end
-- end, false)

-- RegisterKeyMapping(Config.Commands.petInteract, "Pet Interact", "keyboard", Config.KeyActions.fastInteraction)
RegisterKeyMapping(Config.Commands.petMenu, "Pet Menu", "keyboard", Config.KeyActions.interactWithPet)

RegisterNetEvent("electus_pets:removeTransferedPet", function(currentPet)
	for i = 1, #CurrentPets do
		if CurrentPets[i].name == currentPet.name then
			if Config.TargetSystem ~= "none" then
				PetTarget:RemoveTargetEntity(CurrentPets[i].petId, {
					L("interact"),
				})
			end
			table.remove(CurrentPets, i)
			break
		end
	end
end)

-- RegisterNetEvent("electus_pets:removePet", function(currentPet)
--     for i = 1, #CurrentPets do
--         if (CurrentPets[i].name == (currentPet.name or currentPet)) then
--             if (CurrentPets[i].status.tracker) then
--                 RemoveBlipForPet(CurrentPets[i].name)
--             end
--             TriggerServerEvent("electus_pets:removePetMigrate", PedToNet(CurrentPets[i].petId))
--             DeletePet(CurrentPets[i])
--             break
--         end
--     end
-- end)

RegisterNetEvent("electus_pets:commandPetHouse", function()
	OpenPetHouse(-2)
end)

lib.callback.register("electus_pets:insertTransferedPet", function(currentPet)
	currentPet.petId = NetToPed(currentPet.netId)

	while not NetworkHasControlOfEntity(currentPet.petId) do
		NetworkRequestControlOfEntity(currentPet.petId)
		Wait(150)
	end

	CurrentPets[#CurrentPets + 1] = currentPet

	if Config.TargetSystem ~= "none" then
		PetTarget:AddTargetEntity(currentPet.petId, {
			options = {
				{
					name = currentPet.name,
					event = "electus_pets:interact",
					label = L("interact"),
					pet = CurrentPets[#CurrentPets],
				},
			},
			distance = 2.5,
		})
	end
	Follow(currentPet)
end)

AddEventHandler("onResourceStop", function(resourceName)
	if GetCurrentResourceName() ~= resourceName then
		return
	end
	-- TriggerServerEvent("electus_pets:forceDelete", CurrentPets)

	for i = 1, #CurrentPets do
		if CurrentPets[i].action == "riding" then
			StopRiding(CurrentPets[i])
		end

		DeleteEntity(CurrentPets[i].petId)

		if CurrentPets[i].accessoriesProps then
			for key, value in pairs(CurrentPets[i].accessoriesProps) do
				DeleteEntity(value)
			end
		end
	end

	for i = 1, #PetHouses do
		DeleteEntity(PetHouses[i].obj)
	end
end)

function ReloadPed()
	if GetResourceState("illenium-appearance") == "started" then
		TriggerEvent("illenium-appearance:reloadPed")
	elseif GetResourceState("skinchanger") == "started" then
		local ped = PlayerPedId()
		local maxhealth = GetEntityMaxHealth(ped)
		local health = GetEntityHealth(ped)
		local model = nil
		local sex = nil
		local loadSkin = nil

		TriggerEvent("skinchanger:getSkin", function(skin)
			sex = skin.sex
			loadSkin = skin
		end)

		local timer = GetGameTimer() + 10000

		while not loadSkin do
			Wait(100)
			if GetGameTimer() > timer then
				break
			end
		end

		if sex == 1 then
			model = GetHashKey("mp_f_freemode_01")
		else
			model = GetHashKey("mp_m_freemode_01")
		end

		local loaded = pcall(lib.requestModel, model, 5000)
        if not loaded then return end

		SetPlayerModel(PlayerId(), model)
		SetModelAsNoLongerNeeded(model)
		TriggerEvent("skinchanger:loadSkin", loadSkin)
		SetPedMaxHealth(PlayerPedId(), maxhealth)
		Wait(1000)
		SetEntityHealth(PlayerPedId(), health)
	elseif GetResourceState("fivem-appearance") == "started" then
		local appearance = exports["fivem-appearance"]:getPedAppearance(PlayerPedId())
		exports["fivem-appearance"]:setPedAppearance(PlayerPedId(), appearance)
	elseif GetResourceState("qb-clothing") == "started" then
		local health = GetEntityHealth(PlayerPedId())
		local model

		local gender = (GetFrameworkPlayerData().charinfo or {}).gender
		local maxhealth = GetEntityMaxHealth(PlayerPedId())

		if gender == 1 then -- Gender is ONE for FEMALE
			model = GetHashKey("mp_f_freemode_01") -- Female Model
		else
			model = GetHashKey("mp_m_freemode_01") -- Male Model
		end

		local loaded = pcall(lib.requestModel, model, 5000)
        if not loaded then return end

		SetPlayerModel(PlayerId(), model)
		SetModelAsNoLongerNeeded(model)
		Citizen.Wait(1000)

		TriggerServerEvent("qb-clothes:loadPlayerSkin")
		TriggerServerEvent("qb-clothing:loadPlayerSkin")

		SetPedMaxHealth(PlayerPedId(), maxhealth)
		Wait(1000)
		SetEntityHealth(PlayerPedId(), health)
	end
end

function GetPetHouseData(houseId)
	local data = lib.callback.await("electus_pets:getPetHouseData", false, houseId)

	return data
end

function OpenPetVet()
	local pets = lib.callback.await("electus_pets:getDeadPets", false)

	SendReactMessage("updateComponent", { component = "vet", vetPets = pets })
	ToggleNuiFrame(true)
end

function HandleUpdateAccessories(petIndex, data, action)
	local pet = CurrentPets[petIndex]
	if not pet then return end
	local item = data.item

	if data.item == nil then
		item = pet.accessories[data.slot]
	end

	if action == "removeItem" then
		local compatible = IsAccessoryCompatible(pet.model, data.item)
		if not compatible then
			Notify(L("incompatibleAccessory"))
			return
		end
	end


	local success = lib.callback.await("electus_pets:updateAccessories", false, CurrentPets[petIndex], item, action)
	local index = GetPetIndex(pet.name)
	if not index or CurrentPets[index] ~= pet then return end
	if success then
		pet.accessories[data.slot] = action == "removeItem" and item or nil
		UpdateAccessories(index)
		SyncUIAccessoriesInventory()
		SyncUIAccessoriesSlots(pet)
	end
end

local loadingPets, petLoadGeneration = false, 0
function CancelPetLoading()
    petSessionGeneration = petSessionGeneration + 1
    petLoadGeneration = petLoadGeneration + 1
    loadingPets = false
end

function LoadPets()
    if loadingPets then return false end
    loadingPets = true
    local generation, pets = petLoadGeneration, nil
    for attempt = 1, 3 do
        local ok, response = pcall(lib.callback.await, 'electus_pets:getPets', false)
        if generation ~= petLoadGeneration then return false end
        if ok and type(response) == 'table' and not response.error then pets = response; break end
        print(('electus_pets: pet list unavailable (attempt %s/3): %s'):format(attempt,
            ok and type(response) == 'table' and response.error or tostring(response)))
        if attempt < 3 then Wait(1000 * attempt) end
        if generation ~= petLoadGeneration then return false end
    end
    if not pets then
        loadingPets = false
        Notify(L('petsLoadFailed'))
        return false
    end
    local ok, err = pcall(function()
        for _, pet in ipairs(pets) do
            if generation ~= petLoadGeneration then return end
            if type(pet) == 'table' and type(pet.name) == 'string' and Config.Pets[pet.model]
                and not pet.stored and not pet.dead and not GetPetIndex(pet.name) then
                NormalizePetStatus(pet)
                SpawnPet(pet)
            end
        end
    end)
    if generation == petLoadGeneration then loadingPets = false end
    if not ok then print(('electus_pets: pet setup failed: %s'):format(err)); return false end
    return generation == petLoadGeneration
end

function SearchPed(pet, ped)
	local id = GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))
	local foundItem = lib.callback.await("electus_pets:searchPlayer", false, id, pet)

	local ranNum = math.random(1, 10)

	if foundItem then
		if pet.skills.sniff >= ranNum then
			AnimHandler(pet, "sitAnim")
			Notify(L("foundSniffedItem"))
			AddXP(pet, Config.RewardsXP.successfulSearch)
			DailyTaskCheck(pet, "sniffItem")
			UpdatePetUI()
			Wait(500)
			AnimHandler(pet)
		end
	else
		Notify(L("sniffedItemNotFound"))
	end
end

function OpenPetBagInventory(petName, owner)
	TriggerServerEvent("electus_pets:openBagInventory", petName, owner)
end
