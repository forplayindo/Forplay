-- Model ATM + koordinat NPC bank dibaca langsung dari config f_banking,
-- jadi f_banking tidak perlu dipatch dan lokasi selalu sama dengan bank.
local result = { atms = {}, banks = {}, pedModels = {} }

local code = LoadResourceFile('f_banking', 'config.lua')
if not code then
    lib.print.error('config.lua f_banking tidak ditemukan, Ambil Gaji di ATM/Bank nonaktif')
    return result
end

-- lib.locale() di config bank tidak boleh jalan di resource ini
local env = setmetatable({ lib = { locale = function() end } }, { __index = _G })
local chunk, err = load(code, '@f_banking/config.lua', 't', env)
local ok = chunk and pcall(chunk)
local bank = ok and env.Config
if not bank then
    lib.print.error(('Gagal membaca config f_banking: %s'):format(err or 'error saat dijalankan'))
    return result
end

result.atms = bank.atms or {}

local seen = {}
for i = 1, #(bank.peds or {}) do
    local ped = bank.peds[i]
    result.banks[#result.banks + 1] = ped.coords.xyz
    local model = type(ped.model) == 'string' and joaat(ped.model) or ped.model
    if not seen[model] then
        seen[model] = true
        result.pedModels[#result.pedModels + 1] = model
    end
end

return result
