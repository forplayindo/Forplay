local RESOURCE = GetCurrentResourceName()
local isOpen = false
local currentTab = 'overview'

local function setNui(open, tab)
    isOpen = open
    if tab then currentTab = tab end

    SetNuiFocus(open, open)
    SetNuiFocusKeepInput(false)

    if open then
        SendNUIMessage({
            action = 'open',
            resourceName = RESOURCE,
            tab = currentTab,
        })
    else
        SendNUIMessage({ action = 'close' })
    end
end

CreateThread(function()
    while true do
        if isOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 3, true)
            DisableControlAction(0, 4, true)
            DisableControlAction(0, 5, true)
            DisableControlAction(0, 6, true)

            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 68, true)
            DisableControlAction(0, 69, true)
            DisableControlAction(0, 92, true)
            DisableControlAction(0, 106, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)

            Wait(0)
        else
            Wait(250)
        end
    end
end)

local function requestOpen(tab)
    TriggerServerEvent('economy_dashboard:requestOpen', tab or 'overview')
end

local function requestRefresh(tab, payload)
    TriggerServerEvent('economy_dashboard:refreshData', tab or currentTab, payload or {})
end

RegisterNetEvent('economy_dashboard:notify', function(message, msgType)
    message = tostring(message or '')
    msgType = tostring(msgType or 'info')

    print(('[Economy Dashboard] %s'):format(message))

    local color = { 0, 212, 255 }
    if msgType == 'error' then color = { 255, 82, 82 } end
    if msgType == 'warning' then color = { 255, 149, 0 } end
    if msgType == 'success' then color = { 0, 230, 118 } end

    TriggerEvent('chat:addMessage', {
        color = color,
        multiline = true,
        args = { 'EconomyDash', message }
    })
end)

RegisterCommand(Config.OpenCommand or 'economydash', function()
    requestOpen('overview')
end, false)

if Config.OpenKey and Config.OpenKey ~= '' then
    RegisterKeyMapping('+economydash', 'Open Economy Dashboard', 'keyboard', Config.OpenKey)
    RegisterCommand('+economydash', function()
        requestOpen('overview')
    end, false)
    RegisterCommand('-economydash', function() end, false)
end

RegisterNetEvent('economy_dashboard:clientOpen', function(tab)
    setNui(true, tab or 'overview')
    requestRefresh(tab or 'overview', {})
end)

RegisterNetEvent('economy_dashboard:clientClose', function()
    if isOpen then
        setNui(false)
    end
end)

RegisterNetEvent('economy_dashboard:nuiMessage', function(msg)
    if type(msg) == 'table' then
        SendNUIMessage(msg)
    end
end)

RegisterNUICallback('close', function(_, cb)
    setNui(false)
    TriggerServerEvent('economy_dashboard:uiClosed')
    cb({ ok = true })
end)

RegisterNUICallback('changeTab', function(data, cb)
    currentTab = data and data.tab or currentTab
    cb({ ok = true })
end)

RegisterNUICallback('refreshData', function(data, cb)
    local tab = data and data.tab or currentTab
    requestRefresh(tab, data or {})
    cb({ ok = true })
end)

RegisterNUICallback('searchPlayers', function(data, cb)
    TriggerServerEvent('economy_dashboard:nui', 'searchPlayers', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('getPlayerProfile', function(data, cb)
    TriggerServerEvent('economy_dashboard:nui', 'getPlayerProfile', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('updateAlertStatus', function(data, cb)
    TriggerServerEvent('economy_dashboard:nui', 'updateAlertStatus', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('adminSearchPlayers', function(data, cb)
    TriggerServerEvent('economy_dashboard:nui', 'adminSearchPlayers', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('adminAddMoney', function(data, cb)
    TriggerServerEvent('economy_dashboard:nui', 'adminAddMoney', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('adminRemoveMoney', function(data, cb)
    TriggerServerEvent('economy_dashboard:nui', 'adminRemoveMoney', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('adminSetMoney', function(data, cb)
    TriggerServerEvent('economy_dashboard:nui', 'adminSetMoney', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('adminBulkWipeDirty', function(data, cb)
    TriggerServerEvent('economy_dashboard:nui', 'adminBulkWipeDirty', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('exportData', function(data, cb)
    TriggerServerEvent('economy_dashboard:nui', 'exportData', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('testDiscordWebhook', function(data, cb)
    TriggerServerEvent('economy_dashboard:nui', 'testDiscordWebhook', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('getInflationBasket', function(data, cb)
    TriggerServerEvent('economy_dashboard:nui', 'getInflationBasket', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('logPrices', function(data, cb)
    TriggerServerEvent('economy_dashboard:nui', 'logPrices', data or {})
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RESOURCE then return end
    if isOpen then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end)

