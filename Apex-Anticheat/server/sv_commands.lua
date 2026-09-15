local staffAlertSubscribers = {}

local function SendFeedback(source, msg)
    if source == 0 then
        print(msg:gsub('%^%d', ''))
    else
        TriggerClientEvent('chat:addMessage', source, { args = { msg } })
    end
end

RegisterCommand('apexalerts', function(source)
    if source ~= 0 and not IsPlayerAceAllowed(tostring(source), 'command.apex') then return end
    staffAlertSubscribers[source] = not staffAlertSubscribers[source]
    local state = staffAlertSubscribers[source] and '^2ENABLED^0' or '^1DISABLED^0'
    SendFeedback(source, '^3[Apex]^0 Staff alerts ' .. state)
end, false)

function BroadcastStaffAlert(message)
    for staffId, active in pairs(staffAlertSubscribers) do
        if active and (staffId == 0 or DoesPlayerExist(tostring(staffId))) then
            if staffId == 0 then
                print(message:gsub('%^%d', ''))
            else
                TriggerClientEvent('chat:addMessage', staffId, { args = { '^1[Apex Alert]^0 ' .. message } })
            end
        end
    end
end

AddEventHandler('playerDropped', function()
    staffAlertSubscribers[source] = nil
end)

RegisterCommand('apexban', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(tostring(source), 'command.apex') then return end
    local target = tonumber(args[1])
    local hours = tonumber(args[2]) or 24
    local reason = table.concat(args, ' ', 3)

    if not target or not DoesEntityExist(GetPlayerPed(tostring(target))) or reason == '' then
        SendFeedback(source, '^1[Apex]^0 Usage: /apexban <playerId> <hours> <reason>')
        return
    end

    ApexBanManager:Ban(target, 'Manual Ban by Staff: ' .. reason, hours * 3600)
    SendFeedback(source, string.format('^2[Apex]^0 Successfully banned player %d for %d hours.', target, hours))
end, true)

RegisterCommand('apexlookup', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(tostring(source), 'command.apex') then return end
    local target = tonumber(args[1])
    if not target or not DoesEntityExist(GetPlayerPed(tostring(target))) then
        SendFeedback(source, '^1[Apex]^0 Usage: /apexlookup <playerId>')
        return
    end

    local srcStr = tostring(target)
    local name = GetPlayerName(srcStr) or 'Unknown'
    local ping = GetPlayerPing(srcStr)
    local tokensCount = GetNumPlayerTokens(srcStr)

    SendFeedback(source, string.format('^3--- [Apex Lookup: %s (ID %d)] ---^0', name, target))
    SendFeedback(source, string.format('^2Ping:^0 %dms | ^2HWID Tokens:^0 %d', ping, tokensCount))

    for i = 0, GetNumPlayerIdentifiers(srcStr) - 1 do
        local id = GetPlayerIdentifier(srcStr, i)
        SendFeedback(source, '^3Identifier:^0 ' .. id)
    end
end, true)

