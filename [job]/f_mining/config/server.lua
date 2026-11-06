return {
    bucketBase = 70000,         -- gua i = routing bucket 70000 + i (jauh dari bucket = id pemain)

    -- hasil per pukulan (total 100). rare = notifikasi + suara khusus
    drops = {
        { item = 'bijih_tembaga', chance = 62 },
        { item = 'bijih_perak', chance = 27 },
        { item = 'bijih_emas', chance = 10, rare = true },
        { item = 'diamond', chance = 1, rare = true },
    },

    hitCooldown = 4500,         -- ms antar pukulan (animasi klien 5 dtk)
    hitDistance = 3.5,
    rockHits = { 15, 20 },      -- batu hancur setelah sekian pukulan (acak)
    rockRespawn = 120,          -- detik sampai batu yang hancur muncul lagi

    kapak = { hits = 200 },     -- Kapak Tambang patah setelah sekian pukulan (harga di config/shared.lua)

    gudang = { slots = 50, weight = 500000 },   -- Gudang Tambang (lobby): bijih dari lori
    hasil = { slots = 50, weight = 500000 },    -- Gudang Hasil (atas): hasil lebur + berlian
    -- hanya item ini yang boleh dimasukkan pemain ke Gudang Tambang
    -- (Gudang Hasil: hasil lebur + berlian; kalau Gudang Hasil penuh, server meluapkan ke sini)
    gudangItems = {
        bijih_tembaga = true, bijih_perak = true, bijih_emas = true, kapak_tambang = true,
    },
    -- disetor ke bak lori ("Setor Semua")
    depositItems = { 'bijih_tembaga', 'bijih_perak', 'bijih_emas', 'diamond' },

    lori = { interval = 120, travel = 20 }, -- berangkat tiap 120 dtk, sampai gudang 20 dtk kemudian

    afkSeconds = 600,           -- tanpa memukul batu sekian detik -> peringatan, 60 dtk kemudian ke lobby
    wadahTimeout = 300,         -- wadah tidak ditaruh sekian detik -> isi kembali ke gudang
}
