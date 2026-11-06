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

-- NUI responses must contain JSON data, not Lua functions or native handles.
local function PetNuiValue(value, seen)
    local kind = type(value)
    if kind == 'string' or kind == 'boolean' then return value end
    if kind == 'number' then
        if value == value and value ~= math.huge and value ~= -math.huge then return value end
        return nil
    end
    if kind == 'vector3' or kind == 'vector4' then
        return { x = value.x, y = value.y, z = value.z, w = kind == 'vector4' and value.w or nil }
    end
    if kind ~= 'table' then return nil end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local result = {}
    for key, entry in pairs(value) do
        if type(key) == 'string' or type(key) == 'number' then
            result[key] = PetNuiValue(entry, seen)
        end
    end
    seen[value] = nil
    return result
end

local needsSelectedPet = {}
for _, name in ipairs({'command','carry','feed','drink','autoAttack','switchAutoAttack','switchTracker',
    'fetch','sniffNewItem','getSniffedItems','getSniffableItems','ridePet','upgradeSkill','unlockAbility',
    'playEmote','getAccessoriesData','removeAccessory','setAccessory','leash','guardArea','changePass'}) do
    needsSelectedPet[name] = true
end

local function isOwnedPet(pet)
    for _, candidate in ipairs(CurrentPets) do if candidate == pet then return true end end
    return false
end

local function resolveLeashPet(request)
    local pet
    if request.netId ~= nil then
        local netId = tonumber(request.netId)
        if not netId then return end
        for _, candidate in ipairs(CurrentPets) do
            if candidate.netId == netId then pet = candidate; break end
        end
        if not pet or (request.name and request.name ~= pet.name) or (request.owner and request.owner ~= pet.owner) then return end
    elseif PetMenuSelection then
        if isOwnedPet(PetMenuSelection) then pet = PetMenuSelection end
    else
        pet = CurrentPets[PetIndexInSkillMenu]
    end
    if not pet then return end
    if pet.netId and NetworkDoesNetworkIdExist(pet.netId) then
        local entity = NetworkGetEntityFromNetworkId(pet.netId)
        if entity ~= 0 and DoesEntityExist(entity) then pet.petId = entity end
    end
    if DoesEntityExist(pet.petId) then return pet end
end

local function RegisterPetNUICallback(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local replied = false
        local function reply(payload)
            if replied then return end
            cb(PetNuiValue(payload) or {})
            replied = true
        end
        local request = type(data) == 'table' and data or {}
        local selectedPet
        if needsSelectedPet[name] then
            local pet
            if name == 'leash' then pet = resolveLeashPet(request) else pet = CurrentPets[PetIndexInSkillMenu] end
            if not pet or not DoesEntityExist(pet.petId) then reply({ error = 'pet_unavailable' }); return end
            selectedPet = pet
        end
        local ok, err = xpcall(function() handler(request, reply, selectedPet) end, debug.traceback)
        if not ok then
            print(('electus_pets: NUI callback %s failed: %s'):format(name, err))
            reply({ error = 'callback_failed', callback = name })
        elseif not replied then
            reply({})
        end
    end)
end

RegisterPetNUICallback("command", function(data, cb)
	if not DoesInteract then
		DoesInteract = true
		Wait(150)
		SendReactMessage("updateComponent", {
			component = "commandBar",
		})
		ToggleNuiFrame(true)
		SetNuiFocusKeepInput(true)
		IsInPetMenu = false
		Interact(CurrentPets[PetIndexInSkillMenu])
	end
	PetIndexInSkillMenu = nil
	cb({})
end)

RegisterPetNUICallback("carry", function(data, cb)
	CarryPet(CurrentPets[PetIndexInSkillMenu])
	PetIndexInSkillMenu = nil
	IsInPetMenu = nil
	ToggleNuiFrame(false)
	SetNuiFocusKeepInput(false)
	cb({})
end)

RegisterPetNUICallback("feed", function(data, cb)
	if PreventActionRiding() then
		cb({})
		return
	end
	FeedPet(CurrentPets[PetIndexInSkillMenu])
	UpdatePetUI()

	cb({})
end)

RegisterPetNUICallback("drink", function(data, cb)
	if PreventActionRiding() then
		cb({})
		return
	end
	WetPet(CurrentPets[PetIndexInSkillMenu])
	UpdatePetUI()

	cb({})
end)

RegisterPetNUICallback("requestInput", function(data, cb)
	SetNuiFocusKeepInput(false)
	cb({})
end)

RegisterPetNUICallback("exitInput", function(data, cb)
	SetNuiFocusKeepInput(true)
	cb({})
end)

