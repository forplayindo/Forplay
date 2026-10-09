Config = {}

--============================================================
--  GENERAL
--============================================================

Config.Framework      = 'auto'   -- 'auto' | 'qbx' | 'qb' | 'esx' | 'standalone'
Config.Locale         = 'en'
Config.MaxLength      = 220      -- max characters per message
Config.HistorySize    = 120      -- messages kept in the UI buffer
Config.FadeAfter      = 5       -- seconds before the chat dims when closed (0 = never)
Config.SlowMode       = 1.0      -- seconds between messages per player (0 = off)
Config.StaffAce       = 'nxchat.staff'  -- ACE permission that grants staff powers

-- Extra groups treated as staff (qbx_core / QBCore permission groups)
Config.StaffGroups    = { 'admin', 'god', 'mod' }

--============================================================
--  CHANNELS
--  tab: tempat pesan tampil saat chat dibuka
--    'global'   -> obrolan warga, OOC, /try, staf, laporan, info sistem
--    'announce' -> tab Pengumuman (hanya /announce & /announceadmin)
--    'job'      -> tab Job: chat internal job, ketik langsung tanpa command.
--                  Dicek dari job AKTIF (tidak perlu duty). Tab Job hanya muncul
--                  kalau pemain punya minimal satu channel job.
--  permission.type:
--    'open'   -> everyone
--    'job'    -> permission.jobs = { 'police', 'ambulance' }
--    'grade'  -> permission.jobs + permission.minGrade
--    'staff'  -> staff only (ACE / group)
--    'ace'    -> permission.ace = 'nxchat.whatever'
--  Staf (Config.StaffGroups) ikut membaca & mengirim di semua channel job.
--  radius: nil = server wide, number = only players within X metres
--  bubble: draw the text above the player's head in 3D
--============================================================

