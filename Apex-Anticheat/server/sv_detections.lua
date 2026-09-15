ApexDetections = {
    settings = {}
}

local KVP_ENABLED_KEY <const> = 'apex:det:%s:enabled'
local KVP_PUNISH_KEY <const>  = 'apex:det:%s:punish'

-- Per-player detection cooldown cache: [source][detectionKey] = { time = os.time(), count = 1 }
local DetectionCooldowns = {}

-- Clean up player data on disconnect to prevent memory leaks
AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if src then
        DetectionCooldowns[src] = nil
    end
end)

function ApexDetections:Init()
    for key, data in pairs(Config.Detections or {}) do
        local savedEnabled = nil
        local savedPunish  = nil

        if not Config.ForceConfigDefaults then
            savedEnabled = GetResourceKvpString(KVP_ENABLED_KEY:format(key))
            savedPunish  = GetResourceKvpString(KVP_PUNISH_KEY:format(key))
        end

        self.settings[key] = {
            enabled = (savedEnabled ~= nil) and (savedEnabled == 'true') or data.enabled,
            punishment = savedPunish or data.punishment or 'warn'
        }
    end
    print('^2[Apex-Anticheat]^7 Central Detection & Punishment Controller initialized.')
end

function ApexDetections:Get(key)
    return self.settings[key]
end

function ApexDetections:FindKey(keyInput)
    if not keyInput then return nil end
    local search = keyInput:lower()
    for k in pairs(self.settings) do
        if k:lower() == search then
            return k
        end
    end
    return nil
end

function ApexDetections:SetEnabled(key, state)
    local exactKey = self:FindKey(key)
    if not exactKey then return false end

    self.settings[exactKey].enabled = state
    SetResourceKvp(KVP_ENABLED_KEY:format(exactKey), tostring(state))
    self:SyncClientDetections()
    return true, exactKey
end

function ApexDetections:SetPunishment(key, punishment)
    local exactKey = self:FindKey(key)
    if not exactKey then return false end
    punishment = punishment:lower()
    if punishment ~= 'ban' and punishment ~= 'kick' and punishment ~= 'warn' and punishment ~= 'alert' then
        return false
    end

    self.settings[exactKey].punishment = punishment
    SetResourceKvp(KVP_PUNISH_KEY:format(exactKey), punishment)
    return true, exactKey
end

function ApexDetections:Reset(key)
    if key and key ~= 'all' then
        local exactKey = self:FindKey(key)
        if not exactKey or not Config.Detections[exactKey] then return false end
        DeleteResourceKvp(KVP_ENABLED_KEY:format(exactKey))
        DeleteResourceKvp(KVP_PUNISH_KEY:format(exactKey))
        self.settings[exactKey] = {
            enabled = Config.Detections[exactKey].enabled,
            punishment = Config.Detections[exactKey].punishment
        }
        self:SyncClientDetections()
        return true, exactKey
    else
        for k, data in pairs(Config.Detections or {}) do
            DeleteResourceKvp(KVP_ENABLED_KEY:format(k))
            DeleteResourceKvp(KVP_PUNISH_KEY:format(k))
            self.settings[k] = { enabled = data.enabled, punishment = data.punishment }
        end
        self:SyncClientDetections()
        return true, 'all'
    end
end

function ApexDetections:SyncClientDetections(target)
    local clientStates = {}
    for k, v in pairs(self.settings) do
        clientStates[k] = v.enabled
    end
    TriggerClientEvent('apex:syncDetections', target or -1, clientStates)
end

AddEventHandler('playerJoining', function()
    local src = source
    ApexDetections:SyncClientDetections(src)
end)