local function togglePetStatus(key)
    local pet = CurrentPets[PetIndexInSkillMenu]
    if not pet then return end
    local accepted = lib.callback.await('electus_pets:setStatus', false, pet.name, key, not (pet.status[key] == true))
    if not accepted then Notify(L('statusUpdateFailed')) end
end

RegisterPetNUICallback('autoAttack', function(_, cb)
    togglePetStatus('autoAttack')
    cb({})
end)

RegisterPetNUICallback('switchTracker', function(_, cb)
    togglePetStatus('tracker')
    cb({})
end)

RegisterPetNUICallback("fetch", function(data, cb)
	if PreventActionRiding() then
		cb({})
		return
	end
	FetchBall(CurrentPets[PetIndexInSkillMenu])
	cb({})
end)

RegisterPetNUICallback("sniffNewItem", function(data, cb)
	if PreventActionRiding() then
		cb({})
		return
	end
	SniffNewItem(CurrentPets[PetIndexInSkillMenu], data.item)
	cb({})
end)

RegisterPetNUICallback("getSniffedItems", function(data, cb)
	local items = CurrentPets[PetIndexInSkillMenu].sniffedItems
	local sniffedItems = {}
	for i = 1, #items do
		sniffedItems[#sniffedItems + 1] = {
			item = items[i],
			label = GetItemLabel(items[i]),
		}
	end
	cb(sniffedItems)
end)

RegisterPetNUICallback("transferPet", function(data, cb)
	ToggleNuiFrame(false)
	IsInPetMenu = false
	TriggerServerEvent("electus_pets:transferPet", data.pet, data.id)
	cb({})
end)

RegisterPetNUICallback("ridePet", function(data, cb)
	if PreventActionRiding() then
		cb({})
		return
	end
	ToggleNuiFrame(false)
	IsInPetMenu = false
	StartRiding(CurrentPets[PetIndexInSkillMenu])
	cb({})
end)

RegisterPetNUICallback("upgradeSkill", function(data, cb)
    local pet = CurrentPets[PetIndexInSkillMenu]
    if pet then
        local saved = lib.callback.await('electus_pets:upgradeSkill', false, { name = pet.name }, data.skill)
        if saved then pet.skills = saved.skills; pet.abilities = saved.abilities; UpdatePetUI() end
    end
    cb({})
end)

RegisterPetNUICallback("selectNewPet", function(data, cb)
	local pet = data.pet
	local hash = type(pet) == 'table' and EnsurePetModel(pet.model)
	if not hash then cb({ error = 'model_unavailable' }); return end

	while DoesEntityExist(SelectedPet) do
		Wait(0)
		DeleteEntity(SelectedPet)
	end

	local ret, z = GetGroundZFor_3dCoord(
		Config.PetShop[CurrentShop].petCoords.x,
		Config.PetShop[CurrentShop].petCoords.y,
		Config.PetShop[CurrentShop].petCoords.z,
		0
	)

	SelectedPet = CreatePed(
		28,
		hash,
		Config.PetShop[CurrentShop].petCoords.x,
		Config.PetShop[CurrentShop].petCoords.y,
		z,
		Config.PetShop[CurrentShop].petCoords.w,
		false,
		false
	)
	SetModelAsNoLongerNeeded(hash)
	SetEntityAlpha(SelectedPet, 0, false)
	Wait(50)
	SetEntityAlpha(SelectedPet, 255, false)
	SetPedFleeAttributes(SelectedPet, 2, false)
	SetBlockingOfNonTemporaryEvents(SelectedPet, true)
	SetPedCanRagdollFromPlayerImpact(SelectedPet, false)
	SetPedDiesWhenInjured(SelectedPet, false)
	FreezeEntityPosition(SelectedPet, true)
	SetEntityInvincible(SelectedPet, true)
	SetPedCanPlayAmbientAnims(SelectedPet, false)
	local model = pet.model
	if Config.PetVariations[model] then
		local componentId = Config.PetVariations[model][1].componentId
		local textureId = Config.PetVariations[model][1].textureId
		SetPedComponentVariation(SelectedPet, componentId, 0, textureId, 0)
	end

	cb({})
end)

RegisterPetNUICallback("changeZoom", function(data, cb)
	SetZoom(100 - tonumber(data.value))
	cb({})
end)

RegisterPetNUICallback("changeVariation", function(data, cb)
	SetPedComponentVariation(SelectedPet, data.value.componentId, 0, data.value.textureId, 0)
	cb({})
end)

