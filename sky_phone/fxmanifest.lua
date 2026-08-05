fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Sky-Systems'
description 'Sky Phone'
version '0.1.0'

escrow_ignore 'config/**'

shared_scripts {
    '@sky_base/source/import.lua',
    '@sky_jobs_base/source/import.lua',
    'config/init.lua',
    'source/shared/imei.lua',
    'source/shared/sim_number.lua',
}

client_scripts {
    'config/config.lua',
    'config/locales/*.lua',
    'source/client/main.lua',
}

server_scripts {
    'config/config.lua',
    'source/server/db_migrate.lua',
    'source/server/phone.lua',
    'source/server/sim.lua',
    'source/server/calls.lua',
    'source/server/notes.lua',
    'source/server/mail.lua',
}

files {
    'source/html/index.html',
    'source/html/assets/**',
    'source/html/img/**',
}

ui_page 'source/html/index.html'

dependencies { 'sky_base', 'sky_jobs_base' }
