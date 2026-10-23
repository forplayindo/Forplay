---- my tebex: https://guxfiz.tebex.io/
---- my discord: https://discord.gg/kncN7Fr5KT

Config = {}

Config = {
    
    Framework = "qb", -- 'auto'/'esx'/'qb'

    Notify = "qb", -- "ox_lib", "esx", "qb", "custom"

    Staff = {
        Command = 'dvall',
        Group = {'admin', 'mod'} -- "none" | u group!
    },

    sound = {
        start_sound = {
            sound = 'start_sound.mp3', -- "none" | "start_sound.mp3"
            volume = 0.2, -- recommend 0.2 | Volume min 0.1 max 0.5
        },
        end_sound = {
            sound = 'end_sound.mp3', -- "none" | "end_sound.mp3"
            volume = 0.2, -- recommend 0.2 | Volume min 0.1 max 0.5
        },
    },

    nui = {
        color = "dark", -- "dark", "white", "blue", "red", "green", "pink"  (aksen kapsul kaca)
        position = "topCenter", -- "center", "topLeft", "topRight", "middleLeft", "middleRight", "bottomLeft", "bottomRight", "topCenter", "bottomCenter"
        logo = 'default', -- 'default' = ikon bawaan (paling ringan) | logo.png (taruh di web/assets/) | URL. Hindari GIF animasi: bikin repaint tiap frame
        tittle = 'Asuransi Keliling',
        description = 'Amankan kendaraan Anda',
        warning_text = 'Naiki kendaraan Anda sekarang', -- tampil saat sisa 15 detik ('' = tetap pakai description)
        final_text = 'Kendaraan kosong akan diangkut', -- tampil saat sisa 5 detik ('' = tetap pakai description)
    },

    clear_nui = {
        logo = 'default', -- 'default' = ikon centang bawaan | logo.png | URL
        tittle = 'Kendaraan sudah dibersihkan',
        description = 'Selesai. Ambil kendaraan di Asuransi',
        clear_sound = {
            sound = 'clear_sound.mp3', -- "none" | "clear_sound.mp3"
            volume = 0.2, -- recommend 0.2 | Volume min 0.1 max 0.5
        }
    },

    auto = {
        DeleteVehicleTimer = 1, -- Time (in minutes) that it will take to delete vehicles since you execute automatic
        time = {'01:01', '04:00', '07:00', '10:00', '13:00', '16:00', '19:00', '22:00'} -- u add more! time for delete vehicles automatic!
    },

    RemoveCarsInSafeZone = false, --   true | false   -- Remove Vehicles in SafeZone ?|
    safezone = {
        blipshow = true,
        blipstyle = {
            color = 2, -- https://docs.fivem.net/docs/game-references/blips/#blip-colors
            degraded = 64,
        },
        zone = {
            {coord = vec3(-319.5774, -901.4604, 31.6051), radius = 50.0},
            --{coord = vec3(248.5390, -1179.6720, 29.4189), radius = 50.0},
            -- zona poligon (titik vec2 berurutan, tanpa blip): kendaraan di dalamnya tidak dihapus
            { label = 'Bengkel', points = {
                vec2(-328.35, -1339.78),
                vec2(-329.14, -1370.16),
                vec2(-362.24, -1371.01),
                vec2(-362.82, -1337.02),
            } },
        }
    }
}

Leng = {
    ["tittle"] = "Asuransi",
    ["already_autoDV"] = "Sedang diproses!",
}
---- my tebex: https://guxfiz.tebex.io/
---- my discord: https://discord.gg/kncN7Fr5KT