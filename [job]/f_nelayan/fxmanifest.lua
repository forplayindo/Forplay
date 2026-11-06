fx_version 'cerulean'
game 'gta5'

description 'F_Nelayan - job nelayan bebas (tanpa balai kota): tug + jaring, sortir ke peti, bison ke Pasar Ikan'
version '1.0.0'

shared_script '@ox_lib/init.lua'

client_scripts {
	'@qbx_core/modules/playerdata.lua',
	'client/visual.lua',
	'client/main.lua',
	'client/proptest.lua',
}

server_scripts {
	'server/main.lua',
	'server/proptest.lua',
}

ui_page 'html/index.html'

files {
	'config/client.lua',
	'config/shared.lua',
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/ui/ios.css',
	'html/ui/fonts/*.woff2',
}

-- prop dibangun dari materi/*.glb lewat _sumber (lihat _sumber/README.txt)
data_file 'DLC_ITYP_REQUEST' 'stream/f_nelayan.ytyp'

dependencies {
	'ox_lib',
	'ox_target',
	'qbx_core',
	'f_vehiclekeys',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