RegisterPetNUICallback("hideFrame", function(data, cb)
	if CurrentShop then
		ClosePetShopScene()
	end
	ToggleNuiFrame(false)
	SendReactMessage("updateComponent", { component = "none" })
	if IsInPetMenu then
		Wait(100)
		IsInPetMenu = false
	end
	cb({})
end)

RegisterPetNUICallback("loadUtils", function(data, cb)
	loaded = true
    local uiConfig = {}
    for _, key in ipairs({'AbilitiesUpgrade', 'InventoryIconUrl', 'KeyActions', 'PaymentMethods', 'Pets', 'Ui', 'VetPrice'}) do
        uiConfig[key] = Config[key]
    end
    uiConfig.AccessoryShop = { shopItems = Config.AccessoryShop.shopItems }
    cb({ locale = locales[Config.Locale] or locales.en, config = uiConfig })
end)

RegisterPetNUICallback("rotatePetInShop", function(data, cb)
	RotatePetInShop(data.value)
	cb({})
end)

RegisterPetNUICallback("getSniffableItems", function(data, cb)
	local items = Config.AllowedSniffedItems
	local ownedItems = HasItems(items)

	for i = 1, #ownedItems do
		local alreadySniffed = false
		for j = 1, #CurrentPets[PetIndexInSkillMenu].sniffedItems do
			if CurrentPets[PetIndexInSkillMenu].sniffedItems[j] == ownedItems[i].name then
				alreadySniffed = true
				break
			end
		end
		ownedItems[i] = {
			item = ownedItems[i].name,
			label = GetItemLabel(ownedItems[i].name),
			alreadySniffed = alreadySniffed,
		}
	end

	cb(ownedItems)
end)

RegisterPetNUICallback("getEmotes", function(pet, cb)
	if PreventActionRiding() then
		cb({})
		return
	end
	if not Config.Emotes[pet.model] then
		cb({})
		return
	end
	cb(Config.Emotes[pet.model])
end)

RegisterPetNUICallback("unlockAbility", function(data, cb)
    local pet = CurrentPets[PetIndexInSkillMenu]
    if pet then
        local saved = lib.callback.await('electus_pets:unlockAbility', false, { name = pet.name }, data.ability)
        if saved then pet.skills = saved.skills; pet.abilities = saved.abilities; UpdatePetUI() end
    end
    cb({})
end)

RegisterPetNUICallback("playEmote", function(emote, cb)
	if PreventActionRiding() then
		return
	end
	PlayEmote(emote)
	cb({})
end)

RegisterPetNUICallback("dischargePet", function(data, cb)
	TriggerServerEvent("electus_pets:payVetBill", data.pet, data.paymentMethod)
	ToggleNuiFrame(false)
	cb({})
end)

RegisterPetNUICallback("switchAutoAttack", function(data, cb)
    togglePetStatus('autoAttack')
	cb({})
end)

RegisterPetNUICallback("getAccessoriesData", function(data, cb)
	local slots = GetAccessoiresSlots(CurrentPets[PetIndexInSkillMenu])
	local inventory = GetAccessoriesInventory()

	cb({ slots = slots, inventory = inventory })
end)

RegisterPetNUICallback("removeAccessory", function(data, cb)
	HandleUpdateAccessories(PetIndexInSkillMenu, data, "addItem")
	cb({})
end)

RegisterPetNUICallback("removeHouse", function(data, cb)
	RemoveHouse(data.houseId)
	ToggleNuiFrame(false)
	cb({})
end)

RegisterPetNUICallback("setAccessory", function(data, cb)
	HandleUpdateAccessories(PetIndexInSkillMenu, data, "removeItem")
	cb({})
end)

RegisterPetNUICallback("purchaseAccessories", function(data, cb)
	TriggerServerEvent("electus_pets:purchaseAccessories", data.basket, data.paymentMethod)
	ToggleNuiFrame(false)
	cb({})
end)

RegisterPetNUICallback("leash", function(data, cb, pet)
	if PreventActionRiding() then
		return
	end

	local accepted
    local enabling = not pet.leash
	if pet.leash then
		accepted = DetachLeash(pet)
	else
		local hasLeash = HasItem(Config.Items.petLeash)
		if not hasLeash then
			Notify(L("noLeashItem"))
			return
		end
		if not isOwnedPet(pet) then cb({ error = 'pet_unavailable' }); return end
		accepted = AttachLeash(pet)
	end
    if accepted and enabling and isOwnedPet(pet) and not pet.currentVehicle and not pet.pettingSession
        and (not pet.action or pet.action == '' or pet.action == 'idle' or pet.action == 'follow' or pet.action == 'emote') then
        Follow(pet)
    end
	UpdatePetUI()
	cb({ success = accepted == true, netId = pet.netId })
end)

