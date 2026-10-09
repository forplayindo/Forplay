--[[
    sd-3dme — server

    Perubahan dari versi asli:
    * Tidak lagi memakai lib.addCommand (ox_lib). Command didaftarkan dengan RegisterCommand
      biasa supaya bisa DIDAFTARKAN ULANG otomatis.

      Kenapa: kalau ada resource lain (qbx_core, nx_chat, dll.) yang juga mendaftarkan /me atau /do,
      FiveM hanya memakai pendaftaran TERAKHIR. Akibatnya bubble 3D hanya muncul setelah
      `restart sd-3dme` (karena saat itulah sd-3dme jadi yang terakhir). Sekarang sd-3dme
      mendaftarkan ulang commandnya sendiri setiap kali ada resource lain start,
      jadi selalu menang tanpa perlu restart manual.
]]

local MAX_LEN = 100

local Commands = {
    me     = { event = '3dme:me',     help = 'Tampilkan aksi roleplay di atas kepala',      param = 'aksi' },
    ['do'] = { event = '3dme:do',     help = 'Tampilkan deskripsi roleplay di atas kepala', param = 'deskripsi' },
    med    = { event = '3dme:med',    help = 'Tampilkan aksi medis di atas kepala',         param = 'aksi medis' },
    animal = { event = '3dme:animal', help = 'Tampilkan aksi hewan di atas kepala',         param = 'aksi hewan' },
}

local lastFire = {}   -- [src .. name] = GetGameTimer(), cegah eksekusi ganda

local function handle(name, cfg, src, args)
    if src == 0 then
        print(('[sd-3dme] /%s hanya untuk pemain.'):format(name))
        return
    end

    local key = src .. ':' .. name
    local now = GetGameTimer()
    if lastFire[key] and now - lastFire[key] < 100 then return end
    lastFire[key] = now

    local text = table.concat(args, ' ')
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 224, 164, 88 },
            args  = { 'Info', ('Pemakaian: /%s [%s]'):format(name, cfg.param) },
        })
        return
    end

    text = string.sub(text, 1, MAX_LEN)
    TriggerClientEvent(cfg.event, -1, text, src, 'icons')
end

local function registerAll()
    for name, cfg in pairs(Commands) do
        RegisterCommand(name, function(src, args)
            handle(name, cfg, src, args)
        end, false)
    end
end

local function addSuggestions()
    for name, cfg in pairs(Commands) do
        TriggerEvent('chat:addSuggestion', '/' .. name, cfg.help, {
            { name = 'teks', help = cfg.param },
        })
    end
end

-- daftar sekali saat start
registerAll()
CreateThread(function()
    Wait(1000)
    addSuggestions()
end)

-- daftar ulang (debounce) setiap kali resource LAIN start, supaya kita selalu jadi yang terakhir
local pending = false
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end

    -- chat baru start -> kirim ulang suggestion /me /do
    if resourceName == 'chat' or resourceName == 'nx_chat' or resourceName == 'f_chat' then
        SetTimeout(1000, addSuggestions)
    end

    if pending then return end
    pending = true
    SetTimeout(2000, function()
        pending = false
        registerAll()
    end)
end)
