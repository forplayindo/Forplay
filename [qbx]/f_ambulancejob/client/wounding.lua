-- Item yang dipakai SENDIRI dari ox_inventory (client export di ox_inventory data/items.lua).
-- Mengobati orang lain hanya bisa lewat panel Cek Pasien (EMS).
local config = require 'config.client'
local treatment = require 'config.treatment'
local painkillerAmount = 0

local function progress(duration, label)
    return lib.progressCircle({
        duration = duration,
        position = 'bottom',
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, car = false, combat = true, mouse = false },
        anim = { dict = 'mp_suicide', clip = 'pill' },
    })
end

---Darah (0-100) naik sedikit, tapi di bawah batas kritis hanya sampai batas kritis.
local function raiseOwnBlood(amount)
    local current = math.max(0, GetEntityHealth(cache.ped) - 100)
    local cap = current < treatment.blood.critical and treatment.blood.critical or 100
    local new = math.min(cap, current + amount)
    if new > current then SetEntityHealth(cache.ped, 100 + new) end
end

local function startPainkiller()
    OnPainKillers = true
    exports.f_medical:DisableDamageEffects()
    if painkillerAmount < 3 then painkillerAmount += 1 end
end

exports('useBandage', function(data)
    if exports.f_medical:IsDead() or exports.f_medical:IsLaststand() then return end
    if not progress(4000, 'Memasang bandage...') then
        return exports.qbx_core:Notify(locale('error.canceled'), 'error')
    end
    exports.ox_inventory:useItem(data, function(used)
        if not used then return end
        raiseOwnBlood(10)
        -- perban sendiri hanya menahan pendarahan ringan; pendarahan berat tetap butuh EMS
        if (LocalPlayer.state['f_medical:bleedLevel'] or 0) < treatment.heavyBleed then
            exports.f_medical:RemoveBleed(1)
        end
    end)
end)

exports('usePainkillers', function(data)
    if exports.f_medical:IsDead() or exports.f_medical:IsLaststand() then return end
    if not progress(3000, 'Minum painkillers...') then
        return exports.qbx_core:Notify(locale('error.canceled'), 'error')
    end
    exports.ox_inventory:useItem(data, function(used)
        if used then startPainkiller() end
    end)
end)

exports('useCalmPills', function(data)
    if exports.f_medical:IsDead() or exports.f_medical:IsLaststand() then return end
    if not progress(3000, 'Minum calming pills...') then
        return exports.qbx_core:Notify(locale('error.canceled'), 'error')
    end
    -- cooldown & penurunan stress diputuskan server (server export f_ambulancejob.calmPills)
    exports.ox_inventory:useItem(data)
end)

-- efek samping ringan obat penenang: pandangan sedikit kabur
RegisterNetEvent('f_ambulancejob:client:calmEffect', function()
    if GetInvokingResource() then return end
    exports.qbx_core:Notify('Kamu merasa lebih tenang', 'success')
    AnimpostfxPlay('DrugsMichaelAliensFightIn', 0, false)
    SetTimeout(3000, function()
        AnimpostfxStop('DrugsMichaelAliensFightIn')
        AnimpostfxPlay('DrugsMichaelAliensFightOut', 0, false)
        SetTimeout(7000, function() AnimpostfxStop('DrugsMichaelAliensFightOut') end)
    end)
end)

-- Painkiller yang diberikan EMS lewat panel (dipicu server).
RegisterNetEvent('f_ambulancejob:client:painkillerEffect', function()
    if GetInvokingResource() then return end
    startPainkiller()
    exports.qbx_core:Notify('Rasa nyeri berkurang', 'success')
end)

local function consumePainKiller()
    painkillerAmount -= 1
    Wait(config.painkillerInterval * 1000)
    if painkillerAmount > 0 then return end
    painkillerAmount = 0
    OnPainKillers = false
    exports.f_medical:EnableDamageEffects()
end

CreateThread(function()
    while true do
        Wait(1)
        if OnPainKillers then
            consumePainKiller()
        else
            Wait(3000)
        end
    end
end)
