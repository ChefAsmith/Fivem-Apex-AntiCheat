fx_version 'cerulean'
game 'gta5'

author 'ChefAmbrosia'
description 'Pure Lua High-Performance FiveM Server & Client Anticheat'
version '3.1.0'

lua54 'yes'
use_experimental_fxv2_oal 'yes'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/cl_loops.lua',
    'client/cl_handlers.lua',
    'client/cl_variables.lua'
}

server_scripts {
    'server/sv_bans.lua',
    'server/sv_detections.lua',
    'server/sv_permissions.lua',
    'server/sv_webhook.lua',
    'server/sv_commands.lua',
    'server/sv_cloud.lua',
    'server/modules/sv_combat.lua',
    'server/modules/sv_damage.lua',
    'server/modules/sv_entities.lua',
    'server/modules/sv_entity_limiter.lua',
    'server/modules/sv_events.lua',
    'server/modules/sv_explosions.lua',
    'server/modules/sv_fire.lua',
    'server/modules/sv_particles.lua',
    'server/modules/sv_movement.lua',
    'server/modules/sv_deferrals.lua',
    'server/sv_main.lua'
}

dependencies {
    '/onesync',
    '/server:13227'
}