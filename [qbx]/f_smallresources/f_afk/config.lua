return {
    -- Detik diam sebelum di-kick (1000 = ~16-17 menit)
    timeUntilAFKKick = 1000,

    -- Staff f_admin (Owner/Admin/Support) tidak pernah di-kick.
    -- ACE di bawah ini juga dikecualikan (cadangan kalau f_admin mati).
    ignoreAces = { 'admin', 'mod' },

    -- Zona AFK: pemain yang diam di dalam area ini tidak di-kick.
    -- Titik pakai vec2 (ambil dengan /vec2), minimal 3 titik, urut keliling area.
    -- minZ/maxZ opsional, untuk membatasi ketinggian (mis. gedung bertingkat).
    zones = {
        -- {
        --     name = 'Taman Kota',
        --     points = {
        --         vec2(200.0, -900.0),
        --         vec2(230.0, -900.0),
        --         vec2(230.0, -930.0),
        --         vec2(200.0, -930.0),
        --     },
        --     minZ = 20.0,
        --     maxZ = 40.0,
        -- },
    },
}
