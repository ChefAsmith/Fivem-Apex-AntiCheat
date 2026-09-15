local defaultExplosionTypes = {
    6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
    22, 23, 24, 27, 28, 30, 31, 34, 38, 39, 78, 79
}

local explosionConfig = (Config.Modules and Config.Modules.ExplosionFilter) or {
    whitelistedExplosionTypes = defaultExplosionTypes,
    hydrantExplosion = true
}

local whitelistedExplosions = {}
for _, exp in ipairs(explosionConfig.whitelistedExplosionTypes or defaultExplosionTypes) do
    whitelistedExplosions[exp] = true
end

AddEventHandler('explosionEvent', function(sender, data)
    local coords = vector3(data.posX, data.posY, data.posZ)

    -- 1. Protected Explosion Zones
    for _, zone in ipairs(Config.ProtectedExplosionZones or {}) do
        if #(zone.coords - coords) <= zone.radius then
            CancelEvent()
            return
        end
    end

    -- 2. Non-whitelisted Explosion Type
    if not whitelistedExplosions[data.explosionType] then
        CancelEvent()
        ApexDetections:Trigger(sender, 'ExplosionFilter', 'Non-Whitelisted Explosion Type: ' .. tostring(data.explosionType))
        return
    end

    -- 3. Damage Scale & Invisible Explosions
    if data.damageScale > 1.0 or data.isInvisible then
        CancelEvent()
        ApexDetections:Trigger(sender, 'ExplosionFilter', string.format('Explosion Exploit (Scale: %.2f, Invisible: %s)', data.damageScale, tostring(data.isInvisible)))
        return
    end

    -- 4. Hydrant Explosion Troll
    if explosionConfig.hydrantExplosion and data.explosionType == 13 and data.ownerNetId == 0 and not data.f242 and not data.f243 then
        CancelEvent()
        ApexDetections:Trigger(sender, 'ExplosionFilter', 'Hydrant Fountain Explosion')
        return
    end
end)