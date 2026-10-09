-- f_phone: turunan sd-phone dengan layout iPhone Duo.
--
-- Kompatibilitas: script pihak ketiga yang ditulis untuk sd-phone memanggil exports['sd-phone'].
-- Script server ini sendiri sudah memakai exports['f_phone']. `provide` di fxmanifest tidak meneruskan export, jadi setiap export yang
-- didaftarkan resource ini juga didaftarkan atas nama 'sd-phone' - cara yang sama dengan yang dipakai
-- sd-phone untuk lb-phone (event __cfx_export_<resource>_<nama>).
--
-- Jangan jalankan sd-phone dan f_phone bersamaan: keduanya akan berebut nama export ini.

local ALIAS = 'sd-phone'
if GetCurrentResourceName() == ALIAS then return end

-- Resource lain menyimpan (cache) referensi fungsi export per NAMA resource, dan cache itu hanya
-- dibuang saat resource dengan nama itu berhenti. Saat f_phone di-restart, cache 'sd-phone' di
-- resource lain (f_crew dll.) masih menunjuk ke f_phone yang lama -> error "Execution of function
-- reference in script host failed". Jadi saat f_phone berhenti, umumkan juga 'sd-phone' berhenti.
local STOP_EVENT = IsDuplicityVersion() and 'onResourceStop' or 'onClientResourceStop'
AddEventHandler(STOP_EVENT, function(res)
    if res == GetCurrentResourceName() then TriggerEvent(STOP_EVENT, ALIAS) end
end)

local real = exports
exports = setmetatable({}, {
    __index = function(_, resource) return real[resource] end,
    __newindex = function(_, resource, value) real[resource] = value end,
    __call = function(_, name, fn)
        real(name, fn)
        AddEventHandler(('__cfx_export_%s_%s'):format(ALIAS, name), function(setCB)
            setCB(fn)
        end)
    end,
})
