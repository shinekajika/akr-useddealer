fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'akr-useddealer'
description 'Staffed used car dealership for QBCore + OX'
author        'shinekajika'
version     '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
    'client/dealer.lua',
    'client/nui.lua',
    'client/shop.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/listings.lua',
    'server/garage.lua',
    'server/shop.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qb-core',
    'jg-dealerships',
    'jg-advancedgarages',
}