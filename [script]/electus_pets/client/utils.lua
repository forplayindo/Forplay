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

function PetJobAllowed(job, requirement)
    if requirement == nil or requirement == 'none' then return true end
    if type(requirement) == 'table' then
        for _, name in pairs(requirement) do if name == job then return true end end
        return false
    end
    return job == requirement
end

function GetClosestEntity(coords)
	local ped, dist = GetClosestPedDist(coords)
	local veh, vehDist = GetClosestVehicleDist(coords)
	if ped ~= 0 and (veh == 0 or dist <= vehDist) then return ped, dist end
	if veh ~= 0 then return veh, vehDist end
	return 0, math.huge
end

function Notify(msg)
	lib.notify({ description = msg })
end

function GetClosePets(dist)
	local closePets = {}
	local pedCoords = GetEntityCoords(PlayerPedId())
	for i = 1, #CurrentPets do
		if DoesEntityExist(CurrentPets[i].petId) and #(GetEntityCoords(CurrentPets[i].petId) - pedCoords) < dist then
			closePets[#closePets + 1] = CurrentPets[i]
		end
	end
	return closePets
end

function GetClosestPet()
	local pet, closest = 0, 999
	for i = 1, #CurrentPets do
		if DoesEntityExist(CurrentPets[i].petId) then
			local distance = #(GetEntityCoords(CurrentPets[i].petId) - GetEntityCoords(PlayerPedId()))
			if distance < closest then pet, closest = i, distance end
		end
	end
	return closest, pet
end

function GetWorldCoordsFromScreen()
	local camCoords = GetFinalRenderedCamCoord()
	local rot = GetFinalRenderedCamRot(2)
	local dir = RotToDir(rot)
	local endPoint = camCoords + dir * 75
	local raycast = StartExpensiveSynchronousShapeTestLosProbe(
		camCoords.x,
		camCoords.y,
		camCoords.z,
		endPoint.x,
		endPoint.y,
		endPoint.z,
		1,
		PlayerPedId(),
		4
	)
	local result, hit, coords = GetShapeTestResult(raycast)

	return coords
end

function RotToDir(rot)
	return vector3(
		-math.sin((math.pi / 180) * rot.z) * math.abs(math.cos((math.pi / 180) * rot.x)),
		math.cos((math.pi / 180) * rot.z) * math.abs(math.cos((math.pi / 180) * rot.x)),
		math.sin((math.pi / 180) * rot.x)
	)
end

function GetClosestPedDist(coords)
    local closest, distance = 0, math.huge
    local excluded = { [PlayerPedId()] = true }
    for _, pet in ipairs(CurrentPets) do excluded[pet.petId] = true end
    for _, ped in ipairs(GetGamePool('CPed')) do
        if not excluded[ped] and DoesEntityExist(ped) then
            local candidate = #(coords - GetEntityCoords(ped))
            if candidate < distance then closest, distance = ped, candidate end
        end
    end
    return closest, distance
end

function GetClosestVehicleDist(coords)
    local closest, distance = 0, math.huge
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local candidate = #(coords - GetEntityCoords(vehicle))
            if candidate < distance then closest, distance = vehicle, candidate end
        end
    end
    return closest, distance
end

function trim(string)
	return (string:gsub("^%s*(.-)%s*$", "%1"))
end

function LoadModel(model)
	local hash = GetHashKey(model)

	RequestModel(hash)
	while not HasModelLoaded(hash) do
		Wait(0)
	end
end

function EnsurePetModel(model)
    if type(model) ~= 'string' or not Config.Pets[model] then return false end
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) or not IsModelAPed(hash) then
        Notify(L('petModelUnavailable', { model = model }))
        return false
    end
    local ok, err = pcall(lib.requestModel, hash, 10000)
    if not ok then
        print(('electus_pets: failed to load model %s: %s'):format(model, err))
        Notify(L('petModelUnavailable', { model = model }))
        return false
    end
    return hash
end

function LoadDict(Dict)
	while not HasAnimDictLoaded(Dict) do
		Wait(0)
		RequestAnimDict(Dict)
	end

	return Dict
end

function LoadAnim(dict)
	RequestAnimDict(dict)
	while not HasAnimDictLoaded(dict) do
		Wait(0)
	end
end

function ToggleNuiFrame(shouldShow)
	SetNuiFocus(shouldShow, shouldShow)
	SetNuiFocusKeepInput(false)
	SendReactMessage("setVisible", shouldShow)
end

function SendReactMessage(action, data)
	SendNUIMessage({
		action = action,
		data = data,
	})
end

function HelpText(text, type)
	lib.showTextUI(text, type)
end

function HideHelpText()
	lib.hideTextUI()
end
