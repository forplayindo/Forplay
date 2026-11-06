local banking = require 'shared.banking'
local open = false
local spot -- lokasi pencairan yang sedang dibuka: { kind = 'atm', pos = vec3 } / { kind = 'bank' }

---------------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------------
local function closeNui()
    if not open then return end
    open = false
    spot = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openNui(where)
    if open then return end
    local data = lib.callback.await('f_paycheck:get', false, where)
    if not data then
        return lib.notify({ type = 'error', description = 'Kamu terlalu jauh dari ATM / bank.' })
    end
    data.label = where.kind == 'atm' and 'ATM' or 'Bank'
    open = true
    spot = where
    SendNUIMessage({ action = 'open', data = data })
    SetNuiFocus(true, true)
end

RegisterNUICallback('close', function(_, cb)
    closeNui()
    cb(1)
end)

RegisterNUICallback('withdraw', function(data, cb)
    local res = lib.callback.await('f_paycheck:withdraw', false, data.method, spot) or { ok = false, msg = 'Server tidak merespons.' }
    if res.ok then
        closeNui()
        lib.notify({ type = 'success', title = 'Paycheck Dicairkan', description = 'Rincian dikirim ke Email kamu.', icon = 'envelope' })
    end
    cb(res)
end)

---------------------------------------------------------------------------
-- ox_target: opsi "Ambil Gaji" terpisah dari Buka ATM / Buka Bank
---------------------------------------------------------------------------
local function atBank(entity)
    local pos = GetEntityCoords(entity).xy
    for i = 1, #banking.banks do
        if #(pos - banking.banks[i].xy) <= 2.0 then return true end
    end
    return false
end

CreateThread(function()
    if #banking.atms > 0 then
        exports.ox_target:addModel(banking.atms, {{
            name = 'f_paycheck_atm', icon = 'fas fa-money-check-dollar', label = 'Ambil Gaji',
            distance = 2.5,
            onSelect = function(data) openNui({ kind = 'atm', pos = GetEntityCoords(data.entity) }) end,
        }})
    end
    if #banking.pedModels > 0 then
        -- model ped bank juga bisa dipakai NPC lain, jadi hanya aktif di titik NPC bank
        exports.ox_target:addModel(banking.pedModels, {{
            name = 'f_paycheck_bank', icon = 'fas fa-money-check-dollar', label = 'Ambil Gaji',
            distance = 4.5,
            canInteract = atBank,
            onSelect = function() openNui({ kind = 'bank' }) end,
        }})
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    closeNui()
    exports.ox_target:removeModel(banking.atms, 'f_paycheck_atm')
    exports.ox_target:removeModel(banking.pedModels, 'f_paycheck_bank')
end)
