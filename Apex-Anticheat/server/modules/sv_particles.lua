AddEventHandler('ptFxEvent', function(sender, data)
    if data.scale > Config.Modules.Particles.maxParticleScale then
        CancelEvent()
        ApexDetections:Trigger(sender, 'ParticleFx', string.format('Particle Scale: %.2f', data.scale))
        return
    end

    if data.isOnEntity and data.entityNetId > 0 then
        local ent = NetworkGetEntityFromNetworkId(data.entityNetId)
        local owner = NetworkGetEntityOwner(ent)
        if owner > 0 and owner ~= sender then
            CancelEvent()
            ApexDetections:Trigger(sender, 'ParticleFx', 'Particle Attached to Remote Entity')
        end
    end
end)