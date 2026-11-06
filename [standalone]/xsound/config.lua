config = {}

-- How much ofter the player position is updated ?
config.RefreshTime = 300

-- default sound format for interact
config.interact_sound_file = "ogg"

-- is emulator enabled ?
config.interact_sound_enable = true     -- pengganti resource interact-sound (file di html/sounds/*.ogg)

-- how much close player has to be to the sound before starting updating position ?
config.distanceBeforeUpdatingPos = 40

-- Message list
config.Messages = {
    ["streamer_on"]  = "Mode streamer aktif. Kamu tidak akan mendengar musik/suara apa pun.",
    ["streamer_off"] = "Mode streamer nonaktif. Kamu bisa mendengar musik yang diputar pemain lain.",

    ["no_permission"] = "Kamu tidak punya izin memakai perintah ini!",
}

-- Addon list
-- True/False enabled/disabled
config.AddonList = {
    crewPhone = false,
}