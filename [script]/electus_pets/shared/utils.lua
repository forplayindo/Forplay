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

function L(path, args)
	assert(type(path) == "string", "path must be a string")
	local translation = locales[Config.Locale]

	for key in path:gmatch("[^%.]+") do
		if not translation[key] then
			print("Translation not found for path: " .. path)
			return path
		end
		translation = translation[key]
	end

	if args then
		for k, v in pairs(args) do
			translation = translation:gsub("{" .. k .. "}", v)
		end
	end

	return type(translation) == "string" and translation or path
end

-- Accessory fits live here so existing manifests load them before client/server consumers.
Config.AccessoryFits = Config.AccessoryFits or {}

local function number(value, limit)
    return type(value) == 'number' and value == value and math.abs(value) <= limit
end

-- Plain tables keep saved fits portable between the server and all observers.
function ValidatePetAccessoryFit(value)
    if type(value) ~= 'table' then return end
    for _, field in ipairs({'offset', 'rot'}) do
        local kind = type(value[field])
        if kind ~= 'table' and kind ~= 'vector3' then return end
    end
    if value.pedRotation ~= nil and type(value.pedRotation) ~= 'boolean' then return end
    local bone = value.bone
    if type(bone) == 'number' then
        if not number(bone, 65535) or bone < 0 or bone % 1 ~= 0 then return end
    elseif type(bone) ~= 'string' or #bone == 0 or #bone > 64 then return end
    local fit = { bone = bone, offset = {}, rot = {}, rotationOrder = value.rotationOrder == nil and 0 or value.rotationOrder,
        pedRotation = value.pedRotation ~= false }
    if not number(fit.rotationOrder, 5) or fit.rotationOrder < 0 or fit.rotationOrder % 1 ~= 0 then return end
    for _, axis in ipairs({'x','y','z'}) do
        if not number(value.offset[axis], 5) or not number(value.rot[axis], 3600) then return end
        fit.offset[axis] = value.offset[axis]
        fit.rot[axis] = (value.rot[axis] + 180) % 360 - 180
    end
    return fit
end

function GetPetAccessoryFit(model, item)
    local definition = ((Config.AddonAccessories or {})[model] or {})[item]
    if not definition or definition.componentId then return end
    local override = (Config.AccessoryFits[model] or {})[item]
    return ValidatePetAccessoryFit(override or definition)
end

function PetAccessoryFitKey(fit)
    return ('%s:%.6f:%.6f:%.6f:%.6f:%.6f:%.6f:%s:%s'):format(fit.bone,
        fit.offset.x, fit.offset.y, fit.offset.z, fit.rot.x, fit.rot.y, fit.rot.z,
        fit.rotationOrder, tostring(fit.pedRotation))
end
