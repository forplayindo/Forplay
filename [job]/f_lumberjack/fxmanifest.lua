fx_version 'cerulean'
game 'gta5'

description 'F_Lumberjack - penebang kayu: tebang pohon, solo potong & panggul ke Biff, kru angkat batang besar berdua ke flatbed, olah di sawmill Paleto jadi papan'
version '2.0.0'

shared_script '@ox_lib/init.lua'

client_scripts {
	'@qbx_core/modules/playerdata.lua',
	'client/main.lua',      -- harus pertama: membuat tabel FLJ
	'client/world.lua',
	'client/carry.lua',
	'client/truck.lua',
	'client/sawmill.lua',
	'client/kayutes.lua',   -- sementara: /kayutes uji Biff + prop kayu
}

server_script 'server/main.lua'

ui_page 'html/index.html'

files {
	'config/client.lua',
	'config/shared.lua',
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/sfx/*.mp3',
	'html/ui/ios.css',
	'html/ui/fonts/*.woff2',
}

dependencies {
	'ox_lib',
	'ox_target',
	'ox_inventory',
	'qbx_core',
	'f_vehiclekeys',
	'f_addonprop',          -- prop chainsaw, tumpukan papan
	'f_carjob',             -- 17mov_flatbed (truk kru)
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
