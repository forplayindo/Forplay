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

-- Keep the legacy option shape while using ox_target's native API.
PetTarget = {}
local function options(data)
    local out = {}
    for i, entry in ipairs(data.options or {}) do
        out[i] = { name = entry.name or entry.label, label = entry.label, icon = entry.icon,
            distance = data.distance or 2.5, canInteract = entry.canInteract,
            onSelect = function(selected)
                if entry.action then return entry.action(selected.entity) end
                if entry.event then
                    local payload = {}
                    for key, value in pairs(entry) do payload[key] = value end
                    payload.entity = selected.entity
                    TriggerEvent(entry.event, payload)
                end
            end }
    end
    return out
end
function PetTarget:AddTargetEntity(entity, data)
    if Config.TargetSystem == 'ox_target' then return exports.ox_target:addLocalEntity(entity, options(data)) end
    if Config.TargetSystem ~= 'none' then return exports[Config.TargetSystem]:AddTargetEntity(entity, data) end
end
function PetTarget:RemoveTargetEntity(entity, labels)
    if Config.TargetSystem == 'ox_target' then return exports.ox_target:removeLocalEntity(entity, labels) end
    if Config.TargetSystem ~= 'none' then return exports[Config.TargetSystem]:RemoveTargetEntity(entity, labels) end
end
function PetTarget:AddTargetModel(models, data)
    if Config.TargetSystem == 'ox_target' then return exports.ox_target:addModel(models, options(data)) end
    if Config.TargetSystem ~= 'none' then return exports[Config.TargetSystem]:AddTargetModel(models, data) end
end
function PetTarget:RemoveTargetModel(models, labels)
    if Config.TargetSystem == 'ox_target' then return exports.ox_target:removeModel(models, labels) end
    if Config.TargetSystem ~= 'none' then return exports[Config.TargetSystem]:RemoveTargetModel(models, labels) end
end