RegisterCommand('apex', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(tostring(source), 'command.apex') then return end
    local subCmd = (args[1] or ''):lower()

    if subCmd == 'detections' or subCmd == 'list' then
        SendFeedback(source, '^3=== [Apex Active Detections] ===^0')
        for key, info in pairs(ApexDetections.settings) do
            local stateColor = info.enabled and '^2[ON]^0' or '^1[OFF]^0'
            local punishColor = '^3' .. info.punishment:upper() .. '^0'
            SendFeedback(source, string.format('%s ^7%-20s^0 -> Punishment: %s', stateColor, key, punishColor))
        end

    elseif subCmd == 'set' then
        local detKey = args[2]
        local action = (args[3] or ''):lower()
        if not detKey or (action ~= 'on' and action ~= 'off' and action ~= 'true' and action ~= 'false') then
            SendFeedback(source, '^1[Apex]^0 Usage: /apex set <detectionName> <on|off>')
            return
        end
        local state = (action == 'on' or action == 'true')
        local success, resolvedKey = ApexDetections:SetEnabled(detKey, state)
        if success then
            SendFeedback(source, string.format('^2[Apex]^0 Detection ^3%s^0 is now %s.', resolvedKey, state and '^2ENABLED^0' or '^1DISABLED^0'))
        else
            SendFeedback(source, string.format('^1[Apex]^0 Detection \'%s\' not found. Use /apex detections to list.', detKey))
        end

    elseif subCmd == 'punish' then
        local detKey = args[2]
        local punishType = (args[3] or ''):lower()
        if not detKey or (punishType ~= 'ban' and punishType ~= 'kick' and punishType ~= 'warn' and punishType ~= 'alert') then
            SendFeedback(source, '^1[Apex]^0 Usage: /apex punish <detectionName> <ban|kick|warn|alert>')
            return
        end
        local success, resolvedKey = ApexDetections:SetPunishment(detKey, punishType)
        if success then
            SendFeedback(source, string.format('^2[Apex]^0 Punishment for ^3%s^0 set to ^2%s^0.', resolvedKey, punishType:upper()))
        else
            SendFeedback(source, string.format('^1[Apex]^0 Detection \'%s\' not found.', detKey))
        end

    elseif subCmd == 'reset' then
        local detKey = args[2] or 'all'
        local success, resolvedKey = ApexDetections:Reset(detKey)
        if success then
            SendFeedback(source, string.format('^2[Apex]^0 Reset detection(s) ^3%s^0 back to config defaults.', resolvedKey))
        else
            SendFeedback(source, string.format('^1[Apex]^0 Detection \'%s\' not found.', detKey))
        end

    elseif subCmd == 'wipe' or subCmd == 'clear' then
        local target = args[2] or 'all'
        local count = 0

        if target == 'all' or target == 'vehicles' then
            for _, veh in ipairs(GetAllVehicles()) do DeleteEntity(veh); count = count + 1 end
        end
        if target == 'all' or target == 'peds' then
            for _, ped in ipairs(GetAllPeds()) do
                if not IsPedAPlayer(ped) then DeleteEntity(ped); count = count + 1 end
            end
        end
        if target == 'all' or target == 'objects' then
            for _, obj in ipairs(GetAllObjects()) do DeleteEntity(obj); count = count + 1 end
        end

        SendFeedback(source, string.format('^2[Apex]^0 Cleared %d entities (%s).', count, target))

    elseif subCmd == 'unban' then
        local banId = args[2]
        if not banId then
            SendFeedback(source, '^1[Apex]^0 Usage: /apex unban <banId>')
            return
        end

        local success = ApexBanManager:Revoke(banId)
        if success then
            SendFeedback(source, string.format('^2[Apex]^0 Successfully revoked ban ID: %s', banId))
        else
            SendFeedback(source, string.format('^1[Apex]^0 Ban ID %s not found.', banId))
        end

    local target = tonumber(args[2])
        if not target or not DoesEntityExist(GetPlayerPed(tostring(target))) then
            SendFeedback(source, '^1[Apex]^0 Player not found.')
            return
        end

        if GetResourceState('screenshot-basic') == 'started' then
            SendFeedback(source, string.format('^3[Apex]^0 Capturing screenshot for player %d...', target))
            exports['screenshot-basic']:requestClientScreenshot(target, {
                encoding = 'png'
            }, function(err, data)
                if err or not data then
                    SendFeedback(source, string.format('^1[Apex ERROR]^0 Screenshot capture failed: %s', tostring(err)))
                    return
                end

                if Config.Cloud.enabled and Config.Cloud.panelUrl ~= '' then
                    PerformHttpRequest(Config.Cloud.panelUrl .. '/api/server/upload-screenshot-base64', function(status, body)
                        SendFeedback(source, string.format('^2[Apex]^0 Screenshot uploaded to Web Panel for player %d', target))
                    end, 'POST', json.encode({
                        target = target,
                        image = data
                    }), {
                        ['Content-Type'] = 'application/json',
                        ['X-Server-Key'] = Config.Cloud.serverKey
                    })
                end

                if Config.DiscordWebhook and Config.DiscordWebhook ~= '' then
                    ApexWebhook:SendAlert(target, 'SCREENSHOT', 'Manual screenshot requested by console', 'Admin')
                end
            end)
        else
            SendFeedback(source, '^1[Apex]^0 screenshot-basic is not started.')
        end
    else
        SendFeedback(source, '^3[Apex Anticheat Commands]^0\n' ..
            '/apex detections - View active detections & punishments\n' ..
            '/apex set <detection> <on|off> - Toggle detection\n' ..
            '/apex punish <detection> <ban|kick|warn|alert> - Change punishment\n' ..
            '/apex reset [detection|all] - Reset to config defaults\n' ..
            '/apex wipe [all|vehicles|peds|objects] - Entity cleanup\n' ..
            '/apex unban <banId> - Revoke ban\n' ..
            '/apexban <id> <hours> <reason> - Manual staff ban\n' ..
            '/apexlookup <id> - Inspect tokens/identifiers\n' ..
            '/apexalerts - Toggle staff in-game alerts')
    end
end, true)