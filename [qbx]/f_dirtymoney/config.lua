Config = {}

-- Nama akun qbx_core yang menyimpan bagian kotor dari cash pemain
-- (harus ada di qbx_core config/server.lua -> money.moneyTypes)
Config.Account = 'dirty'

-- Item lama yang otomatis dikonversi jadi cash kotor saat masuk ke inventory pemain
Config.OldItem = 'black_money'

-- Notifikasi saat setor bank ditolak, %s = nominal kotor yang ikut disetor
Config.DepositRejected = 'Bank Menolak, ada %s asal usulnya tidak jelas'

-- Perintah admin untuk memberi cash kotor (tes): /uangkotor [id] [jumlah]
Config.AdminCommand = 'uangkotor'
Config.AdminGroup = 'group.admin'
