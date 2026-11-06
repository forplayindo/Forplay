local fitting
local showFit

local function notify(message, kind)
    lib.notify({description = message, type = kind or 'inform'})
end

local function putFit(session, fit)
    Config.AccessoryFits[session.model] = Config.AccessoryFits[session.model] or {}
    Config.AccessoryFits[session.model][session.item] = fit
end

function CancelPetAccessoryFitting()
    if not fitting then return end
    local session = fitting
    fitting = nil
    putFit(session, session.original)
    if session.dialog then lib.closeInputDialog() end
    lib.hideContext(false)
    SyncPetVisuals()
end

local function available(session)
    if fitting ~= session then return false end
    local pet = GetPetByNetId(session.netId)
    local equipped = false
    for _, item in pairs(pet and pet.accessories or {}) do
        if item == session.item then equipped = true; break end
    end
    local entity = NetworkDoesNetworkIdExist(session.netId) and NetworkGetEntityFromNetworkId(session.netId) or 0
    if not pet or pet.owner ~= GetIdentifier() or not equipped or entity == 0 or not DoesEntityExist(entity)
        or #(GetEntityCoords(entity) - GetEntityCoords(PlayerPedId())) > 5.0 then
        CancelPetAccessoryFitting()
        return false
    end
    return entity
end

local function preview(session, value)
    local entity = available(session)
    if not entity then return end
    local fit = ValidatePetAccessoryFit(value)
    local bone = fit and PetAccessoryBone(entity, fit.bone)
    if not fit or not bone or bone < 0 then
        notify('Invalid fit or attachment bone for this animal.', 'error')
    else
        session.fit = fit
        putFit(session, fit)
        SyncPetVisuals()
    end
    showFit(session)
end

local function input(session, title, rows)
    session.dialog = true
    local result = lib.inputDialog(title, rows)
    session.dialog = false
    return result
end

local function editAxes(session, field)
    if not available(session) then return end
    local position = field == 'offset'
    local rows = {}
    for _, axis in ipairs({'x', 'y', 'z'}) do
        rows[#rows+1] = {type = 'number', label = axis:upper() .. (position and ' (metres)' or ' (degrees)'),
            default = session.fit[field][axis], precision = position and 3 or 1,
            step = position and 0.005 or 1, min = position and -5 or -360, max = position and 5 or 360, required = true}
    end
    local result = input(session, position and 'Accessory position' or 'Accessory rotation', rows)
    if not result then if available(session) then showFit(session) end; return end
    local value = ValidatePetAccessoryFit(session.fit)
    value[field] = {x = result[1], y = result[2], z = result[3]}
    preview(session, value)
end

showFit = function(session)
    if not available(session) then return end
    lib.registerContext({id = 'electus_pet_fit', title = session.item .. ' / ' .. session.model,
        onExit = CancelPetAccessoryFitting,
        options = {
            {title = 'Position', description = 'Adjust attachment offsets and preview.', onSelect = function() editAxes(session, 'offset') end},
            {title = 'Rotation', description = 'Adjust pitch, roll and yaw and preview.', onSelect = function() editAxes(session, 'rot') end},
            {title = 'Attachment bone', description = tostring(session.fit.bone), onSelect = function()
                if not available(session) then return end
                local result = input(session, 'Attachment bone', {{type = 'input', label = 'Bone ID or bone name',
                    default = tostring(session.fit.bone), required = true}})
                if not result then if available(session) then showFit(session) end; return end
                local value = ValidatePetAccessoryFit(session.fit)
                value.bone = tonumber(result[1]) or result[1]
                preview(session, value)
            end},
            {title = 'Rotation settings', onSelect = function()
                if not available(session) then return end
                local result = input(session, 'Rotation settings', {
                    {type = 'select', label = 'Rotation order', default = tostring(session.fit.rotationOrder), required = true, options = {
                        {value='0',label='ZYX (0)'},{value='1',label='YZX (1)'},{value='2',label='ZXY (2)'},
                        {value='3',label='XZY (3)'},{value='4',label='YXZ (4)'},{value='5',label='XYZ (5)'}}},
                    {type = 'checkbox', label = 'Full ped rotation', checked = session.fit.pedRotation}})
                if not result then if available(session) then showFit(session) end; return end
                local value = ValidatePetAccessoryFit(session.fit)
                value.rotationOrder, value.pedRotation = tonumber(result[1]), result[2] == true
                preview(session, value)
            end},
            {title = 'Save for this animal model', description = 'Applies this item fit to everyone and survives restarts.', onSelect = function()
                if not available(session) or session.saving then return end
                session.saving = true
                local ok, saved = pcall(lib.callback.await, 'electus_pets:saveAccessoryFit', false,
                    session.netId, session.item, session.fit)
                session.saving = false
                if ok and saved == true then
                    -- Keep the saved fit even if the broadcast has not arrived yet.
                    if fitting == session then fitting = nil; putFit(session, session.fit) end
                    notify('Accessory fit saved for ' .. session.model .. '.', 'success')
                else
                    notify('Fit could not be saved. Check permission and stay beside your pet.', 'error')
                    if available(session) then showFit(session) end
                end
            end},
            {title = 'Cancel and revert', onSelect = CancelPetAccessoryFitting}
        }})
    lib.showContext('electus_pet_fit')
end

RegisterNetEvent('electus_pets:openAccessoryFitter', function()
    CancelPetAccessoryFitting()
    local distance, index = GetClosestPet()
    local pet = CurrentPets[index]
    if not pet or distance > 3.0 or not pet.netId then notify('Stand beside your equipped pet first.', 'error'); return end
    local options = {}
    for slot, item in pairs(pet.accessories or {}) do
        local fit = GetPetAccessoryFit(pet.model, item)
        if fit then
            options[#options+1] = {title = slot .. ': ' .. item, onSelect = function()
                local original = (Config.AccessoryFits[pet.model] or {})[item]
                local session = {netId = pet.netId, model = pet.model, item = item,
                    original = original and ValidatePetAccessoryFit(original), fit = GetPetAccessoryFit(pet.model, item)}
                fitting = session
                showFit(session)
            end}
        end
    end
    if #options == 0 then notify('Equip a supported prop accessory before fitting.', 'error'); return end
    lib.registerContext({id = 'electus_pet_fit_items', title = 'Fit accessories: ' .. pet.name, options = options})
    lib.showContext('electus_pet_fit_items')
end)

local function sameFit(a, b)
    return a == nil and b == nil or a and b and PetAccessoryFitKey(a) == PetAccessoryFitKey(b)
end

RegisterNetEvent('electus_pets:accessoryFits', function(values)
    if type(values) ~= 'table' then return end
    local fits = {}
    for model, items in pairs(values) do
        local definitions = (Config.AddonAccessories or {})[model]
        if definitions and type(items) == 'table' then
            for item, value in pairs(items) do
                local definition = definitions[item]
                local fit = definition and not definition.componentId and ValidatePetAccessoryFit(value)
                if fit then fits[model] = fits[model] or {}; fits[model][item] = fit end
            end
        end
    end
    local session = fitting
    local preserve = session and sameFit((fits[session.model] or {})[session.item], session.original)
    Config.AccessoryFits = fits
    if session then
        if preserve then putFit(session, session.fit)
        else
            fitting = nil
            if session.dialog then lib.closeInputDialog() end
            lib.hideContext(false)
        end
    end
    SyncPetVisuals()
end)

-- The existing visual sync loop cancels previews when a pet leaves or changes character.
function CheckPetAccessoryFitting()
    if fitting then available(fitting) end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then CancelPetAccessoryFitting() end
end)
