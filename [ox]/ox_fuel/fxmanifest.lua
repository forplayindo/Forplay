fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'

name 'ox_fuel'
author 'Overextended'
version '1.5.4'
repository 'https://github.com/overextended/ox_fuel'
description 'Fuel management system with ox_inventory support'

dependencies {
	'ox_lib',
	'ox_inventory',
}

shared_scripts {
	'@ox_lib/init.lua',
	'config.lua'
}

server_scripts {
	'server.lua'
}

client_script 'client/init.lua'

ui_page 'html/menu.html'

files {
	'locales/*.json',
	'data/stations.lua',
	'client/*.lua',
	'shared/*.lua',
	'html/hologram.html',
	'html/menu.html',
	'html/menu.css',
	'html/menu.js',
}

ox_libs {
	'math',
	'locale',
}
