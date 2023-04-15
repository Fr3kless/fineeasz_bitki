fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Fineeasz'

client_scripts {
    'config.lua',
    'client/spheres.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/main.lua'
}

shared_scripts { 
    '@es_extended/imports.lua',
}