Config.Channels = {
    {
        id         = 'Civil',
        label      = 'Warga',
        tag        = 'Civil',
        tab        = 'global',
        -- no `command` on purpose: typing without a leading slash already
        -- sends here (it's the default channel), so /local would be redundant.
        color      = '#C8CEDA',
        icon       = 'speech',
        radius     = nil,
        default    = true,
        format     = '%s: %s',           -- name: message
        permission = { type = 'open' },
    },
    {
        id         = 'ooc',
        label      = 'Di luar karakter (OOC)',
        tag        = 'OOC',
        tab        = 'global',
        command    = 'ooc',
        aliases    = { 'b' },
        color      = '#6E9BD8',
        icon       = 'globe',
        radius     = nil,
        format     = '(( %s: %s ))',
        permission = { type = 'open' },
    },
    -- /me dan /do TIDAK ada di sini dengan sengaja: keduanya ditangani resource
    -- sd-3dme (bubble 3D di atas kepala), jadi tidak muncul di card chat.
    -- Kalau nanti mau dikembalikan ke chat, tambahkan lagi channel 'me' / 'do'.
    {
        id         = 'try',
        label      = 'Mencoba',
        tag        = 'TRY',
        tab        = 'global',
        command    = 'try',
        color      = '#7FC7A8',
        icon       = 'dice',
        radius     = 18.0,
        bubble     = true,
        italic     = true,
        roll       = true,               -- appends succeeded / failed
        format     = '%s %s',
        permission = { type = 'open' },
    },
    {
        id         = 'staff',
        label      = 'Admin',
        tag        = 'ADMIN',
        tab        = 'global',
        command    = 'staff',
        aliases    = { 'a' },
        color      = '#E0A458',
        icon       = 'shield',
        radius     = nil,
        webhook    = '',
        permission = { type = 'staff' },
    },
    {
        id         = 'announce',
        label      = 'Pengumuman',
        tab        = 'announce',
        tag        = 'ANNOUNCEMENT',      -- diganti per pesan dengan nama dari Config.Announce
        -- tanpa `command`: /announce & /announceadmin didaftarkan manual di server/main.lua
        -- (cek job/duty/grade dari Config.Announce). commandOnly = tidak bisa dikirim lewat
        -- kotak chat / event f_chat:send, hanya lewat command itu.
        color      = '#F2B705',
        icon       = 'megaphone',
        radius     = nil,                -- server wide
        cooldown   = 5,                  -- detik, per pemain (jeda antar /announce)
        commandOnly = true,
        permission = { type = 'open' },  -- semua warga bisa MEMBACA
    },
    {
        id         = 'report',
        label      = 'Laporan',
        tag        = 'REPORT',
        tab        = 'global',
        command    = 'report',
        color      = '#D9534F',
        icon       = 'flag',
        radius     = nil,
        staffOnlyView = true,            -- sender + staff see it, nobody else
        webhook    = '',
        permission = { type = 'open' },
    },

    -- ---------- tab Job (tanpa command; pilih di tab Job lalu ketik) ----------
    -- Tambah job lain: salin satu blok, ganti id (unik), label, tag, warna & jobs.
    {
        id         = 'job_police',
        label      = 'Polisi',
        tag        = 'POLISI',
        tab        = 'job',
        color      = '#4A90E2',
        icon       = 'shield',
        permission = { type = 'job', jobs = { 'police', 'bcso', 'sasp' } },
    },
    {
        id         = 'dispatch',
        label      = 'Dispatch',
        tag        = 'DISPATCH',
        tab        = 'job',
        color      = '#E2725B',
        icon       = 'radio',
        webhook    = '',                 -- optional Discord webhook for this channel
        permission = { type = 'job', jobs = { 'police', 'bcso', 'sasp', 'ambulance' } },
    },
    {
        id         = 'job_ems',
        label      = 'EMS',
        tag        = 'EMS',
        tab        = 'job',
        color      = '#E24A4A',
        icon       = 'radio',
        permission = { type = 'job', jobs = { 'ambulance' } },
    },
    {
        id         = 'job_mechanic',
        label      = 'Bengkel',
        tag        = 'BENGKEL',
        tab        = 'job',
        color      = '#E0A458',
        icon       = 'radio',
        permission = { type = 'job', jobs = { 'mechanic' } },
    },
    {
        id         = 'job_cafe',
        label      = 'Cafe',
        tag        = 'CAFE',
        tab        = 'job',
        color      = '#4AE28A',
        icon       = 'radio',
        permission = { type = 'job', jobs = { 'cafe' } },
    },
    {
        id         = 'job_government',
        label      = 'Pemerintah',
        tag        = 'PEMERINTAH',
        tab        = 'job',
        color      = '#F2B705',
        icon       = 'radio',
        permission = { type = 'job', jobs = { 'government' } },
    },
}

-- Saat chat tertutup, pesan baru dari semua tab muncul sebentar di layar lalu memudar
-- (FadeAfter). Pengumuman tampil lebih lama dan tidak terdorong hilang oleh chat lain.
Config.AnnounceFadeAfter = 12   -- detik

--============================================================
--  /announce — pengumuman ke semua warga atas nama instansi
--  Di chat hanya tampil NAMA INSTANSI (name) + isi pesan, tanpa nama pemain.
--  jobs:     key = nama job (lowercase). Job yang tidak ada di sini tidak bisa /announce.
--    name     = nama yang tampil di chat (bebas diubah)
--    color    = warna
--    minGrade = grade minimal yang boleh announce (0 = semua grade)
--  onDuty:   true = harus on duty
--  admin:    dipakai /announceadmin (staf, tanpa job)
--  Staf boleh /announce selama job-nya ada di daftar, tanpa cek duty/grade.
--============================================================

Config.Announce = {
    onDuty = true,
    jobs = {
        police     = { name = 'LSPD',            color = '#4A90E2', minGrade = 0 },
        bcso       = { name = 'BCSO',            color = '#4A90E2', minGrade = 0 },
        sasp       = { name = 'SASP',            color = '#4A90E2', minGrade = 0 },
        ambulance  = { name = 'EMS',             color = '#E24A4A', minGrade = 0 },
        mechanic   = { name = 'Bengkel',         color = '#E0A458', minGrade = 0 },
        cafe       = { name = 'Cafe',            color = '#4AE28A', minGrade = 0 },
        government = { name = 'Pemerintah Kota', color = '#F2B705', minGrade = 0 },
    },
    admin = { name = 'Admin', color = '#A855F7' },
}

--============================================================
--  THEME PRESETS  (players pick one, or set a free hex accent)
--============================================================

Config.DefaultTheme = {
    preset    = 'dispatch',
    accent    = '#E0A458',
    corners   = 'soft',    -- 'sharp' | 'soft' | 'round'
    density   = 'cosy',    -- 'tight' | 'cosy' | 'loose'
    size      = 100,       -- 80 - 130 (%)
    position  = 'left',    -- 'left' | 'right'
    timestamps = true,
    avatars    = true,
    sound      = true,
    font       = 'Inter',
}

Config.Themes = {
    { id = 'dispatch', label = 'Dispatch',  accent = '#E0A458', bg = '#10141C' },
    { id = 'harbour',  label = 'Harbour',   accent = '#5FB2C4', bg = '#0E1519' },
    { id = 'orchid',   label = 'Orchid',    accent = '#B389D8', bg = '#14111C' },
    { id = 'moss',     label = 'Moss',      accent = '#7FB069', bg = '#101610' },
    { id = 'ember',    label = 'Ember',     accent = '#E2725B', bg = '#181110' },
    { id = 'slate',    label = 'Slate',     accent = '#9FB0C9', bg = '#121418' },
    { id = 'daylight', label = 'Daylight',  accent = '#3B6EA5', bg = '#ECEEF2', light = true },
}

--============================================================
--  BLUR (real game blur behind the chat, html/blur.js)
--============================================================
-- GPU only, no Lua resmon. 'auto' follows 0r-hud-v3 (/hudblur) when it runs,
-- otherwise picks a tier from the player's real FPS and switches itself off
-- on weak PCs. Players can override with /chatblur.
Config.Blur = {
    enabled = true,       -- false = never blur (plain translucent panels)
    default = 'auto',     -- 'auto' | 'high' | 'medium' | 'low' | 'off'
    command = 'chatblur', -- nil to disable the command
    autoFps = { high = 75, medium = 45, low = 30 },
}

Config.Fonts = { 'Inter', 'Barlow Semi Condensed', 'Rubik', 'Source Sans 3', 'System UI' }

--============================================================
--  MODERATION
--============================================================

Config.Moderation = {
    allowDelete   = true,
    allowEdit     = true,
    allowMute     = true,
    defaultMute   = 10,      -- minutes
    logWebhook    = '',      -- everything staff does lands here
    blockedWords  = {},      -- { 'word1', 'word2' } -> replaced with ***
}

--============================================================
--  AUTOMATIC MESSAGES
--============================================================

Config.AutoMessages = {
    enabled = true,
    messages = {
        {
            interval = 30,
            audience = 'everyone',
            color    = '#6E9BD8',
            icon     = 'info',
            --title    = 'New here?',
            text     = 'Lagi RP? Jangan lupa tetap in character. Gunakan /ooc kalau mau ngobrol di luar karakter.',
        },
    },
}

--============================================================
--  PLAYER TAGS  (badges shown next to a name)
--  Assign in game with /tag [id] [label] [hex]  -- staff only
--============================================================

Config.Tags = {
    enabled = true,
    presets = {
        { id = 'staff',   label = 'STAFF',   color = '#E0A458' },
        { id = 'dev',     label = 'DEV',     color = '#A88BD8' },
        { id = 'donator', label = 'VIP',     color = '#6FBF8B' },
        { id = 'new',     label = 'NEW',     color = '#8D97AB' },
    },
}

--============================================================
--  BUBBLES (3D text above the head for /try; /me & /do are handled by sd-3dme)
--============================================================

Config.Bubbles = {
    enabled   = true,
    distance  = 15.0,
    duration  = 9,        -- seconds on screen
    maxStack  = 3,        -- lines above one head
    scale     = 0.34,
}
