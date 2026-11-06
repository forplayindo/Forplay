Config = {}

-- Command pembuka panel (semua staff; aksi di dalamnya dicek per izin).
Config.Command = 'admin'

-- Grup ACE tiap role. Owner diatur di server.cfg (add_principal ... group.owner), tidak bisa dari panel.
Config.Groups = {
    admin = 'group.admin',
    support = 'group.support',
}

-- Command uang: khusus Owner. Admin selalu diberi ACE deny, Support tidak pernah diberi.
Config.MoneyCommands = { 'givemoney', 'setmoney', 'addsociety' }

-- Aksi panel (bukan command chat). a/s = bawaan untuk Admin/Support sebelum Owner mengubahnya.
-- money = khusus Owner, tidak bisa dicentang. Izin dicek lewat ACE 'f_admin.<key>'.
Config.Actions = {
    { key = 'panel.open',       label = 'Buka panel admin (/admin)', a = true, s = true },
    { key = 'self.noclip',      label = 'Noclip (/noclip)', a = true, s = true },
    { key = 'self.godmode',     label = 'God mode', a = true, s = false },
    { key = 'self.invisible',   label = 'Tidak terlihat', a = true, s = true },
    { key = 'self.names',       label = 'Nama di atas kepala (/names)', a = true, s = true },
    { key = 'self.blips',       label = 'Blip semua pemain (/blippemain)', a = true, s = true },
    { key = 'self.teleport',    label = 'Teleport ke waypoint & kembali ke posisi sebelumnya', a = true, s = true },
    { key = 'self.vehgod',      label = 'Godmode kendaraan', a = true, s = false },
    { key = 'self.ammo',        label = 'Amunisi tak terbatas', a = true, s = false },
    { key = 'self.ped',         label = 'Ganti model ped (/setmodel)', a = true, s = false },
    { key = 'self.weapons',     label = 'Beri semua senjata per kategori ke diri sendiri', a = true, s = false },
    { key = 'self.cuff',        label = 'Borgol / lepas borgol diri sendiri', a = true, s = true },
    { key = 'player.goto',      label = 'Datangi pemain & kembalikan pemain', a = true, s = true },
    { key = 'player.bring',     label = 'Tarik pemain ke saya', a = true, s = true },
    { key = 'player.spectate',  label = 'Spectate pemain', a = true, s = true },
    { key = 'player.freeze',    label = 'Bekukan pemain', a = true, s = true },
    { key = 'player.revive',    label = 'Revive / heal pemain & diri sendiri', a = true, s = true },
    { key = 'player.dm',        label = 'Kirim pesan ke pemain', a = true, s = true },
    { key = 'player.sitveh',    label = 'Duduk di kendaraan pemain', a = true, s = true },
    { key = 'player.bucket',    label = 'Ubah routing bucket pemain', a = true, s = false },
    { key = 'player.mute',      label = 'Mute suara pemain', a = true, s = true },
    { key = 'player.setdata',   label = 'Ubah nama / makan / minum / stres / armor / no HP', a = true, s = false },
    { key = 'player.kick',      label = 'Kick pemain', a = true, s = true },
    { key = 'player.ban',       label = 'Ban pemain (HWID)', a = true, s = false },
    { key = 'player.unban',     label = 'Lihat Daftar Ban & cabut ban', a = true, s = false },
    { key = 'player.kill',      label = 'Bunuh pemain', a = true, s = false },
    { key = 'player.inventory', label = 'Buka inventaris pemain', a = true, s = false },
    { key = 'player.clothing',  label = 'Menu pakaian pemain', a = true, s = false },
    { key = 'player.setjob',    label = 'Ubah job / gang pemain', a = true, s = false },
    { key = 'give.item',        label = 'Beri item (log Discord)', a = true, s = false },
    { key = 'give.vehicle',     label = 'Beri kendaraan ke garasi pemain (log Discord)', a = true, s = false },
    { key = 'give.money',       label = 'Beri / atur uang (termasuk item uang tunai)', money = true },
    { key = 'vehicle.spawn',    label = 'Spawn kendaraan sementara', a = true, s = false },
    { key = 'vehicle.fix',      label = 'Perbaiki / bersihkan kendaraan', a = true, s = true },
    { key = 'vehicle.delete',   label = 'Hapus kendaraan terdekat', a = true, s = true },
    { key = 'vehicle.save',     label = 'Beli kendaraan (simpan ke garasi sendiri)', a = true, s = false },
    { key = 'vehicle.tune',     label = 'Tuning kendaraan gratis', a = true, s = false },
    { key = 'vehicle.plate',    label = 'Ganti plat kendaraan', a = true, s = false },
    { key = 'server.weather',   label = 'Ganti cuaca & pemadaman listrik', a = true, s = false },
    { key = 'server.time',      label = 'Ganti waktu', a = true, s = false },
    { key = 'server.radio',     label = 'Daftar pemain di frekuensi radio', a = true, s = true },
    { key = 'server.stash',     label = 'Buka stash berdasarkan nama', a = true, s = false },
    { key = 'server.announce',  label = 'Pengumuman kota (tab Pengumuman)', a = true, s = true },
    { key = 'reports.manage',   label = 'Lihat & balas laporan warga', a = true, s = true },
    { key = 'dev.tools',        label = 'Alat developer (koordinat, entity)', a = true, s = false },
    { key = 'anticheat.exempt', label = 'Kebal anti-cheat (noclip/teleport/speed tidak ditandai)', a = true, s = true },
}

