AddEventHandler('playerConnecting', function(_, _, deferrals)
    local source = source
    deferrals.defer()

    Wait(0)

    local license = GetPlayerIdentifierByType(source --[[@as string]], 'license2')
        or GetPlayerIdentifierByType(source --[[@as string]], 'license')
    local discord = GetPlayerIdentifierByType(source --[[@as string]], 'discord')
    local ip = GetPlayerIdentifierByType(source --[[@as string]], 'ip')

    local ban = Storage.FindBan({ license = license, discord = discord, ip = ip })

    if ban then
        deferrals.done(('Kamu di-ban dari server ini.\nAlasan: %s\nDi-ban oleh: %s'):format(ban.reason, ban.banned_by))
        return
    end

    deferrals.done()
end)
