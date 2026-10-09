local config    = lib.load('configs.client')
local utils     = require 'client.modules.utils'
local resources = require 'bridge.compat.resources'

local prisonDoc
local prisonDocBlip

local function initPrisonDoctor()
    if DoesEntityExist(prisonDoc) then return end

    local docInfo = config.PrisonDoctor
    prisonDoc = utils.createPed(docInfo.model, docInfo.coords, docInfo.scenario)
    prisonDocBlip = utils.createBlip('Prison Infirmary', docInfo.coords, 61, 0.3, 1)
    if resources.qb_target then
            exports['qb-target']:AddTargetEntity(prisonDoc, {
                options = {
                    {
                        label = 'Periksa Kesehatan',
                        icon = 'fas fa-stethoscope',
                        action = function()
                            if lib.progressCircle({
                                label = 'Sedang diperiksa...',
                                duration = (docInfo.healLength * 1000),
                                position = 'bottom',
                                useWhileDead = true,
                                canCancel = false,
                                disable = {
                                    move = true,
                                    car = true,
                                    combat = true,
                                    sprint = true,
                                },
                            }) then
                                lib.notify({ title = 'Sembuh', description = 'Kamu sudah diperiksa dokter!', type = 'success' })
                                config.PlayerHealed()
                            end
                        end
                    },
                },
            distance = 2.5,
        })
    else
        exports.ox_target:addLocalEntity(prisonDoc, {
            {
                label = 'Periksa Kesehatan',
                icon = 'fas fa-stethoscope',
                onSelect = function()
                    if lib.progressCircle({
                        label = 'Sedang diperiksa...',
                        duration = (docInfo.healLength * 1000),
                        position = 'bottom',
                        useWhileDead = true,
                        canCancel = false,
                        disable = {
                            move = true,
                            car = true,
                            combat = true,
                            sprint = true,
                        },
                    }) then
                        lib.notify({ title = 'Sembuh', description = 'Kamu sudah diperiksa dokter!', type = 'success' })
                        config.PlayerHealed()
                    end
                end
            }
        })
    end
end

local function removePrisonDoctor()
    if not DoesEntityExist(prisonDoc) and not DoesBlipExist(prisonDocBlip) then
        return
    end

    if resources.qb_target then
        exports['qb-target']:RemoveTargetEntity(prisonDoc)
    else
        exports.ox_target:removeLocalEntity(prisonDoc, 'Periksa Kesehatan')
    end

    DeletePed(prisonDoc)
    RemoveBlip(prisonDocBlip)
end

AddEventHandler('onResourceStart', function(resource)
   if resource ~= GetCurrentResourceName() then return end
   initPrisonDoctor()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removePrisonDoctor()
end)

AddEventHandler('xt-prison:client:onLoad', function()
    initPrisonDoctor()
end)

AddEventHandler('xt-prison:client:onUnload', function()
    removePrisonDoctor()
end)
