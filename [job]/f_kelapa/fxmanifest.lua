fx_version 'cerulean'
game 'gta5'

description 'F_Kelapa - panjat pohon kelapa di kebun Paleto, petik [E], pungut kelapa_muda, jual di f_koperasi'
version '1.0.0'

shared_script '@ox_lib/init.lua'

client_script 'client/main.lua'
server_script 'server/main.lua'

files {
	'config/shared.lua',
	'config/pohon.lua',
}

dependencies {
	'ox_lib',
	'ox_target',
	'ox_inventory',
	'qbx_core',
	'f_addonprop',          -- prop f_kelapa_pohon / f_kelapa_buah + ymap kebun
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
