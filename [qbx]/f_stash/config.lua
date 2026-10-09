Config = {}

Config.Command   = 'stash'        -- /stash, hanya untuk Config.AllowedLicenses

-- Hanya pemain dengan identifier di bawah ini yang boleh membuka menu /stash.
-- Isi lengkap dengan awalannya, contoh 'license:1a2b3c...' (bisa juga 'discord:...' / 'fivem:...').
-- Lihat license pemain di txAdmin (Players > pilih pemain > IDs).
Config.AllowedLicenses = {
    'license:3b28ac3d7f015e6e6983866188d94dedf79c0271',
}
Config.Distance  = 1.5            -- jarak teks [E] muncul (meter)
Config.MaxSlots  = 500
Config.MaxWeight = 5000           -- kg
Config.Grades    = { 0, 1, 2, 3, 4 } -- 0 = semua grade; angka lain = grade itu ke atas

-- Stash yang ID-nya dipakai langsung oleh script lain: boleh dipindah/diubah, tidak boleh dihapus.
Config.Protected = {
    cafe_fridge = 'f_cafe',
    cafe_ready  = 'f_cafe',
}

-- Stash lama dari script lain, dimasukkan SEKALI saat f_stash pertama kali jalan.
-- ID sama dengan yang lama, jadi barang di dalamnya tetap ada.
Config.Seed = {
    { id = 'mechanicstash',  label = 'Gudang Bengkel',        coords = vec3(-346.08, -1334.10, 30.32), gtype = 'job', group = 'mechanic',  grade = 0, personal = false, duty = false, slots = 200, weight = 2000 },
    { id = 'cafe_fridge',    label = 'Kulkas & Gudang Bahan', coords = vec3(-1759.23, -1087.98, 14.36), gtype = 'job', group = 'cafe',      grade = 0, personal = false, duty = true,  slots = 80,  weight = 1000 },
    { id = 'cafe_ready',     label = 'Stok Siap Jual',        coords = vec3(-1753.05, -1081.94, 14.37), gtype = 'job', group = 'cafe',      grade = 0, personal = false, duty = true,  slots = 50,  weight = 1000 },
    { id = 'ambulanceStash', label = 'Loker Pribadi EMS',     coords = vec3(309.78, -596.6, 43.29),     gtype = 'job', group = 'ambulance', grade = 0, personal = true,  duty = true,  slots = 30,  weight = 100 },
    { id = 'emslocker',      label = 'Loker Pribadi EMS 2',   coords = vec3(301.82, -600.99, 43.29),    gtype = 'job', group = 'ambulance', grade = 0, personal = true,  duty = false, slots = 70,  weight = 70 },
    { id = 'policelocker',   label = 'Loker Pribadi Polisi',  coords = vec3(451.25, -994.28, 30.69),    gtype = 'job', group = 'police',    grade = 0, personal = true,  duty = false, slots = 70,  weight = 100 },
}
