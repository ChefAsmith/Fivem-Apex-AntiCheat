local heartbeats = {}
local CONNECT_GRACE_PERIOD <const> = 60

RegisterNetEvent('apex:heartbeat', function()
    heartbeats[source] = os.time()
end)

AddEventHandler('playerJoining', function()
    heartbeats[source] = os.time() + CONNECT_GRACE_PERIOD
end)

AddEventHandler('playerDropped', function()
    heartbeats[source] = nil
end)

CreateThread(function()
    while true do
        Wait(15000)
        local now = os.time()
        for _, player in ipairs(GetPlayers()) do
            local src = tonumber(player)
            if src then
                local lastBeat = heartbeats[src]
                if not lastBeat or (now - lastBeat) > 60 then
                    DropPlayer(tostring(src), '[Apex-Anticheat] Client integrity timed out (Heartbeat missed).')
                end
            end
        end
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    local now = os.time()
    for _, player in ipairs(GetPlayers()) do
        local src = tonumber(player)
        if src then heartbeats[src] = now + 60 end
    end

    ApexBanManager:Init()
    ApexDetections:Init()
    ApexPermissions:Init()

    local recommended = {
        { name = 'onesync', val = 'on' },
        { name = 'sv_scriptHookAllowed', val = 'false' },
        { name = 'sv_enableNetworkedSounds', val = 'false' },
        { name = 'sv_enableNetworkedScriptEntityStates', val = 'false' },
        { name = 'sv_filterRequestControl', val = '4' }
    }

    for _, c in ipairs(recommended) do
        local cur = GetConvar(c.name, 'none')
        if cur ~= 'none' and cur ~= c.val then
            print(string.format('^3[Apex WARNING]^7 ConVar \'%s\' is not set to recommended value \'%s\' (Current: %s)', c.name, c.val, cur))
        end
    end

    print('^2[Apex-Anticheat]^7 Successfully started with Lua engine.')
end)