local ped
local claiming = false

local function notify(text, kind)
    if text then exports.qbx_core:Notify(text, kind or 'inform') end
end

local function claim()
    if claiming then return end
    claiming = true

    if lib.callback.await('f_starterpack:status', false) then
        notify(Config.Text.already, 'error')
        claiming = false
        return
    end

    local alert = lib.alertDialog({
        header = Config.Welcome.title,
        content = Config.Welcome.message,
        centered = true,
        cancel = true,
        size = 'xl',
        labels = { confirm = 'Ambil Starterpack', cancel = 'Nanti' },
    })

    if alert ~= 'confirm' or not lib.progressCircle({
            duration = 3000,
            position = 'bottom',
            label = 'Menerima starterpack...',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = { dict = 'mp_common', clip = 'givetake1_a' },
        }) then
        notify(Config.Text.canceled)
        claiming = false
        return
    end

    local ok, msg = lib.callback.await('f_starterpack:claim', false)
    notify(msg, ok and 'success' or 'error')
    claiming = false
end

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
    ped = CreatePed(4, model, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.coords.w, false, true)
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
            onSelect = claim,
            canInteract = function()
                return not cache.vehicle and not claiming and not lib.progressActive()
            end,
        },
    })
end

function point:onExit()
    removePed()
end

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then removePed() end
end)