RegisterPetNUICallback("getHouseData", function(data, cb)
	local houseData = GetPetHouseData(data.houseId)
	if not houseData then cb({ house = {}, outside = {}, maxOutside = Config.MaxAmountPetOutside, maxHouseSlots = 0 }); return end
	local pets = {}
	for i = 1, #CurrentPets do
		pets[#pets + 1] = { name = CurrentPets[i].name, model = CurrentPets[i].model }
	end
	cb({
		house = houseData.pets,
		maxOutside = Config.MaxAmountPetOutside,
		outside = pets,
		maxHouseSlots = (data.houseId == -2 and Config.MaxAmountPetInsideCommandHouse)
			or Config.PetHouseModels[houseData.data.houseType].maxPets,
	})
end)

RegisterPetNUICallback("guardArea", function(data, cb)
	local pedCoords = GetEntityCoords(PlayerPedId())
	CreateGuardArea(CurrentPets[PetIndexInSkillMenu], pedCoords)

	-- GuardArea(CurrentPets[PetIndexInSkillMenu], pedCoords, 5.0)
	cb({})
end)

RegisterPetNUICallback("insertPetInHouse", function(data, cb)
	InsertPetInHouse(data.houseId, data.petName, data.maxHouseSlots)
	cb({})
end)

RegisterPetNUICallback("getAvaliableFriendJobs", function(data, cb)
	cb(GetJobsLabel(Config.AllowedJobsToSetAsFriends))
end)

RegisterPetNUICallback("removePetFromHouse", function(data, cb)
	if #CurrentPets >= Config.MaxAmountPetOutside then
		Notify(L("maxOutside"))
		return
	end
	RemovePetFromHouse(data.petName, data.houseId)
	cb({})
end)

RegisterPetNUICallback("addJobAsFriend", function(data, cb)
	TriggerServerEvent("electus_pets:addJobAsFriend", data.job)
	cb({})
end)

RegisterPetNUICallback("removeJobAsFriend", function(data, cb)
	TriggerServerEvent("electus_pets:removeJobAsFriend", data.job)
	cb({})
end)

RegisterPetNUICallback("addFriend", function(data, cb)
	TriggerServerEvent("electus_pets:addFriend", data.id)
	cb({})
end)

RegisterPetNUICallback("getFriends", function(data, cb)
	cb(GetFriendList())
end)

RegisterPetNUICallback("removeFriend", function(data, cb)
	TriggerServerEvent("electus_pets:removeFriend", data.identifier)
	cb({})
end)

RegisterPetNUICallback("purchasePet", function(data, cb)
	local startingPoints = Config.PetShop[CurrentShop].startingSkillPoints
	TriggerServerEvent(
		"electus_pets:purchasePet",
		data.pet,
		data.variation,
		data.paymentMethod,
		data.name,
		startingPoints
	)
	ClosePetShopScene()
	ToggleNuiFrame(false)
	cb({})
end)

RegisterPetNUICallback("openOptions", function(data, cb)
	SetNuiFocusKeepInput(false)
	SendReactMessage("updateComponent", {
		component = "settings",
	})
	cb({})
end)

RegisterPetNUICallback("bagLock", function(data, cb)
	ToggleNuiFrame(false)
	SetNuiFocusKeepInput(true)
	IsInPetMenu = false
	TriggerServerEvent("electus_pets:unlockBag", data.owner, data.petName, data.password)
	cb({})
end)

RegisterPetNUICallback("changeBagLock", function(data, cb)
	SendReactMessage("updateComponent", { component = "changePass" })
	cb({})
end)

RegisterPetNUICallback("receivePet", function(data, cb)
	ToggleNuiFrame(false)
	TriggerServerEvent("electus_pets:givePet", data.name, data.model, 0)
	cb({})
end)

RegisterPetNUICallback("changePass", function(data, cb)
	TriggerServerEvent("electus_pets:registerBagPassword", CurrentPets[PetIndexInSkillMenu].name, data.password)
	ToggleNuiFrame(false)
	IsInPetMenu = false
	SetNuiFocusKeepInput(false)
	cb({})
end)

RegisterPetNUICallback('getCompatibiles', function(_, cb)
    local compatible, labels = {}, {}
    for model, accessories in pairs(Config.AddonAccessories or {}) do
        labels[model] = (Config.Pets[model] or {}).label or model
        for item in pairs(accessories) do
            compatible[item] = compatible[item] or {}
            compatible[item][#compatible[item] + 1] = model
        end
    end
    cb({ comp = compatible, labels = labels })
end)
