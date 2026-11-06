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

local currentValue = nil
local activeMarkers = {}
local blips = {}
local interactablePeds = {
	petShop = {},
	accessoryShop = {},
	vets = {},
}

function ClearPetMarkers()
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    blips, activeMarkers, currentValue = {}, {}, nil
end

function AddBlip(coords, sprite, text, size, color)
	if not Config.EnableBlips then
		return
	end
	local blip = AddBlipForCoord(coords)
	SetBlipSprite(blip, sprite)
	SetBlipDisplay(blip, 4)
	SetBlipScale(blip, size)
	SetBlipColour(blip, color)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(text)
	EndTextCommandSetBlipName(blip)
	blips[#blips + 1] = blip
end

function SpawnMarkerPed(markerType, markerName)
	local coords = nil
	local heading = 0.0
	local model = nil

	if markerType == "petShop" then
		coords = Config.PetShop[markerName].markerCoords.xyz
		heading = Config.PetShop[markerName].markerCoords.w
		model = Config.PetShop[markerName].shopModel
	elseif markerType == "accessoryShop" then
		coords = Config.AccessoryShop.shops[markerName].markerCoords.xyz
		heading = Config.AccessoryShop.shops[markerName].markerCoords.w
		model = Config.AccessoryShop.shops[markerName].shopModel
	elseif markerType == "vets" then
		coords = Config.Vets[markerName].coords
		heading = Config.Vets[markerName].heading
		model = Config.Vets[markerName].model
	end

	if not coords or not heading or not model then
		return
	end

	lib.requestModel(model)

	local ped = CreatePed(0, model, coords.x, coords.y, coords.z, heading, false, false)

	-- Wait until the NPC is fully spawned
	while not DoesEntityExist(ped) do
		Wait(1)
	end

	PlaceObjectOnGroundProperly(ped)

	SetPedFleeAttributes(ped, 0, false)
	SetBlockingOfNonTemporaryEvents(ped, true)
	SetPedCanRagdollFromPlayerImpact(ped, false)
	SetPedDiesWhenInjured(ped, false)
	FreezeEntityPosition(ped, true)
	SetEntityInvincible(ped, true)
	SetPedCanPlayAmbientAnims(ped, false)

	interactablePeds[markerType][markerName] = ped
end

-- NON TARGET USERS
CreateThread(function()
	while Config.TargetSystem == "none" do
		Wait(2500)
		local pedCoords = GetEntityCoords(PlayerPedId())

		for i, v in pairs(Config.PetShop) do
			local interactCoords = vector3(v.markerCoords.x, v.markerCoords.y, v.markerCoords.z)

			if #(interactCoords - pedCoords) < 50.0 then
				local found = false

				for j = 1, #activeMarkers do
					if activeMarkers[j] == i then
						found = true
						break
					end
				end

				if not found and PetJobAllowed(GetJobName(), v.jobRequirement) then
					activeMarkers[#activeMarkers + 1] =
						{ markerType = "petShop", markerName = i, coords = interactCoords }
				end
			end
		end

		for i, v in pairs(Config.AccessoryShop.shops) do
			local interactCoords = vector3(v.markerCoords.x, v.markerCoords.y, v.markerCoords.z)

			if #(interactCoords - pedCoords) < 50.0 then
				local found = false

				for j = 1, #activeMarkers do
					if activeMarkers[j] == i then
						found = true
						break
					end
				end

				if not found then
					activeMarkers[#activeMarkers + 1] =
						{ markerType = "accessoryShop", markerName = i, coords = interactCoords }
				end
			end
		end

		for i, v in pairs(Config.Vets) do
			local interactCoords = vector3(v.coords.x, v.coords.y, v.coords.z)

			if #(interactCoords - pedCoords) < 50.0 then
				local found = false

				for j = 1, #activeMarkers do
					if activeMarkers[j] == i then
						found = true
						break
					end
				end

				if not found then
					activeMarkers[#activeMarkers + 1] = { markerType = "vets", markerName = i, coords = interactCoords }
				end
			end
		end
	end
end)

function LoadMarkers()
	LoadBlips()

	-- should not load target system markers if target system is none
	if Config.TargetSystem == "none" then
		return
	end

	LoadPetShops()
	LoadVets()
	LoadAccessoryShop()
end

function LoadBlips()
	for i = 1, #blips do
		RemoveBlip(blips[i])
	end
	blips = {}

	for i, v in pairs(Config.PetShop) do
		if PetJobAllowed(GetJobName(), v.jobRequirement) then
			AddBlip(v.markerCoords.xyz, v.blip.sprite, v.blip.name, v.blip.size, v.blip.color)
		end
	end

	for i, v in pairs(Config.AccessoryShop.shops) do
		if PetJobAllowed(GetJobName(), v.jobRequirement) then
			AddBlip(v.markerCoords.xyz, v.blip.sprite, v.blip.name, v.blip.size, v.blip.color)
		end
	end

	for i, v in pairs(Config.Vets) do
		if PetJobAllowed(GetJobName(), v.jobRequirement) then
			AddBlip(v.coords.xyz, v.blip.sprite, v.blip.name, v.blip.size, v.blip.color)
		end
	end
end

CreateThread(function()
	while true do
		local playerCoords = GetEntityCoords(PlayerPedId())

		for k, v in pairs(Config.PetShop) do
			if #(playerCoords - v.markerCoords.xyz) < 50.0 then
				if
					not interactablePeds.petShop
					or not interactablePeds.petShop[k]
					or not DoesEntityExist(interactablePeds.petShop[k])
				then
					SpawnMarkerPed("petShop", k)
				end
			else
				if
					interactablePeds.petShop
					and interactablePeds.petShop[k]
					and DoesEntityExist(interactablePeds.petShop[k])
				then
					DeleteEntity(interactablePeds.petShop[k])
					interactablePeds.petShop[k] = nil
				end
			end
		end

		for k, v in pairs(Config.AccessoryShop.shops) do
			if #(playerCoords - v.markerCoords.xyz) < 50.0 then
				if
					not interactablePeds.accessoryShop
					or not interactablePeds.accessoryShop[k]
					or not DoesEntityExist(interactablePeds.accessoryShop[k])
				then
					SpawnMarkerPed("accessoryShop", k)
				end
			else
				if
					interactablePeds.accessoryShop
					and interactablePeds.accessoryShop[k]
					and DoesEntityExist(interactablePeds.accessoryShop[k])
				then
					DeleteEntity(interactablePeds.accessoryShop[k])
					interactablePeds.accessoryShop[k] = nil
				end
			end
		end

		for k, v in pairs(Config.Vets) do
			if #(playerCoords - v.coords) < 50.0 then
				if
					not interactablePeds.vets
					or not interactablePeds.vets[k]
					or not DoesEntityExist(interactablePeds.vets[k])
				then
					SpawnMarkerPed("vets", k)
				end
			else
				if interactablePeds.vets and interactablePeds.vets[k] and DoesEntityExist(interactablePeds.vets[k]) then
					DeleteEntity(interactablePeds.vets[k])
					interactablePeds.vets[k] = nil
				end
			end
		end

		Wait(2500)
	end
end)

function LoadPetShops()
	for i, v in pairs(Config.PetShop) do
		PetTarget:RemoveTargetModel({ v.shopModel }, { L("interact") })

		PetTarget:AddTargetModel({ v.shopModel }, {
			options = {
				{
					label = L("interact"),
					action = function()
						OpenPetShop(i)
					end,
					canInteract = function(entity)
						local customRequirement = not v.customRequirement or v.customRequirement()
						local jobRequirement = PetJobAllowed(GetJobName(), v.jobRequirement)

						return interactablePeds.petShop
							and interactablePeds.petShop[i]
							and DoesEntityExist(interactablePeds.petShop[i])
							and entity == interactablePeds.petShop[i]
							and customRequirement
							and jobRequirement
					end,
				},
			},
			distance = 2,
		})
	end
end

function LoadVets()
	for i = 1, #Config.Vets do
		PetTarget:RemoveTargetModel({ Config.Vets[i].model }, { L("interact") })
		if Config.Vets[i] then
			PetTarget:AddTargetModel({ Config.Vets[i].model }, {
				options = {
					{
						label = L("interact"),
						action = function()
							OpenPetVet()
						end,
						canInteract = function(entity)
							return interactablePeds.vets
								and interactablePeds.vets[i]
								and DoesEntityExist(interactablePeds.vets[i])
								and entity == interactablePeds.vets[i]
						end,
					},
				},
				distance = 2,
			})
		end
	end
end

function LoadAccessoryShop()
	for i, v in pairs(Config.AccessoryShop.shops) do
		PetTarget:RemoveTargetModel({ v.shopModel }, { L("interact") })

		PetTarget:AddTargetModel({ v.shopModel }, {
			options = {
				{
					label = L("interact"),
					action = function()
						OpenAccessoryShop()
					end,
					canInteract = function(entity)
						return interactablePeds.accessoryShop
							and interactablePeds.accessoryShop[i]
							and DoesEntityExist(interactablePeds.accessoryShop[i])
							and entity == interactablePeds.accessoryShop[i]
					end,
				},
			},
			distance = 2,
		})
	end
end

local petBlips = {}

function AddBlipForPet(pet)
	local blip = AddBlipForEntity(pet.petId)

	SetBlipSprite(blip, ((Config.Blips or {}).pet or {}).sprite or 442)
	SetBlipColour(blip, ((Config.Blips or {}).pet or {}).color or 2)
	SetBlipScale(blip, 1.0)
	SetBlipAsShortRange(blip, true)

	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(pet.name)
	EndTextCommandSetBlipName(blip)

	table.insert(petBlips, { name = pet.name, blip = blip })
end

function RemoveBlipForPet(petName)
	local blip = nil

	for i = 1, #petBlips do
		if petBlips[i].name == petName then
			blip = petBlips[i].blip
			table.remove(petBlips, i)
			break
		end
	end

	if blip then RemoveBlip(blip) end
end

CreateThread(function()
	while Config.TargetSystem == "none" do
		Wait(0)
		-- if (#activeMarkers > 0) then
		local pedCoords = GetEntityCoords(PlayerPedId())

		for k, v in pairs(activeMarkers) do
			if not interactablePeds[v.markerType] or not interactablePeds[v.markerType][v.markerName] then
				activeMarkers[k] = nil
				break
			end

			local coords = v.coords
			local dist = #(coords - pedCoords)

			if dist < 2.0 then
				currentValue = v

				local isOpen = lib.isTextUIOpen()

				if not isOpen then
					HelpText(L("open", { interact = Config.KeyActions.openInteractablePed }))
				end
			elseif currentValue and currentValue == v then
				currentValue = nil
				HideHelpText()
			elseif dist >= 50.0 then
				activeMarkers[k] = nil
				break
			end
		end

		if currentValue then
			if IsControlJustPressed(0, Config.Keys[Config.KeyActions.openInteractablePed].key) then
				if currentValue.markerType == "petShop" then
					local shop = Config.PetShop[currentValue.markerName]
					local customRequirement = not shop.customRequirement or shop.customRequirement()
					local jobCheck = PetJobAllowed(GetJobName(), shop.jobRequirement)

					if jobCheck and customRequirement then
						OpenPetShop(currentValue.markerName)
					end

					currentValue = nil
				elseif currentValue.markerType == "vets" then
					currentValue = nil
					OpenPetVet()
				elseif currentValue.markerType == "accessoryShop" then
					currentValue = nil
					OpenAccessoryShop()
				end
			end
		end
	end
	-- end
end)
