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
        style = "style1", -- "style1", "style2", "style3", "style4", "style5" 
        color = "dark", -- "red", "blue", "pink", "green", "dark", "white" 
        position = "topCenter", -- "center", "topLeft", "topRight", "middleLeft", "middleRight", "bottomLeft", "bottomRight", "topCenter", "bottomCenter"
        logo = 'https://images.emojiterra.com/google/noto-emoji/animated-emoji/1f6a8.gif', -- logo.png(u add image in web/assets/"here") or URL
        tittle = 'ASURANSI KELILING',
        description = 'Amankan Kendaraan Anda!!',
    },

    clear_nui = {
        logo = 'https://media.tenor.com/AWKzZ19awFYAAAAi/checkmark-transparent.gif', -- logo.png(u add image in web/assets/"here") or URL
        description = 'Selesai. Ambil kendaraan di Asuransi',
        clear_sound = {
            sound = 'clear_sound.mp3', -- "none" | "end_sound.mp3"
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
            -- u can add more!
        }
    }
}

Leng = {
    ["tittle"] = "Asuransi",
    ["already_autoDV"] = "Sedang diproses!",
}
---- my tebex: https://guxfiz.tebex.io/
---- my discord: https://discord.gg/kncN7Fr5KT