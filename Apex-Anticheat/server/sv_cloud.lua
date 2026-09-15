if not Config.Cloud or not Config.Cloud.enabled then return end

ApexCloud = {
    pendingAcks = {}
}

local function CloudRequest(endpoint, payload, callback)
    local url = string.format('%s%s', Config.Cloud.panelUrl, endpoint)
    PerformHttpRequest(url, function(statusCode, resultData, headers)
        if callback then
            local decoded = nil
            if statusCode == 200 and resultData and resultData ~= '' then
                local success, data = pcall(json.decode, resultData)
                if success then decoded = data end
            end
            callback(statusCode, decoded, resultData)
        end
    end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json',
        ['X-Server-Key'] = Config.Cloud.serverKey
    })
end

function ApexCloud:GetServerSnapshot()
    local players = {}
    for _, srcStr in ipairs(GetPlayers()) do
        local src = tonumber(srcStr)
        local ids = {}
        for i = 0, GetNumPlayerIdentifiers(srcStr) - 1 do
            local id = GetPlayerIdentifier(srcStr, i)
            local idType = id:match('^([^:]+)')
            ids[idType] = id
        end

        table.insert(players, {
            source = src,
            name = GetPlayerName(srcStr) or 'Unknown',
            ping = GetPlayerPing(srcStr),
            tokensCount = GetNumPlayerTokens(srcStr),
            identifiers = ids
        })
    end

    -- Harvest active KVP bans to synchronize with Cloud Dashboard
    local activeBans = {}
    if ApexBanManager and ApexBanManager.bans then
        for banId, record in pairs(ApexBanManager.bans) do
            local license = 'N/A'
            if record.identifiers then
                license = record.identifiers.license or record.identifiers.steam or 'N/A'
            end
            table.insert(activeBans, {
                banId = banId,
                reason = record.reason,
                expires = record.expires,
                license = license,
                identifiers = record.identifiers or {}
            })
        end
    end

    return {
        serverKey = Config.Cloud.serverKey,
        serverName = GetConvar('sv_hostname', 'FiveM Game Server'),
        onlinePlayers = players,
        playerCount = #players,
        detections = ApexDetections and ApexDetections.settings or {},
        totalBans = #activeBans,
        bans = activeBans,
        uptime = math.floor(GetGameTimer() / 1000),
        ackCommands = self.pendingAcks
    }
end

function ApexCloud:SendViolation(source, playerName, detectionKey, punishment, reason)
    local srcStr = tostring(source)
    local ped = GetPlayerPed(srcStr)
    local coords = DoesEntityExist(ped) and GetEntityCoords(ped) or vector3(0, 0, 0)

    CloudRequest('/api/server/violation', {
        serverKey = Config.Cloud.serverKey,
        source = source,
        playerName = playerName,
        detection = detectionKey,
        punishment = punishment,
        reason = reason,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        timestamp = os.time()
    })
end