-- Bawaan izin command untuk Support (command lain bawaannya hanya Admin).
Config.SupportCommands = { 'tp', 'tpm', 'dv', 'revive', 'fix', 'wash' }

-- Channel Discord. Tiap channel punya convar webhook sendiri di server.cfg;
-- channel yang convar-nya kosong ikut webhook utama.
Config.LogChannels = {
    { key = 'utama',   label = 'Utama / lainnya', convar = 'f_admin_webhook' },
    { key = 'ekonomi', label = 'Ekonomi',         convar = 'f_admin_webhook_ekonomi' },
    { key = 'sanksi',  label = 'Sanksi',          convar = 'f_admin_webhook_sanksi' },
}

-- Jenis log Discord. on = bawaan; Owner bisa mengubahnya di halaman Log Discord.
-- ch = channel (Config.LogChannels), kosong = utama.
Config.Logs = {
    { key = 'item',     label = 'Beri item', on = true, ch = 'ekonomi' },
    { key = 'vehicle',  label = 'Beri / simpan / spawn kendaraan', on = true, ch = 'ekonomi' },
    { key = 'money',    label = 'Beri / atur uang', on = true, ch = 'ekonomi' },
    { key = 'freeze',   label = 'Bekukan / bunuh pemain', on = true, ch = 'sanksi' },
    { key = 'kick',     label = 'Kick', on = true, ch = 'sanksi' },
    { key = 'ban',      label = 'Ban / cabut ban', on = true, ch = 'sanksi' },
    { key = 'mute',     label = 'Mute pemain', on = true, ch = 'sanksi' },
    { key = 'staff',    label = 'Angkat / ubah / copot staff', on = true },
    { key = 'perms',    label = 'Ubah izin Daftar Command', on = true },
    { key = 'noclip',   label = 'Noclip on/off', on = true },
    { key = 'self',     label = 'Mode staff lain (god, tidak terlihat, ped, borgol)', on = true },
    { key = 'teleport', label = 'Datangi / tarik / kembalikan pemain', on = true },
    { key = 'spectate', label = 'Spectate', on = true },
    { key = 'revive',   label = 'Revive / heal', on = true },
    { key = 'job',      label = 'Ubah job / gang', on = true },
    { key = 'data',     label = 'Ubah data pemain', on = true },
    { key = 'weapons',  label = 'Ambil semua senjata', on = true },
    { key = 'inv',      label = 'Buka inventaris / pakaian pemain', on = true },
    { key = 'dm',       label = 'Pesan ke pemain', on = false },
    { key = 'server',   label = 'Cuaca / waktu / stash / pengumuman', on = true },
    { key = 'report',   label = 'Laporan warga ditutup', on = false },
    { key = 'pet',      label = 'Setujui / tolak pengajuan hewan', on = true, ch = 'ekonomi' },
}

-- Laporan warga (/lapor, /report)
Config.Report = {
    cooldown = 60,      -- detik antar laporan per warga
    maxActive = 2,      -- laporan belum selesai per warga
    maxLength = 250,
    notifyMs = 10000,   -- lama notifikasi ox_lib
    categories = { 'Nyangkut / bug', 'Pemain melanggar', 'Item / uang hilang', 'Pertanyaan', 'Lainnya' },
}

-- Format plat kustom dari panel
Config.PlateMax = 8

Config.WeaponList = {
    pistol = { 'weapon_pistol', 'weapon_pistol_mk2', 'weapon_combatpistol', 'weapon_appistol', 'weapon_stungun', 'weapon_pistol50', 'weapon_snspistol', 'weapon_heavypistol', 'weapon_vintagepistol', 'weapon_flaregun', 'weapon_marksmanpistol', 'weapon_revolver', 'weapon_revolver_mk2', 'weapon_doubleaction', 'weapon_snspistol_mk2', 'weapon_raypistol', 'weapon_ceramicpistol', 'weapon_navyrevolver', 'weapon_gadgetpistol' },
    smg = { 'weapon_microsmg', 'weapon_smg', 'weapon_smg_mk2', 'weapon_assaultsmg', 'weapon_combatpdw', 'weapon_machinepistol', 'weapon_minismg', 'weapon_raycarbine' },
    shotgun = { 'weapon_pumpshotgun', 'weapon_sawnoffshotgun', 'weapon_assaultshotgun', 'weapon_bullpupshotgun', 'weapon_musket', 'weapon_heavyshotgun', 'weapon_dbshotgun', 'weapon_autoshotgun', 'weapon_pumpshotgun_mk2', 'weapon_combatshotgun' },
    assault = { 'weapon_assaultrifle', 'weapon_assaultrifle_mk2', 'weapon_carbinerifle', 'weapon_carbinerifle_mk2', 'weapon_advancedrifle', 'weapon_specialcarbine', 'weapon_bullpuprifle', 'weapon_compactrifle', 'weapon_specialcarbine_mk2', 'weapon_bullpuprifle_mk2', 'weapon_militaryrifle' },
    lmg = { 'weapon_mg', 'weapon_combatmg', 'weapon_gusenberg', 'weapon_combatmg_mk2' },
    sniper = { 'weapon_sniperrifle', 'weapon_heavysniper', 'weapon_marksmanrifle', 'weapon_remotesniper', 'weapon_heavysniper_mk2', 'weapon_marksmanrifle_mk2' },
    heavy = { 'weapon_rpg', 'weapon_grenadelauncher', 'weapon_grenadelauncher_smoke', 'weapon_minigun', 'weapon_firework', 'weapon_railgun', 'weapon_hominglauncher', 'weapon_compactlauncher', 'weapon_rayminigun' },
}
