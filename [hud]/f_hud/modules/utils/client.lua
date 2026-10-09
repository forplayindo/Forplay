---
--[[ Contains client-side helper functions. ]]
---

local Utils = {}

--- Custom notifications with options.
---@param title string
---@param type 'inform'|'error'|'success'|'warning'
---@param duration number
---@param description string
function Utils.Notify(title, type, duration, description)
    lib.notify({
        title = title,
        description = description,
        duration = duration,
        position = 'center-right',
        type = type,
    })
end

-- Retrieves the fuel level of a vehicle from various possible fuel resources
---@param vehicle number vehicle
---@return integer FuelLevel
local fuelResource = nil
local function detectFuelResource()
    for _, res in ipairs({ 'ox_fuel', 'LegacyFuel', 'cdn-fuel', 'ps-fuel' }) do
        if GetResourceState(res) == 'started' then return res end
    end
    return false
end
AddEventHandler('onClientResourceStart', function() fuelResource = nil end)
AddEventHandler('onClientResourceStop', function() fuelResource = nil end)

function Utils.GetVehicleFuelLevel(vehicle)
    if fuelResource == nil then fuelResource = detectFuelResource() end
    local level = 0
    if fuelResource == 'ox_fuel' then
        level = Entity(vehicle)?.state?.fuel or 0
    elseif fuelResource then
        level = exports[fuelResource]:GetFuel(vehicle)
    else
        level = GetVehicleFuelLevel(vehicle)
    end
    return math.floor(level or 0)
end

return Utils
