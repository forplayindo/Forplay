local config = require 'config.server'
local sharedConfig = require 'config.shared'
local startedRegister = {}
local startedSafe = {}
local safeCodes = {}

local function getClosestRegister(coords)
    local closestRegisterIndex
    for i = 1, #sharedConfig.registers do
        if #(coords - sharedConfig.registers[i].coords) <= 2 then
            if closestRegisterIndex then
                if #(coords - sharedConfig.registers[i].coords) < #(coords - sharedConfig.registers[closestRegisterIndex].coords) then
                    closestRegisterIndex = i
                end
            else
                closestRegisterIndex = i
            end
        end
    end
    return closestRegisterIndex
end

local function getClosestSafe(coords)
    local closestSafeIndex
    for i = 1, #sharedConfig.safes do
        if #(coords - sharedConfig.safes[i].coords) <= 2 then
            closestSafeIndex = i
        end
    end
    return closestSafeIndex
end

RegisterNetEvent('f_storerobbery:server:checkStatus', function()
    local coords = GetEntityCoords(GetPlayerPed(source))
    local closestRegisterIndex = getClosestRegister(coords)
    if not closestRegisterIndex then return end

    local hasLockpick = exports.ox_inventory:Search(source, 'count', 'lockpick') > 0
    local hasAdvanced = exports.ox_inventory:Search(source, 'count', 'advancedlockpick') > 0

    if hasLockpick then
        TriggerClientEvent('f_storerobbery:client:initRegisterAttempt', source, false)
    elseif hasAdvanced then
        TriggerClientEvent('f_storerobbery:client:initRegisterAttempt', source, true)
    else
        exports.qbx_core:Notify(source, 'Kamu tidak punya alat yang dibutuhkan', 'error')
    end

    startedRegister[source] = true
    sharedConfig.registers[closestRegisterIndex].robbed = true
end)

RegisterNetEvent('f_storerobbery:server:registerFailed', function(isUsingAdvanced)
    local coords = GetEntityCoords(GetPlayerPed(source))
    local closestRegisterIndex = getClosestRegister(coords)
    local removalChance = isUsingAdvanced and math.random(0, 30) or math.random(0, 60)

    startedRegister[source] = false
    sharedConfig.registers[closestRegisterIndex].robbed = false
    if removalChance > math.random(0, 100) then
        exports.qbx_core:Notify(source, locale('error.lockpick_broken'), 'error')
        if isUsingAdvanced then
            exports.ox_inventory:RemoveItem(source, 'advancedlockpick', 1)
        else
            exports.ox_inventory:RemoveItem(source, 'lockpick', 1)
        end
    end
end)

RegisterNetEvent('f_storerobbery:server:registerExited', function()
    local coords = GetEntityCoords(GetPlayerPed(source))
    local closestRegisterIndex = getClosestRegister(coords)
    startedRegister[source] = false
    sharedConfig.registers[closestRegisterIndex].robbed = false
end)

RegisterNetEvent('f_storerobbery:server:registerCanceled', function()
    startedRegister[source] = false
    TriggerClientEvent('f_storerobbery:client:updatedRobbables', -1, sharedConfig.registers, sharedConfig.safes)
end)

RegisterNetEvent('f_storerobbery:server:registerOpened', function(isDone)
    if not isDone then return end
    local coords = GetEntityCoords(GetPlayerPed(source))
    local closestRegisterIndex = getClosestRegister(coords)

    if not closestRegisterIndex then return end
    if #(coords - sharedConfig.registers[closestRegisterIndex].coords) > 2 then return end
    if not startedRegister[source] then return end

    exports.f_dirtymoney:AddDirtyCash(source, math.random(config.registerReward.min, config.registerReward.max), 'storerobbery-register')

    TriggerClientEvent('f_storerobbery:client:updatedRobbables', -1, sharedConfig.registers, sharedConfig.safes)
    if config.registerReward.chanceAtSticky > math.random(0, 100) then
        local code = safeCodes[sharedConfig.registers[closestRegisterIndex].safeKey]
        local info
        if sharedConfig.safes[sharedConfig.registers[closestRegisterIndex].safeKey].type == 'keypad' then
            info = {
                label = locale('text.safe_code') .. tostring(code)
            }
        else
            info = {
                label = locale('text.safe_code') .. tostring(math.floor((code[1] % 360) / 3.60)) .. "-" .. tostring(math.floor((code[2] % 360) / 3.60)) .. "-" .. tostring(math.floor((code[3] % 360) / 3.60)) .. "-" .. tostring(math.floor((code[4] % 360) / 3.60)) .. "-" .. tostring(math.floor((code[5] % 360) / 3.60))
            }
        end

        exports.ox_inventory:AddItem(source, 'stickynote', 1, info)
    end

    startedRegister[source] = false
    SetTimeout(math.random(config.registerRefresh.min, config.registerRefresh.max), function()
        sharedConfig.registers[closestRegisterIndex].robbed = false
        TriggerClientEvent('f_storerobbery:client:updatedRobbables', -1, sharedConfig.registers, sharedConfig.safes)
    end)
end)

