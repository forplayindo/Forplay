-- Patch f_crew: channel radio gang buatan pemain didaftarkan saat server jalan (nama channel,
-- pembatasan, favorit). Kunci sebenarnya ada di server (pma-voice addChannelCheck di f_crew).

local function apply(channel, gangName, label)
    if type(channel) ~= 'number' then return end
    local key = tostring(channel)
    if gangName then
        Shared.RestrictedChannels[channel] = { type = 'gang', name = { gangName } }
        Shared.RadioNames[key] = label
        Shared.RadioNames[key .. '.%'] = label
    else
        Shared.RestrictedChannels[channel] = nil
        Shared.RadioNames[key] = nil
        Shared.RadioNames[key .. '.%'] = nil
    end
end

local function refreshRadio()
    if Radio.playerLoaded then Radio:Init() end
end

local function sync()
    if GetResourceState('f_crew') ~= 'started' then return end
    local list = lib.callback.await('f_crew:server:radioChannels', false)
    if type(list) ~= 'table' then return end
    for i = 1, #list do apply(list[i][1], list[i][2], list[i][3]) end
    refreshRadio()
end

RegisterNetEvent('f_crew:client:radioChannel', function(channel, gangName, label)
    apply(channel, gangName, label)
    refreshRadio()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    CreateThread(sync)
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() or res == 'f_crew' then
        if LocalPlayer.state.isLoggedIn then CreateThread(sync) end
    end
end)
