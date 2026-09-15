for _, eventName in ipairs(Config.BlacklistedEvents) do
    RegisterNetEvent(eventName, function(...)
        local src = source
        CancelEvent()
        ApexDetections:Trigger(src, 'BlacklistedEvent', 'Triggered Event: ' .. eventName)
    end)
end