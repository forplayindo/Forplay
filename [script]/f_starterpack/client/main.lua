local ped
local open = false

local function closeUi()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openUi()
    if open then return end
    local data = lib.callback.await('f_starterpack:info', false)
    if not data then return end
    open = true
    SendNUIMessage({ action = 'open', data = data })
    SetNuiFocus(true, true)
end

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb({})
end)

RegisterNUICallback('claim', function(_, cb)
    local ok, msg = lib.callback.await('f_starterpack:claim', false)
    cb({ ok = ok, msg = msg })
    if ok then
        closeUi()
        exports.qbx_core:Notify(msg, 'success')
    end
end)

local function removePed()
    if not ped then return end
    exports.ox_target:removeLocalEntity(ped, 'f_starterpack')
    DeleteEntity(ped)
    ped = nil
end

local point = lib.points.new({ coords = Config.Ped.coords.xyz, distance = 40.0 })

function point:onEnter()
    if ped then return end
    local cfg = Config.Ped
    local model = joaat(cfg.model)
    lib.requestModel(model)
    ped = CreatePed(4, model, cfg.coords.x, cfg.coords.y, cfg.coords.z, cfg.coords.w, false, true)
    SetModelAsNoLongerNeeded(model)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    if cfg.scenario then TaskStartScenarioInPlace(ped, cfg.scenario, 0, true) end

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'f_starterpack',
            icon = cfg.icon,
            label = cfg.label,
            distance = cfg.distance,
            onSelect = openUi,
            canInteract = function()
                return not cache.vehicle and not open
            end,
        },
    })
end

function point:onExit()
    closeUi()
    removePed()
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    closeUi()
    removePed()
end)
