local blockedClientEvents = {
    "ambulancier:selfRespawn", "bank:transfer", "esx_ambulancejob:revive",
    "esx-qalle-jail:openJailMenu", "esx_jailer:wysylandoo", "esx_society:openBossMenu",
    "esx:spawnVehicle", "HCheat:TempDisableDetection", "UnJP"
}

for _, eventName in ipairs(blockedClientEvents) do
    AddEventHandler(eventName, function()
        CancelEvent()
        TriggerServerEvent('apex:clientDetection', 'ClientEventTrap', 'Triggered client honeypot: ' .. eventName)
    end)
end