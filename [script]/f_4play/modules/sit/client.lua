-- Duduk di kursi/bangku (model di SitConfig.chairs) lewat ox_target. Berdiri: X / SPACE.

local sitting = false
local seatEntity

local function sit(entity, newCoords)
    local playerPed = cache.ped
    local playerCoords = GetEntityCoords(playerPed)
    local entityCoords = GetEntityCoords(entity)
    local name = GetEntityArchetypeName(entity)
    local heading = GetEntityHeading(entity) + 180.0
    if string.find(name, "bench") then
        entityCoords = newCoords
    end
    if name == "prop_table_01_chr_b" then heading += 90 end
    seatEntity = entity
    FreezeEntityPosition(seatEntity, true)
    if name == "apa_mp_h_yacht_barstool_01" then
        playerCoords = vec3(playerCoords.x, playerCoords.y, playerCoords.z + 0.25)
    end
    TaskStartScenarioAtPosition(playerPed, "PROP_HUMAN_SEAT_BENCH", entityCoords.x, entityCoords.y, playerCoords.z - 0.5, heading, 0, true, true)
    if SitConfig.firstPersonOnSit then
        Wait(1000)
        SetFollowPedCamViewMode(4)
    end
    sitting = true
end

exports.ox_target:addModel(SitConfig.chairs, {
    {
        -- Duduk
        label = SitConfig.targetName, name = "nvsit", icon = SitConfig.targetIcon, iconColor = "orange", distance = 1.5,
        canInteract = function() return not sitting end,
        onSelect = function(data) return sit(data.entity, data.coords) end
    },
    {
        -- Berdiri
        label = SitConfig.targetNameStandUp, name = "nvstandup", icon = SitConfig.targetIcon, iconColor = "orange", distance = 1.5,
        canInteract = function() return sitting end,
        onSelect = function() return ExecuteCommand('neveradev:sit:stand_up') end
    }
})

-- nama command sama dengan nv_sit_on_every_chair supaya keybind pemain tidak hilang
RegisterKeyMapping('neveradev:sit:stand_up_x', 'Nevera - Stand Up X', 'keyboard', "X")
RegisterKeyMapping('neveradev:sit:stand_up_space', 'Nevera - Stand Up SPACE', 'keyboard', "SPACE")

RegisterCommand('neveradev:sit:stand_up_x', function() ExecuteCommand('neveradev:sit:stand_up') end)
RegisterCommand('neveradev:sit:stand_up_space', function() ExecuteCommand('neveradev:sit:stand_up') end)

RegisterCommand('neveradev:sit:stand_up', function()
    if sitting then
        sitting = false
        local playerPed = cache.ped
        ClearPedTasks(playerPed)
        TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_STAND_IDLE", 0, true)
        FreezeEntityPosition(seatEntity, false)
        Wait(500)
        SetFollowPedCamViewMode(1)
    end
end)