function ApexCloud:ProcessCommands(commands)
    if not commands or #commands == 0 then return end
    self.pendingAcks = {}

    for _, cmd in ipairs(commands) do
        local cmdId = cmd.id
        local action = cmd.action

        if action == 'ban' then
            local target = tonumber(cmd.target)
            if target and DoesEntityExist(GetPlayerPed(tostring(target))) then
                local duration = (tonumber(cmd.hours) or 24) * 3600
                ApexBanManager:Ban(target, 'Cloud Panel Ban: ' .. (cmd.reason or 'No reason provided'), duration, cmd.banId)
            end

        elseif action == 'kick' then
            local target = tonumber(cmd.target)
            if target and DoesEntityExist(GetPlayerPed(tostring(target))) then
                DropPlayer(tostring(target), '[Apex Cloud] ' .. (cmd.reason or 'Kicked from Web Panel'))
            end

        elseif action == 'unban' then
            local revoked = false
            if cmd.banId then
                revoked = ApexBanManager:Revoke(cmd.banId)
            end
            if not revoked and cmd.license then
                revoked = ApexBanManager:Revoke(cmd.license)
            end
            if not revoked and cmd.target then
                revoked = ApexBanManager:Revoke(cmd.target)
            end

            if revoked then
                print(string.format('^2[Apex Cloud]^7 Successfully unbanned player: %s', tostring(cmd.banId or cmd.license or cmd.target)))
            else
                print(string.format('^1[Apex Cloud WARNING]^7 Could not find ban matching: %s', tostring(cmd.banId or cmd.license or cmd.target)))
            end

        elseif action == 'set_detection' then
            if cmd.detection and cmd.enabled ~= nil then
                ApexDetections:SetEnabled(cmd.detection, cmd.enabled == true)
            end

        elseif action == 'set_punishment' then
            if cmd.detection and cmd.punishment then
                ApexDetections:SetPunishment(cmd.detection, cmd.punishment)
            end

        elseif action == 'unban_all' then
            if cmd.license then
                local count = ApexBanManager:RevokeAll(cmd.license)
                print(string.format('^2[Apex Cloud]^7 Bulk unbanned %d entries for %s', count, cmd.license))
            end

        elseif action == 'screenshot' then
            local target = tonumber(cmd.target)
            if target and DoesEntityExist(GetPlayerPed(tostring(target))) then
                local targetStr = tostring(target)
                local pName = GetPlayerName(targetStr) or cmd.playerName or ('Player ' .. targetStr)
                local pLicense = 'N/A'
                for i = 0, GetNumPlayerIdentifiers(targetStr) - 1 do
                    local id = GetPlayerIdentifier(targetStr, i)
                    if id and id:sub(1, 8) == 'license:' then
                        pLicense = id
                        break
                    end
                end

                if GetResourceState('screenshot-basic') == 'started' then
                    exports['screenshot-basic']:requestClientScreenshot(target, {
                        encoding = 'png'
                    }, function(err, data)
                        if err or not data then
                            print(string.format('^1[Apex Cloud ERROR]^7 Screenshot failed for %s (%d): %s', pName, target, tostring(err)))
                            return
                        end

                        PerformHttpRequest(Config.Cloud.panelUrl .. '/api/server/upload-screenshot-base64', function(status, body)
                            if status == 200 then
                                print(string.format('^2[Apex Cloud]^7 Screenshot saved to panel for %s (%d)', pName, target))
                            else
                                print(string.format('^1[Apex Cloud ERROR]^7 Panel upload failed with status %s', tostring(status)))
                            end
                        end, 'POST', json.encode({
                            target = target,
                            playerName = pName,
                            license = pLicense,
                            image = data
                        }), {
                            ['Content-Type'] = 'application/json',
                            ['X-Server-Key'] = Config.Cloud.serverKey
                        })
                    end)
                else
                    print('^1[Apex Cloud ERROR]^7 screenshot-basic resource is not started!')
                end
            end

        elseif action == 'wipe' then
            local entityType = cmd.target or 'all'
            if entityType == 'all' or entityType == 'vehicles' then
                for _, veh in ipairs(GetAllVehicles()) do DeleteEntity(veh) end
            end
            if entityType == 'all' or entityType == 'peds' then
                for _, p in ipairs(GetAllPeds()) do
                    if not IsPedAPlayer(p) then DeleteEntity(p) end
                end
            end
            if entityType == 'all' or entityType == 'objects' then
                for _, obj in ipairs(GetAllObjects()) do DeleteEntity(obj) end
            end

        elseif action == 'exec' then
            if cmd.command then
                ExecuteCommand(cmd.command)
            end
        end

        table.insert(self.pendingAcks, cmdId)
    end
end

CreateThread(function()
    Wait(3000)
    print('^2[Apex-Anticheat]^7 Connecting to Cloud Dashboard at ' .. Config.Cloud.panelUrl .. ' ...')
    local firstSync = false

    while true do
        Wait(Config.Cloud.syncInterval or 3000)
        local snapshot = ApexCloud:GetServerSnapshot()

        CloudRequest('/api/server/sync', snapshot, function(status, response, rawData)
            if status == 200 and response then
                if not firstSync then
                    print('^2[Apex Cloud]^7 Successfully connected and synced with Dashboard!')
                    firstSync = true
                end
                if response.commands then
                    ApexCloud:ProcessCommands(response.commands)
                end
            elseif status == 401 or status == 403 then
                print('^1[Apex Cloud ERROR]^7 Authentication failed! Verify Config.Cloud.serverKey matches SERVER_KEY in panel_server.js.')
            elseif status == 0 then
                print(string.format('^1[Apex Cloud ERROR]^7 Connection refused to %s. Ensure "node panel_server.js" is running!', Config.Cloud.panelUrl))
            else
                print(string.format('^1[Apex Cloud ERROR]^7 Dashboard returned HTTP %s: %s', tostring(status), tostring(rawData)))
            end
        end)
    end
end)