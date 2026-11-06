-- /fotokendaraan: one-time photos for addon vehicles, saved to images/<model>.webp.
-- Admin only; nothing here runs for normal players.
local config = require 'config'
local RES = GetCurrentResourceName()
local MAX_BYTES = 1024 * 1024

local sessions = {} -- [src] = { [model] = true }

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local B64_INDEX = {}
for i = 1, #B64 do B64_INDEX[B64:byte(i)] = i - 1 end

local function base64Decode(data)
    data = data:gsub('[^%w%+/]', '')
    local out, n = {}, 0
    for i = 1, #data, 4 do
        local a, b, c, d = data:byte(i, i + 3)
        a, b = B64_INDEX[a] or 0, B64_INDEX[b] or 0
        local triple = (a << 18) | (b << 12) | ((c and B64_INDEX[c] or 0) << 6) | (d and B64_INDEX[d] or 0)
        n += 1
        if not c then
            out[n] = string.char((triple >> 16) & 0xFF)
        elseif not d then
            out[n] = string.char((triple >> 16) & 0xFF, (triple >> 8) & 0xFF)
        else
            out[n] = string.char((triple >> 16) & 0xFF, (triple >> 8) & 0xFF, triple & 0xFF)
        end
    end
    return table.concat(out)
end

lib.addCommand('fotokendaraan', {
    help = 'Foto kendaraan addon dengan latar transparan (model1 model2 ... atau "addon")',
    restricted = 'group.admin',
}, function(src, _, raw)
    if src <= 0 then return end
    if GetResourceState('screencapture') ~= 'started' then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Resource screencapture tidak berjalan.' })
    end

    local models = {}
    for word in raw:gmatch('%S+') do
        if word ~= 'fotokendaraan' and word ~= '/fotokendaraan' then
            if word == 'addon' then
                for _, m in ipairs(config.addonVehicles) do models[#models + 1] = m:lower() end
            elseif word:match('^[%w_]+$') then
                models[#models + 1] = word:lower()
            end
        end
    end
    if #models == 0 then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Tulis nama model, atau isi addonVehicles di config f_vehimages lalu pakai /fotokendaraan addon' })
    end

    local allowed = {}
    for _, m in ipairs(models) do allowed[m] = true end
    sessions[src] = allowed
    TriggerClientEvent('f_vehimages:start', src, models)
end)

RegisterNetEvent('f_vehimages:save', function(model, data)
    local src = source
    local session = sessions[src]
    local ok = false
    if session and type(model) == 'string' and session[model] and type(data) == 'string' and #data < MAX_BYTES * 2 then
        session[model] = nil
        local binary = base64Decode(data:gsub('^data:[^,]*,', ''))
        -- only accept a real webp file
        if #binary > 100 and #binary <= MAX_BYTES and binary:sub(1, 4) == 'RIFF' and binary:sub(9, 12) == 'WEBP' then
            ok = SaveResourceFile(RES, ('images/%s.webp'):format(model), binary, #binary) == true
        end
    end
    TriggerClientEvent('f_vehimages:saved', src, model, ok)
end)

RegisterNetEvent('f_vehimages:done', function()
    local src = source
    if not sessions[src] then return end
    sessions[src] = nil
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success', duration = 10000,
        description = 'Foto kendaraan selesai. Jalankan "ensure f_vehimages" agar foto baru terbaca.',
    })
end)

AddEventHandler('playerDropped', function() sessions[source] = nil end)
