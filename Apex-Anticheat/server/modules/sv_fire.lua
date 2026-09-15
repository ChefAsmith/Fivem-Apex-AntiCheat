local LEGIT_FIRE_WEAPONS = {
    [GetHashKey("WEAPON_MOLOTOV")] = true,
    [GetHashKey("WEAPON_FLARE")] = true,
    [GetHashKey("WEAPON_FLAREGUN")] = true,
    [GetHashKey("WEAPON_PETROLCAN")] = true,
    [GetHashKey("WEAPON_HAZARDCAN")] = true,
    [GetHashKey("WEAPON_FERTILIZERCAN")] = true
}

AddEventHandler('fireEvent', function(sender, rawData)
    if not rawData or not rawData[1] then return end
    local data = rawData[1][1]
    if not data or not data.isEntity or sender == data.entityGlobalId then return end

    if data.weaponHash and data.weaponHash ~= 0 and not LEGIT_FIRE_WEAPONS[data.weaponHash] then
        CancelEvent()
        ApexDetections:Trigger(sender, 'WeaponModifier', string.format('Flaming Bullets active (Weapon: %s)', tostring(data.weaponHash)))
        return
    end

    local victim = NetworkGetEntityFromNetworkId(data.entityGlobalId or 0)
    if not DoesEntityExist(victim) then return end

    local senderPed = GetPlayerPed(tostring(sender))
    local dist = #(GetEntityCoords(senderPed) - GetEntityCoords(victim))

    -- 2. Fire Distance Exploit
    if dist > Config.Modules.Fire.maxFireDistance then
        CancelEvent()
        ApexDetections:Trigger(sender, 'FireExploit', string.format('Fire Distance Exploit (%.2fm)', dist))
    end
end)