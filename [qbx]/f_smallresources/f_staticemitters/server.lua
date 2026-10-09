lib.callback.register('f_staticemitters:server:IsPlayerAceAllowed', function(src)
    return IsPlayerAceAllowed(src, 'admin')
end)