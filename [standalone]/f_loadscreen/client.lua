-- Jembatan loadscreen <-> server.
-- Loadscreen hanya bisa diajak bicara satu arah (SendLoadingScreenMessage);
-- arah balik lewat NUI callback (butuh ui_page di manifest).

local done = false          -- loadscreen sudah ditutup
local gate = nil            -- nil = belum dijawab server, 'off', atau nomor versi
local gateAskedAt = GetGameTimer()

local function send(data)
    if done then return end
    SendLoadingScreenMessage(json.encode(data))
end

local function playerName()
    return ((GetPlayerName(PlayerId()) or ''):gsub('%^%d', ''))
end

local function pushGate()
    if gate == nil then return end
    if gate == 'off' then
        send({ eventName = 'rulesGateOff' })
    else
        send({ eventName = 'rulesGate', version = gate })
    end
end

-- ====================================================================
-- Callback dari halaman
-- ====================================================================
RegisterNUICallback('flsHello', function(_, cb)
    cb('ok')
    send({ eventName = 'setPlayerName', name = playerName() })
    local vol = GetResourceKvpInt('volume')
    if GetResourceKvpString('volume_set') == '1' then
        send({ eventName = 'storedVolume', volume = vol })
    end
    TriggerServerEvent('f_loadscreen:content')
    pushGate()
end)

RegisterNUICallback('flsVolume', function(data, cb)
    cb('ok')
    local v = math.floor(tonumber(data and data.volume) or 50)
    SetResourceKvpInt('volume', math.max(0, math.min(100, v)))
    SetResourceKvp('volume_set', '1')
end)

RegisterNUICallback('flsGateAccept', function(data, cb)
    cb('ok')
    TriggerServerEvent('f_loadscreen:gateAccept', data and data.version)
end)

RegisterNUICallback('flsGateDecline', function(data, cb)
    cb('ok')
    TriggerServerEvent('f_loadscreen:gateDecline', data and data.message)
end)

-- ====================================================================
-- Jawaban server
-- ====================================================================
local gotStats = false

RegisterNetEvent('f_loadscreen:stats', function(d)
    gotStats = true
    d.eventName = 'serverStats'
    send(d)
end)

RegisterNetEvent('f_loadscreen:content', function(news, tips)
    send({ eventName = 'serverContent', news = news, tips = tips })
end)

RegisterNetEvent('f_loadscreen:gate', function(version)
    gate = version
    pushGate()
end)

RegisterNetEvent('f_loadscreen:gateOff', function()
    gate = 'off'
    pushGate()
end)

RegisterNetEvent('f_loadscreen:gateAccepted', function()
    gate = 'off'
    send({ eventName = 'rulesAccepted' })
end)

-- ====================================================================
-- Polling statistik: 250ms sampai ada jawaban, lalu tiap 2 detik
-- ====================================================================
CreateThread(function()
    TriggerServerEvent('f_loadscreen:gateCheck')
    while not done do
        TriggerServerEvent('f_loadscreen:stats')
        Wait(gotStats and 2000 or 250)
        -- server tidak menjawab gateCheck: jangan sampai pemain tertahan
        if gate == nil and GetGameTimer() - gateAskedAt > 8000 then gate = 'off' end
    end
end)

-- ====================================================================
-- Shutdown
-- f_multichar memanggil CanShutdown -> FadeOut -> ShutdownLoadingScreenNui.
-- Cadangan: kalau 60 detik setelah sesi mulai belum ada yang menutup,
-- loadscreen ditutup dari sini.
-- ====================================================================
local function canShutdown()
    return gate == 'off'
end

local function fadeOut(ms)
    ms = tonumber(ms) or 600
    send({ eventName = 'fadeOut', durationMs = ms })
    return ms
end

local function finish()
    if done then return end
    Wait(fadeOut(600))
    done = true
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end

exports('CanShutdown', canShutdown)
exports('FadeOut', function(ms)
    local r = fadeOut(ms)
    SetTimeout(r, function() done = true end)
    return r
end)
exports('IsLoadingScreenDone', function() return done end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    local deadline = GetGameTimer() + 60000
    while not done and (GetGameTimer() < deadline or not canShutdown()) do Wait(1000) end
    finish()
end)
