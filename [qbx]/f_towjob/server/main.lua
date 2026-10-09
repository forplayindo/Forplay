local config = require 'config.server'
local sharedConfig = require 'config.shared'
local Bail = {}

-- "drops" is a count the client keeps locally and only reports once, at the
-- end of a shift - there is no way to individually verify each drop server
-- side without touching the client's delivery flow. Instead, cap the claimed
-- count against how much real time has actually passed since the last
-- payout: a real drop realistically takes at least MIN_SECONDS_PER_DROP, so
-- a forged claim can never be paid faster than that.
local lastPayoutTime = {} ---@type table<string, integer>
local MIN_SECONDS_PER_DROP = 25

RegisterNetEvent('qb-tow:server:DoBail', function(bool, vehInfo)
    local Player = exports.qbx_core:GetPlayer(source)
    local paymentMethod

    if not bool then
        if not Bail[Player.PlayerData.citizenid] then return end
        Player.Functions.AddMoney('bank', Bail[Player.PlayerData.citizenid], "tow-bail-paid")
        Bail[Player.PlayerData.citizenid] = nil
        TriggerClientEvent('ox_lib:notify', source, {
          id = 'bail_pay',
          title = 'Pembayaran Kerja',
          description = locale("success.refund_to_cash", config.bailPrice),
          showDuration = true,
          position = 'center-right',
          icon = 'check',
          iconColor = '#49c530'
        })
        return
    end

    if Player.PlayerData.money.cash < config.bailPrice or Player.PlayerData.money.bank < config.bailPrice then
        TriggerClientEvent('ox_lib:notify', source, {
          id = 'tow_pay',
          title = 'Pembayaran Kerja',
          description = locale("error.no_deposit", config.bailPrice),
          showDuration = true,
          position = 'center-right',
          icon = 'ban',
          iconColor = '#C53030'
        })
        return
    end

    if Player.PlayerData.money.cash >= config.bailPrice then
        paymentMethod = 'cash'
    else
        paymentMethod = 'bank'
    end

    Bail[Player.PlayerData.citizenid] = config.bailPrice
    Player.Functions.RemoveMoney(paymentMethod, config.bailPrice, "tow-paid-bail")
    TriggerClientEvent('ox_lib:notify', source, {
      id = 'bail_pay',
      title = 'Pembayaran Kerja',
      description = locale("success.paid_with_" .. paymentMethod, config.bailPrice),
      showDuration = true,
      position = 'center-right',
      icon = 'check',
      iconColor = '#49c530'
    })
    TriggerClientEvent('qb-tow:client:SpawnVehicle', source, vehInfo)
end)

RegisterNetEvent('qb-tow:server:11101110', function(drops)
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return end

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    if Player.PlayerData.job.name ~= "tow" or #(playerCoords - vec3(sharedConfig.locations["main"].coords.x, sharedConfig.locations["main"].coords.y, sharedConfig.locations["main"].coords.z)) > 6.0 then
        return DropPlayer(source, locale("info.skick"))
    end

    drops = tonumber(drops) or 0
    if drops > 20 then drops = 20 end

    local citizenid = Player.PlayerData.citizenid
    local now = GetGameTimer()
    local last = lastPayoutTime[citizenid]
    lastPayoutTime[citizenid] = now

    local maxPlausibleDrops = last and math.floor((now - last) / (MIN_SECONDS_PER_DROP * 1000)) or 3
    if drops > maxPlausibleDrops then drops = maxPlausibleDrops end
    if drops < 1 then
        exports.qbx_core:Notify(source, locale("error.no_work_done"), "error")
        return
    end

    local bonus = 0
    local DropPrice = math.random(85000, 95000)
    if drops > 5 then
        bonus = math.ceil((DropPrice / 10) * ((3 * (drops / 5)) + 2))
    end
    local price = (DropPrice * drops) + bonus
    local taxAmount = math.ceil((price / 100) * config.paymentTax)
    local payment = price - taxAmount

    Player.Functions.AddJobReputation(1)
    Player.Functions.AddMoney("bank", payment, "tow-salary")
    TriggerClientEvent('ox_lib:notify', source, {
      id = 'tow_pay',
      title = 'Pembayaran Kerja',
      description = locale("success.you_earned", payment),
      showDuration = true,
      position = 'center-right',
      icon = 'check',
      iconColor = '#49c530'
    })
end)

lib.addCommand('npc', {
    help = locale("info.toggle_npc"),
}, function(source)
    TriggerClientEvent("jobs:client:ToggleNpc", source)
end)

lib.addCommand('tow', {
    help = locale("info.tow"),
}, function(source)
    local Player = exports.qbx_core:GetPlayer(source)
    if Player.PlayerData.job.name ~= "tow" and Player.PlayerData.job.name ~= "mechanic" then return end
    TriggerClientEvent("qb-tow:client:TowVehicle", source)
end)

lib.callback.register('qb-tow:server:spawnVehicle', function(source, model, coords, warp)
    local warpPed = warp and GetPlayerPed(source)
    local netId = qbx.spawnVehicle({model = model, spawnSource = coords, warp = warpPed})
    if not netId or netId == 0 then return end
    return netId
end)
