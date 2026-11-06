fx_version 'cerulean'
game 'gta5'

description 'F_ClaimReward - /hadiah: kode referral, hadiah harian, gacha & toko koin (server-authoritative)'
version '1.0.0'

shared_script '@ox_lib/init.lua'

client_script 'client/main.lua'
server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/main.lua',
	'server/player.lua',
	'server/admin.lua',
}

ui_page 'html/index.html'

-- config/server.lua sengaja tidak ada di files: daftar admin & peluang gacha tidak dikirim ke client
files {
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/ui/ios.css',
	'html/ui/fonts/*.woff2',
}

dependencies {
	'oxmysql',
	'ox_lib',
	'ox_inventory',
	'qbx_core',
	-- f_vehicles sengaja tidak di sini: resource itu server_only, client akan gagal start
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
