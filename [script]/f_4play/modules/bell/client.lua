-- Bel lobi/kasir: titik ox_target per bel di BellConfig.Bells, logika di server.lua.

CreateThread(function()
    for i, bell in ipairs(BellConfig.Bells) do
        exports.ox_target:addBoxZone({
            name = ('f_bell_%d'):format(i),
            coords = bell.coords,
            size = vec3(1.0, 1.0, 1.5),
            options = {{
                name = 'f_bell:ring',
                icon = 'fa-solid fa-bell',
                label = 'Bunyikan Bel',
                distance = 2.0,
                onSelect = function()
                    TriggerServerEvent('f_bell:server:ring', i)
                end,
            }},
        })
    end
end)

RegisterNetEvent('f_bell:client:rang', function(coords)
    PlaySoundFromCoord(-1, 'DOOR_BUZZ', coords.x, coords.y, coords.z, 'MP_PLAYER_APARTMENT', false, 10, false)
end)
