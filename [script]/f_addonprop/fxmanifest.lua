fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_addonprop'
description 'Kumpulan prop/animasi addon (stream saja, tanpa script)'
version '1.0.0'

-- Taruh prop baru di stream/<nama_pack>/ (.ydr .ytd .ytyp .ycd).
-- Semua .ytyp di subfolder otomatis terdaftar lewat glob di bawah.
data_file 'DLC_ITYP_REQUEST' 'stream/**/*.ytyp'