---Dispatches private warnings to the target player
---@param target number Server ID of the offender
---@param reason string Violation description
function ApexDetections:WarnPlayer(target, reason)
    local src = tonumber(target)
    if not src or not DoesPlayerExist(tostring(src)) then return end

    local warnConfig = Config.Warning or { useTxAdmin = true, sendPrivateChat = true, showHudTicker = true }
    local authorName = "Apex Anticheat"
    local warningMessage = "Suspicious activity detected: " .. reason

    -- 1. Primary: Official txAdmin In-Game Warning Modal
    if warnConfig.useTxAdmin then
        TriggerClientEvent('txcl:showWarning', src, authorName, warningMessage, 'APEX-WARN', true)
    end

    -- 2. Backup: Target-isolated Private Chat Message
    if warnConfig.sendPrivateChat then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 50, 50 },
            multiline = true,
            args = { '^1[Apex Warning]^0', warningMessage }
        })
    end

    -- 3. Native Screen HUD Feed Notification
    if warnConfig.showHudTicker then
        TriggerClientEvent('apex:showWarningNotification', src, warningMessage)
    end
end

---Handles any triggered detection
---@param source number
---@param detectionKey string
---@param reason string
---@return boolean handled
function ApexDetections:Trigger(source, detectionKey, reason)
    local src = tonumber(source)
    if not src then return false end

    -- 1. Check Permissions & Excuses
    if ApexPermissions:HasPermission(src, detectionKey) or ApexPermissions:IsExcused(src, detectionKey) then
        return false
    end

    -- 2. Verify Detection State
    local config = self:Get(detectionKey)
    if not config or not config.enabled then
        return false
    end

    local punishment = config.punishment or 'warn'
    local srcStr = tostring(src)
    local playerName = GetPlayerName(srcStr) or 'Unknown'

    -- 3. Cooldown & Rate-Limit Check
    -- RULE: Detections configured for "ban" NEVER have a cooldown!
    if punishment ~= 'ban' then
        local now = os.time()
        local cooldownDuration = Config.DetectionCooldown or 15

        DetectionCooldowns[src] = DetectionCooldowns[src] or {}
        local entry = DetectionCooldowns[src][detectionKey]

        if entry and (now - entry.time) < cooldownDuration then
            -- Currently in cooldown window: increment violation count and suppress spam
            entry.count = entry.count + 1
            return false
        end

        -- If previous violations occurred during cooldown, append the count to the reason
        if entry and entry.count > 1 then
            reason = string.format('%s (Repeated %dx in last %ds)', reason, entry.count, cooldownDuration)
        end

        -- Reset cooldown window
        DetectionCooldowns[src][detectionKey] = { time = now, count = 1 }
    end

    -- 4. Notify Cloud Web Panel
    if ApexCloud and ApexCloud.SendViolation then
        ApexCloud:SendViolation(src, playerName, detectionKey, punishment, reason)
    end

    -- 5. Execute Punishment
    if punishment == 'ban' then
        ApexBanManager:Ban(src, reason)
    elseif punishment == 'kick' then
        ApexWebhook:SendAlert(src, 'KICK', reason, detectionKey)
        if BroadcastStaffAlert then
            BroadcastStaffAlert(string.format('^1[KICK]^0 %s (%s) was kicked for: %s', playerName, srcStr, reason))
        end
        DropPlayer(srcStr, string.format('\n[Apex-Anticheat]\nYou were kicked by anticheat.\nReason: %s', reason))
    elseif punishment == 'warn' then
        ApexWebhook:SendAlert(src, 'WARN', reason, detectionKey)
        if BroadcastStaffAlert then
            BroadcastStaffAlert(string.format('^3[WARN]^0 %s (%s) triggered: %s', playerName, srcStr, reason))
        end
        self:WarnPlayer(src, reason)
    elseif punishment == 'alert' then
        ApexWebhook:SendAlert(src, 'FLAGGED (STAFF REVIEW)', reason, detectionKey)
        if BroadcastStaffAlert then
            BroadcastStaffAlert(string.format('^5[STAFF REVIEW NEEDED]^0 %s (%s) flagged for: %s. Use ^3/apexlookup %s^0 to spectate/investigate!', playerName, srcStr, reason, srcStr))
        end
    end

    return true
end

-- Sole Client Detection Event Receiver
RegisterNetEvent('apex:clientDetection', function(detectionKey, details)
    local src = source
    ApexDetections:Trigger(src, detectionKey, details)
end)