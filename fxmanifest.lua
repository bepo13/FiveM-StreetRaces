fx_version 'cerulean'
game 'gta5'

author 'mufty'
description 'MRP Races'
version '0.0.2'

server_scripts {
    "shared/*.lua",
    "server/*.lua"
}

client_scripts {
    "shared/*.lua",
    "client/*.lua"
}

ui_page 'html/scoreboard.html'

files {
    'html/scoreboard.html',
    'html/style.css',
    'html/reset.css',
    'html/listener.js',
    'html/res/futurastd-medium.css',
    'html/res/futurastd-medium.eot',
    'html/res/futurastd-medium.woff',
    'html/res/futurastd-medium.ttf',
    'html/res/futurastd-medium.svg',
}

dependency 'mrp_core'
