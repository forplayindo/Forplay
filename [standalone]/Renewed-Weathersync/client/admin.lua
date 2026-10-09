-- Weather Admin Management --
local weatherTypes = {
    {
        label = 'Blizzard',
        value = 'BLIZZARD'
    },
    {
        label = 'Clear',
        value = 'CLEAR'
    },
    {
        label = 'Clearing',
        value = 'CLEARING'
    },
    {
        label = 'Clouds',
        value = 'CLOUDS'
    },
    {
        label = 'Extra Sunny',
        value = 'EXTRASUNNY'
    },
    {
        label = 'Foggy',
        value = 'FOGGY'
    },
    {
        label = 'Neutral',
        value = 'NEUTRAL'
    },
    {
        label = 'Overcast',
        value = 'OVERCAST'
    },
    {
        label = 'Rain',
        value = 'RAIN'
    },
    {
        label = 'Smog',
        value = 'SMOG'
    },
    {
        label = 'Snow',
        value = 'SNOW'
    },
    {
        label = 'Snowlight',
        value = 'SNOWLIGHT'
    },
    {
        label = 'Thunder',
        value = 'THUNDER'
    },
    {
        label = 'Xmas',
        value = 'XMAS'
    },
}

local function viewWeatherEvent(index, weatherEvent, isQueued)
    local metadata = isQueued and {
        ('Weather %s'):format(weatherEvent.weather),
        ('Lasting for %s minutes'):format(weatherEvent.time)
    } or {
        ('Weather %s'):format(weatherEvent.weather),
        ('%s Minutes Remaining'):format(weatherEvent.time)
    }
    lib.registerContext({
        id = 'Renewed-Weathersync:client:changeWeather',
        title = 'Ubah Cuaca',
        menu = 'Renewed-Weathersync:client:manageWeather',
        options = {
            {
                title = 'Info',
                icon = 'fa-solid fa-circle-info',
                readOnly = true,
                metadata = metadata
            },
            {
                title = 'Ubah Cuaca',
                icon = 'fa-solid fa-cloud',
                arrow = true,
                onSelect = function()
                    local input = lib.inputDialog('Ubah Jenis Cuaca', {
                        {
                            label = 'Pilih Cuaca',
                            type = 'select',
                            required = true,
                            default = weatherEvent.weather,
                            options = weatherTypes
                        },
                    })

                    if input and input[1] then
                        local weather = lib.callback.await('Renewed-Weathersync:server:setWeatherType', false, index, input[1])

                        if weather then
                            weatherEvent.weather = weather
                        end
                    end

                    viewWeatherEvent(index, weatherEvent)
                end
            },
            {
                title = 'Ubah Durasi',
                arrow = true,
                icon = 'fa-solid fa-hourglass-half',
                onSelect = function()
                    local input = lib.inputDialog('Ubah Durasi', {
                        {
                            label = 'Durasi (menit)',
                            type = 'slider',
                            required = true,
                            min = 1,
                            max = 120,
                            default = weatherEvent.time,
                        },
                    })

                    if input and input[1] then
                        local time = lib.callback.await('Renewed-Weathersync:server:setEventTime', false, index, input[1])

                        if time then
                            weatherEvent.time = time
                        end
                    end

                    viewWeatherEvent(index, weatherEvent)
                end
            },
            {
                title = 'Hapus Cuaca',
                arrow = true,
                icon = 'fa-solid fa-circle-xmark',
                onSelect = function()
                    TriggerServerEvent('Renewed-Weather:server:removeWeatherEvent', index)
                end
            }
        }
    })

    lib.showContext('Renewed-Weathersync:client:changeWeather')
end

RegisterNetEvent('Renewed-Weather:client:viewWeatherInfo', function(weatherTable)
    local options = {}
    local amt = 0

    local startingIn = 0

    for i = 1, #weatherTable do
        local currentWeather = weatherTable[i]
        amt += 1

        local isQueued = i > 1

        local meatadata = isQueued and {
            ('Mulai dalam %s menit'):format(startingIn),
            ('Lasting for %s minutes'):format(currentWeather.time)
        } or {
            ('%s Minutes Remaining'):format(currentWeather.time)
        }

        options[amt] = {
            title = isQueued and ('Cuaca Berikutnya: %s'):format(currentWeather.weather) or ('Cuaca Sekarang: %s'):format(currentWeather.weather),
            description = isQueued and ('Mulai dalam %s menit'):format(startingIn),
            arrow = true,
            icon = isQueued and 'fa-solid fa-cloud-arrow-up' or 'fa-solid fa-cloud',
            metadata = meatadata,
            onSelect = function()
                viewWeatherEvent(i, currentWeather, isQueued)
            end
        }

        startingIn += currentWeather.time
    end


    lib.registerContext({
        id = 'Renewed-Weathersync:client:manageWeather',
        title = 'Pengaturan Cuaca',
        options = options
    })

    lib.showContext('Renewed-Weathersync:client:manageWeather')
end)