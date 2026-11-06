--[[ HUD radio: siapa yang sedang bicara di channel radio.
     Sumber: channel dari statebag pma-voice 'radioChannel', nama anggota dari mm_radio (radioListUpdate),
     bicara dari pma-voice (setTalkingOnRadio / radioActive). Tanpa thread, hanya event. ]]

local Radio = {}

local channel = 0
local members = {}          -- [serverId string] = nama
local listsByChannel = {}   -- daftar anggota terakhir per channel (bisa datang sebelum statebag berubah)

local function sameChannel(a, b)
    return math.abs((tonumber(a) or 0) - (tonumber(b) or 0)) < 0.001
end

local function pushChannel()
    local count = 0
    for _ in pairs(members) do count += 1 end
    SendNUIMessage({ action = 'ui:radioHud', data = { channel = channel, count = count } })
end

local function setChannel(value)
    channel = tonumber(value) or 0
    members = channel ~= 0 and (listsByChannel[channel] or {}) or {}
    pushChannel()
end

local function nameOf(id)
    return members[tostring(id)] or ('ID ' .. tostring(id))
end

local function talk(id, talking)
    if channel == 0 then return end
    SendNUIMessage({ action = 'ui:radioTalk', data = { id = tostring(id), name = nameOf(id), talking = talking == true } })
end

-- channel radio pemain (pma-voice)
AddStateBagChangeHandler('radioChannel', ('player:%s'):format(cache.serverId), function(_, _, value)
    setChannel(value)
end)

-- daftar anggota channel (mm_radio, dikirim server ke anggota channel saja)
RegisterNetEvent('mm_radio:client:radioListUpdate', function(players, ch)
    local names = {}
    for id, p in pairs(players or {}) do
        names[tostring(id)] = type(p) == 'table' and p.name or tostring(p)
    end
    listsByChannel[tonumber(ch) or ch] = names
    if sameChannel(ch, channel) then
        members = names
        pushChannel()
    end
end)

-- orang lain bicara / berhenti
RegisterNetEvent('pma-voice:setTalkingOnRadio', function(source, talking)
    talk(source, talking)
end)

-- diri sendiri bicara (event lokal pma-voice)
AddEventHandler('pma-voice:radioActive', function(talking)
    talk(cache.serverId, talking)
end)

--- Kirim ulang status (dipanggil saat UI selesai dimuat / f_hud di-restart)
function Radio.Resend()
    setChannel(LocalPlayer.state.radioChannel)
end

return Radio
