-- Bel lobi/kasir: warga memanggil pegawai job (on/off duty) lewat notifikasi ox_lib.
BellConfig = {}

BellConfig.Cooldown = 60   -- jeda per bel (detik), anti spam
BellConfig.Distance = 3.0  -- jarak maks pemain dari bel saat membunyikan (dicek server)

-- Satu baris = satu bel. Notifikasi dikirim ke SEMUA pemain dengan job `job` yang online
-- (on-duty maupun off-duty). Kalau tidak ada yang online, bel tidak berbunyi.
--   job    : nama job di qbx_core
--   title  : judul notifikasi
--   label  : tempat, dipakai di "Ada warga menunggu di <label>"
--   staff  : dipakai di "Tidak ada <staff> di kota saat ini"
--   coords : titik ox_target "Bunyikan Bel" (koordinat SEMENTARA, ubah ke meja depan masing-masing)
BellConfig.Bells = {
    {job = 'police',    title = 'Bel Kantor Polisi', label = 'lobi Kantor Polisi Mission Row', staff = 'polisi',         coords = vec3(441.2, -978.9, 30.69)},
    {job = 'cafe',      title = 'Bel Kafe',          label = 'kasir Kafe',                     staff = 'pegawai kafe',   coords = vec3(-1707.76, -803.41, 10.52)},
    {job = 'mechanic',  title = 'Bel Bengkel',       label = 'kasir Bengkel',                  staff = 'mekanik',        coords = vec3(-327.51, -1336.86, 30.46)},
    {job = 'ambulance', title = 'Bel Rumah Sakit',   label = 'resepsionis Ocean Hospital',     staff = 'petugas medis',  coords = vec3(-2786.37, -69.65, 17.61)},
}
