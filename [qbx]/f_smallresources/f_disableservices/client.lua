local config = lib.load('f_disableservices.config')

CreateThread(function()
    SetMaxWantedLevel(config.maxWantedLevel)
    for key, value in ipairs(config.enabledServices) do
        EnableDispatchService(key, value)
    end
end)