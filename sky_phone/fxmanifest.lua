fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

author 'Sky-Systems'
description 'Sky Phone'
version '0.1.0'

escrow_ignore {
    'config/**',
    'source/bridge/**',
}

shared_scripts {
    'config/init.lua',
    'source/bridge/shared.lua',
    'source/shared/imei.lua',
    'source/shared/sim_number.lua',
}

client_scripts {
    'config/config.lua',
    'config/locales/*.lua',
    'source/bridge/client/framework.lua',
    'source/bridge/client/callbacks.lua',
    'source/client/camera.lua',
    'source/client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/config.lua',
    'config/media.lua',
    'source/bridge/server/database.lua',
    'source/bridge/server/migrations.lua',
    'source/bridge/server/callbacks.lua',
    'source/bridge/server/framework.lua',
    'source/bridge/server/frameworks/*.lua',
    'source/bridge/server/inventory.lua',
    'source/bridge/server/inventory/*.lua',
    'source/server/db_migrate.lua',
    'source/server/phone.lua',
    'source/server/sim.lua',
    'source/server/calls.lua',
    'source/server/notes.lua',
    'source/server/mail.lua',
    'source/server/banking.lua',
    'source/server/marketplace.lua',
    'source/server/pages.lua',
    'source/server/media.lua',
    'source/server/calendar.lua',
}

files {
    'source/html/index.html',
    'source/html/assets/**',
    'source/html/img/**',
}

ui_page 'source/html/index.html'

dependency 'oxmysql'