RegisterNetEvent('f_storerobbery:server:trySafe', function()
    local src = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(src)
    local closestSafeIndex = getClosestSafe(playerCoords)
    local leoCount = exports.qbx_core:GetDutyCountType('leo')

    if not closestSafeIndex then return end
    if leoCount < sharedConfig.minimumCops and sharedConfig.notEnoughCopsNotify then
        exports.qbx_core:Notify(source, locale('error.no_police', {Required = config.minimumCops}), 'error')
        return
    end

    sharedConfig.safes[closestSafeIndex].robbed = true
    startedSafe[source] = true
    TriggerClientEvent('f_storerobbery:client:initSafeAttempt', source, closestSafeIndex, safeCodes[closestSafeIndex])
end)

RegisterNetEvent('f_storerobbery:server:failedSafeCracking', function()
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local closestSafeIndex = getClosestSafe(playerCoords)
    sharedConfig.safes[closestSafeIndex].robbed = false
    startedSafe[source] = false
end)

RegisterNetEvent('f_storerobbery:server:safeCracked', function()
    local player = exports.qbx_core:GetPlayer(source)
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local closestSafeIndex = getClosestSafe(playerCoords)
    local worthMarkedBills = math.random(config.safeReward.markedBillsWorth.min, config.safeReward.markedBillsWorth.max)
    local numMarkedBills = math.random(config.safeReward.markedBillsAmount.min, config.safeReward.markedBillsAmount.max)

    if not closestSafeIndex then return end
    if not startedSafe[source] then return end

    -- f_dirtymoney: isi brankas langsung jadi cash kotor (item markedbills tidak dipakai)
    exports.f_dirtymoney:AddDirtyCash(source, worthMarkedBills * numMarkedBills, 'storerobbery-safe')

    if config.safeReward.chanceAtSpecial > math.random(0, 100) then
        player.Functions.AddItem('rolex', math.random(config.safeReward.rolexAmount.min, config.safeReward.rolexAmount.max))
        if config.safeReward.chanceAtSpecial / 2 > math.random(0, 100) then
            player.Functions.AddItem('goldbar', config.safeReward.goldbarAmount)
        end
    end
    startedSafe[source] = false
    TriggerClientEvent('f_storerobbery:client:updatedRobbables', -1, sharedConfig.registers, sharedConfig.safes)
    SetTimeout(math.random(config.safeRefresh.min, config.safeRefresh.max), function()
        sharedConfig.safes[closestSafeIndex].robbed = false
        TriggerClientEvent('f_storerobbery:client:updatedRobbables', -1, sharedConfig.registers, sharedConfig.safes)
    end)
end)

AddEventHandler('playerJoining', function()
    TriggerClientEvent('f_storerobbery:client:updatedRobbables', source, sharedConfig.registers, sharedConfig.safes)
end)

lib.callback.register('f_storerobbery:server:leoCount', function()
    return exports.qbx_core:GetDutyCountType('leo')
end)

CreateThread(function()
    while true do
        safeCodes = {}
        for i = 1, #sharedConfig.safes, 1 do
            local Safe = sharedConfig.safes[i]
            if Safe.type == "padlock" then
                safeCodes[i] = { math.random(150, 450), math.random(1.0, 100.0), math.random(360, 450), math.random(300.0, 340.0), math.random(350, 400), math.random(320.0, 340.0), math.random(350, 600) }
            elseif Safe.type == "keypad" then
                safeCodes[i] = math.random(1000, 9999)
            else
                print('[ERROR] Incorrect Safe type!')
            end
        end
        Wait(config.safeRefresh.min)
    end
end)
