-- Overrides are deliberately separate from shipped defaults and scoped to one model/item.
local path = 'data/accessory_fits.json'

local function propDefinition(model, item)
    local definition = ((Config.AddonAccessories or {})[model] or {})[item]
    return definition and not definition.componentId and definition
end

local saved = LoadResourceFile(GetCurrentResourceName(), path)
if saved then
    local decoded = EP.decode(saved, {})
    for model, items in pairs(decoded) do
        if type(items) == 'table' then
            for item, value in pairs(items) do
                local fit = propDefinition(model, item) and ValidatePetAccessoryFit(value)
                if fit then
                    Config.AccessoryFits[model] = Config.AccessoryFits[model] or {}
                    Config.AccessoryFits[model][item] = fit
                end
            end
        end
    end
end

RegisterCommand('petfit', function(src)
    if src == 0 then print('Use /petfit in game beside your equipped pet.'); return end
    TriggerClientEvent('electus_pets:openAccessoryFitter', src)
end, true)

EP.registerCallback('electus_pets:saveAccessoryFit', function(src, netId, item, value)
    if not IsPlayerAceAllowed(src, 'command.petfit') then return false end
    local entry = EP.activePets[tonumber(netId)]
    if not entry or not entry.ready or entry.owner ~= EP.identifier(src)
        or type(item) ~= 'string' or not DoesEntityExist(entry.entity)
        or GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(entry.entity)
        or not EP.near(src, GetEntityCoords(entry.entity), 5.0) then return false end
    local model, equipped = entry.pet.model, false
    for _, accessory in pairs(entry.pet.accessories or {}) do
        if accessory == item then equipped = true; break end
    end
    local fit = equipped and propDefinition(model, item) and ValidatePetAccessoryFit(value)
    if not fit then return false end
    Config.AccessoryFits[model] = Config.AccessoryFits[model] or {}
    local previous = Config.AccessoryFits[model][item]
    Config.AccessoryFits[model][item] = fit
    local ok, written = pcall(SaveResourceFile, GetCurrentResourceName(), path, json.encode(Config.AccessoryFits), -1)
    if not ok or not written then
        Config.AccessoryFits[model][item] = previous
        return false
    end
    TriggerClientEvent('electus_pets:accessoryFits', -1, Config.AccessoryFits)
    return true
end)
