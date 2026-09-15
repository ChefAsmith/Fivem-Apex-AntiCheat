AddEventHandler('weaponDamageEvent', function(sender, data)
    if WasEventCanceled() then return end
    local targetEntity = NetworkGetEntityFromNetworkId(data.hitGlobalId or data.hitGlobalIds[1] or 0)
    if DoesEntityExist(targetEntity) and IsPedAPlayer(targetEntity) then
        local targetSrc = tostring(NetworkGetEntityOwner(targetEntity))
        if GetPlayerInvincible(targetSrc) then
            CancelEvent()
            ApexDetections:Trigger(tonumber(targetSrc), 'Godmode', 'Invincibility active on victim')
        end
    end
end)