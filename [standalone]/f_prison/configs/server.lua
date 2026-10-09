return {
    EnableJailCommand = false,                  -- /jail (ox_lib input). Off: jailing only through the MDT (report + booking). /unjail stays.
    MinutesPerMonth = 1,                      -- real minutes one "month" of sentence lasts (counted on the server, only while online)

    UnemployedJobName = 'unemployed',           -- Name of unemployed job (if remove job is enabled)

    CanteenMeal = {                             -- Food & Drink received from canteen
        food = {
            item = 'burger',
            count = 1
        },
        drink = {
            item = 'water',
            count = 1
        }
    },

    AllowedToKeepItems = {                      --  Items found/received in prison that can be kept when released
        ['money'] = true
    },

    -- foreplay: item yang TIDAK disita saat masuk penjara (dan tetap dibawa saat keluar).
    -- KeepFoodAndDrink = semua item di ox_inventory/data/items.lua yang menambah hunger/thirst
    -- (dibaca otomatis). Tambahkan makanan/minuman dari script lain di KeepOnEntry.
    KeepFoodAndDrink = true,
    KeepOnEntry = {
        -- ['nama_item'] = true,
    },

    PoliceJobs = {                              -- Police jobs
        'police',
        'lspd',
    },

    Lifers = {                                  -- Lifer identifiers
        'RANDOLIOCID',
        'QWADEBOTCID'
    },

    banPlayer = function(source, cid)
        -- Implement your own ban functions/logging here
        -- This function passes the player source and player core identifier
    end
}