fx_version 'cerulean'
game 'gta5'
lua54 'yes'
node_version '22'
use_experimental_fxv2_oal 'yes'

author 'Sky-Systems'
description 'Sky Phone'
version '0.1.0'

provide 'lb-phone'
provide '17mov_Phone'
provide 'high-phone'
provide 'qs-smartphone'
provide 'yseries'

shared_scripts {
    'config/init.lua',
    'source/bridge/shared.lua',
    'source/shared/imei.lua',
    'source/shared/sim_number.lua',
    'source/shared/custom_apps.lua',
    'source/shared/custom_app_compat.lua',
}

client_scripts {
    'config/config.lua',
    'config/locales/en.lua',
    'config/locales/de.lua',
    'source/bridge/client/framework.lua',
    'source/bridge/client/callbacks.lua',
    'source/bridge/client/housing.lua',
    'source/bridge/client/housing/*.lua',
    'source/bridge/client/calls.lua',
    'source/client/animations.lua',
    'source/client/focus.lua',
    'source/client/camera.lua',
    'source/client/garage.lua',
    'source/client/skyride.lua',
    'source/client/housing.lua',
    'source/client/crewlink.lua',
    'source/client/health.lua',
    'source/bridge/client/radio.lua',
    'source/client/payphones.lua',
    'source/client/custom_apps.lua',
    'source/client/custom_app_compat.lua',
    'source/client/main.lua',
    'source/client/radio.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'source/server/crypto_password.js',
    'config/config.lua',
    'config/media.lua',
    'config/locales/en.lua',
    'config/locales/de.lua',
    'source/server/update_check.lua',
    'source/bridge/server/database.lua',
    'source/bridge/server/migrations.lua',
    'source/bridge/server/callbacks.lua',
    'source/bridge/server/framework.lua',
    'source/bridge/server/frameworks/*.lua',
    'source/bridge/server/housing.lua',
    'source/bridge/server/housing/*.lua',
    'source/bridge/server/inventory.lua',
    'source/bridge/server/inventory/*.lua',
    'source/bridge/server/voice.lua',
    'source/server/custom_apps.lua',
    'source/server/custom_app_compat.lua',
    'source/server/media_metadata.lua',
    'source/server/companies.lua',
    'source/server/sim.lua',
    'source/server/memos.lua',
    'source/server/notes.lua',
    'source/server/phone.lua',
    'source/server/db_migrate.lua',
    'source/server/lb_phone_migration.lua',
    'source/server/custom_app_storage.lua',
    'source/server/payphones.lua',
    'source/server/calls.lua',
    'source/server/media_import.lua',
    'source/server/media_import/fivemanage.lua',
    'source/server/media_import/manifest.lua',
    'source/server/media.lua',
    'source/server/weazel_news.lua',
    'source/server/citywarn.lua',
    'source/server/messages.lua',
    'source/server/easyshare.lua',
    'source/server/darkchat.lua',
    'source/server/flare.lua',
    'source/server/mail.lua',
    'source/server/banking.lua',
    'source/server/crypto.lua',
    'source/server/health.lua',
    'source/server/billing.lua',
    'source/server/garage.lua',
    'source/server/housing.lua',
    'source/server/marketplace.lua',
    'source/server/pages.lua',
    'source/server/fliptok.lua',
    'source/server/picstagram.lua',
    'source/server/feather.lua',
    'source/server/map.lua',
    'source/server/crewlink.lua',
    'source/server/skyride.lua',
    'source/server/calendar.lua',
    'source/server/music.lua',
    'source/server/radio.lua',
    'source/server/testdata.lua',
}

files {
    'source/html/index.html',
    'source/html/assets/**',
    'source/html/img/**',
    'config/music/**',
}

ui_page 'source/html/index.html'

dependency 'oxmysql'
