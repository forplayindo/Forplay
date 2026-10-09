Bridge = {
    Framework = nil,
    FrameworkObject = nil,
}

if Config.Framework and Config.Framework ~= 'auto' then
    Bridge.Framework = Config.Framework
    print(('[Economy Dashboard] Framework forced to: %s'):format(Config.Framework))
end

if Config.Debug then
    print('[Economy Dashboard] Bridge initialized, waiting for framework detection...')
end
