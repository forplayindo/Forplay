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

SelectedPet = nil
local cam = nil
CurrentShop = nil

function OpenPetShop(currentShop)
	if not Config.PetShop[currentShop] then return end
	if Config.PetShop[currentShop].pets[1] == nil then
		print("No pets in shop")
		return
	end

    if not PetJobAllowed(GetJobName(), Config.PetShop[currentShop].jobRequirement) then
        Notify(L('lackJobRequirement'))
        return
    end

	local firstModel = Config.PetShop[currentShop].pets[1]
	local hash = EnsurePetModel(firstModel)
	if not hash then return end
	CurrentShop = currentShop
	ToggleNuiFrame(true)

	local pets = {}

	for i = 1, #Config.PetShop[CurrentShop].pets do
		local key = Config.PetShop[CurrentShop].pets[i]
		local pet = Config.Pets[key]
		pets[i] = {
			model = key,
			label = pet.label,
			price = pet.price * Config.PetShop[CurrentShop].priceModifier,
			attack = pet.attack,
			sniff = pet.sniff,
			variations = Config.PetVariations[key],
		}
	end

	SendReactMessage("updateComponent", {
		component = "shop",
		pets = pets,
	})

	cam = CreateCamWithParams(
		"DEFAULT_SCRIPTED_CAMERA",
		Config.PetShop[CurrentShop].cam.coords.x,
		Config.PetShop[CurrentShop].cam.coords.y,
		Config.PetShop[CurrentShop].cam.coords.z,
		Config.PetShop[CurrentShop].cam.rot.x,
		Config.PetShop[CurrentShop].cam.rot.y,
		Config.PetShop[CurrentShop].cam.rot.z,
		45.0,
		1
	)

	SetCamActive(cam, true)
	RenderScriptCams(true, false, 0, true, false)
	SetZoom(50.0)

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

	local model = Config.PetShop[CurrentShop].pets[1]
	local componentId = Config.PetVariations[model][1].componentId
	local textureId = Config.PetVariations[model][1].textureId

	SetPedComponentVariation(SelectedPet, componentId, 0, textureId, 0)
end

-- RegisterCommand("testPet", function(source, args, rawCommand)
--     local drawableId = GetNumberOfPedDrawableVariations(SelectedPet, tonumber(args[1]))
--     print('usable IDs starting from 0 not 1')
--     print('count(drawableId): ', drawableId)

--     for drawableIndex = 0, drawableId - 1, 1 do
--         local textureId = GetNumberOfPedTextureVariations(SelectedPet, tonumber(args[1]), drawableIndex)
--         print('count(textureId): ', textureId)
--         for textureIndex = 0, textureId - 1, 1 do
--             print('drawableindex: ', drawableIndex, 'textureIndex: ', textureIndex, 'valid: ',
--                 IsPedComponentVariationValid(SelectedPet, tonumber(args[1]), drawableIndex, textureIndex))
--         end
--     end
-- end)

function ClosePetShopScene()
	if not SelectedPet then
		return
	end

	SetNuiFocus(false, false)
	DestroyCam(cam, 0)
	DeleteEntity(SelectedPet)

	while DoesEntityExist(SelectedPet) do
		Wait(0)
		DeleteEntity(SelectedPet)
	end

	RenderScriptCams(false, false, 1, true, true)
	cam, SelectedPet = nil, nil
	CurrentShop = nil
	SetFocusEntity(PlayerPedId())
end

function OpenAccessoryShop()
	ToggleNuiFrame(true)
	SendReactMessage("updateComponent", { component = "accessoryShop" })
end

function RotatePetInShop(value)
	if not SelectedPet then
		return
	end

	local rot = GetEntityHeading(SelectedPet)
	SetEntityHeading(SelectedPet, rot + value)
end

function SetZoom(value)
	local camData = Config.PetShop[CurrentShop].cam
	SetCamParams(
		cam,
		camData.coords.x,
		camData.coords.y,
		camData.coords.z,
		camData.rot.x,
		camData.rot.y,
		camData.rot.z,
		value + 0.0,
		1,
		1,
		2
	)
end
