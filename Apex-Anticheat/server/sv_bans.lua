ApexBanManager = {
    bans = {},
    identifierLookup = {},
    tokenLookup = {}
}

local BAN_KEY <const> = 'apex:ban:%s'
local BAN_EXPIRES_KEY <const> = 'apex:record:%s:expires'
local BAN_IDENTIFIER_KEY <const> = 'apex:record:%s:id:%s'
local BAN_TOKEN_KEY <const> = 'apex:record:%s:tok:%s'

function ApexBanManager:Init()
    local handle = StartFindKvp('apex:ban:')
    local key
    repeat
        key = FindKvp(handle)
        if key then
            local banId = key:gsub('apex:ban:', '')
            local reason = GetResourceKvpString(key)
            local expires = GetResourceKvpInt(BAN_EXPIRES_KEY:format(banId))
            local ids = self:GetStoredIdentifiers(banId)
            local tokens = self:GetStoredTokens(banId)

            local record = { id = banId, reason = reason, expires = expires, identifiers = ids, tokens = tokens }
            self.bans[banId] = record

            for _, idVal in pairs(ids) do self.identifierLookup[idVal] = record end
            for _, tokVal in pairs(tokens) do self.tokenLookup[tokVal] = record end
        end
    until not key
    EndFindKvp(handle)
    print(string.format('^2[Apex-Anticheat]^7 Loaded %d persistent bans from KVP database.', self:CountBans()))
end

function ApexBanManager:CountBans()
    local count = 0
    for _ in pairs(self.bans) do count = count + 1 end
    return count
end

function ApexBanManager:GetStoredIdentifiers(banId)
    local ids = {}
    local handle = StartFindKvp(BAN_IDENTIFIER_KEY:format(banId, ''))
    local key
    repeat
        key = FindKvp(handle)
        if key then
            local idType = key:match('id:(.*)')
            ids[idType] = GetResourceKvpString(key)
        end
    until not key
    EndFindKvp(handle)
    return ids
end

function ApexBanManager:GetStoredTokens(banId)
    local tokens = {}
    local handle = StartFindKvp(BAN_TOKEN_KEY:format(banId, ''))
    local key
    repeat
        key = FindKvp(handle)
        if key then
            local idx = key:match('tok:(.*)')
            tokens[idx] = GetResourceKvpString(key)
        end
    until not key
    EndFindKvp(handle)
    return tokens
end

function ApexBanManager:Ban(source, reason, duration, customBanId)
    local src = tostring(source)
    if ApexPermissions:HasPermission(source) or ApexPermissions:IsExcused(source) then
        return
    end

    duration = duration or (365 * 86400) -- Default 1 year
    local expires = os.time() + duration
    local banId = customBanId or string.upper(string.format('%08x', math.random(0, 0xFFFFFFFF)))

    local identifiers = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then
            local idType = id:match('^([^:]+)')
            identifiers[idType] = id
        end
    end

    local tokens = {}
    for i = 0, GetNumPlayerTokens(src) - 1 do
        tokens[tostring(i)] = GetPlayerToken(src, i)
    end

    SetResourceKvp(BAN_KEY:format(banId), reason)
    SetResourceKvpInt(BAN_EXPIRES_KEY:format(banId), expires)

    for idType, idVal in pairs(identifiers) do
        SetResourceKvp(BAN_IDENTIFIER_KEY:format(banId, idType), idVal)
        self.identifierLookup[idVal] = { id = banId, reason = reason, expires = expires }
    end

    for idx, tokVal in pairs(tokens) do
        SetResourceKvp(BAN_TOKEN_KEY:format(banId, idx), tokVal)
        self.tokenLookup[tokVal] = { id = banId, reason = reason, expires = expires }
    end

    self.bans[banId] = { id = banId, reason = reason, expires = expires, identifiers = identifiers, tokens = tokens }

    ApexWebhook:SendBanAlert(source, reason, banId)
    if BroadcastStaffAlert then
        BroadcastStaffAlert(string.format('%s (%s) banned for: %s [Ban ID: %s]', GetPlayerName(src) or 'Unknown', src, reason, banId))
    end
    
    local srcNum = tonumber(src)
    for _, veh in ipairs(GetAllVehicles()) do
        if NetworkGetFirstEntityOwner(veh) == srcNum or NetworkGetEntityOwner(veh) == srcNum then DeleteEntity(veh) end
    end
    for _, ped in ipairs(GetAllPeds()) do
        if not IsPedAPlayer(ped) and (NetworkGetFirstEntityOwner(ped) == srcNum or NetworkGetEntityOwner(ped) == srcNum) then DeleteEntity(ped) end
    end
    for _, obj in ipairs(GetAllObjects()) do
        if NetworkGetFirstEntityOwner(obj) == srcNum or NetworkGetEntityOwner(obj) == srcNum then DeleteEntity(obj) end
    end
    DropPlayer(src, string.format('\n[Apex-Anticheat]\nYou have been permanently banned.\nBan ID: %s\nReason: %s', banId, reason))
end

function ApexBanManager:IsBanned(source)
    local src = tostring(source)
    local now = os.time()

    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        local record = self.identifierLookup[id]
        if record then
            if record.expires > now then return true, record else self:Revoke(record.id) end
        end
    end

    for i = 0, GetNumPlayerTokens(src) - 1 do
        local tok = GetPlayerToken(src, i)
        local record = self.tokenLookup[tok]
        if record then
            if record.expires > now then return true, record else self:Revoke(record.id) end
        end
    end

    return false, nil
end

---Revokes an active ban by Ban ID, License, or any Player Identifier
---@param banIdOrIdentifier string
---@return boolean success
function ApexBanManager:Revoke(banIdOrIdentifier)
    if not banIdOrIdentifier then return false end
    local query = tostring(banIdOrIdentifier):upper()

    -- 1. Try exact or case-insensitive Ban ID match
    local targetBanId = nil
    for id in pairs(self.bans) do
        if id:upper() == query then
            targetBanId = id
            break
        end
    end

    -- 2. Try exact identifier lookup (e.g. license:xxx, steam:xxx)
    if not targetBanId then
        local record = self.identifierLookup[banIdOrIdentifier] or self.identifierLookup[banIdOrIdentifier:lower()]
        if record then
            targetBanId = record.id
        end
    end

    -- 3. Fuzzy search inside ban records identifiers
    if not targetBanId then
        local searchLower = tostring(banIdOrIdentifier):lower()
        for id, b in pairs(self.bans) do
            for _, val in pairs(b.identifiers or {}) do
                if val:lower() == searchLower or val:lower():find(searchLower, 1, true) then
                    targetBanId = id
                    break
                end
            end
            if targetBanId then break end
        end
    end

    if not targetBanId then
        print(string.format('^1[Apex-Anticheat]^7 Revoke failed: No active ban found matching "%s"', tostring(banIdOrIdentifier)))
        return false
    end

    local ban = self.bans[targetBanId]
    if ban then
        for idType, idVal in pairs(ban.identifiers or {}) do 
            self.identifierLookup[idVal] = nil 
            DeleteResourceKvp(BAN_IDENTIFIER_KEY:format(targetBanId, idType))
        end
        for tokIndex, tokVal in pairs(ban.tokens or {}) do 
            self.tokenLookup[tokVal] = nil 
            DeleteResourceKvp(BAN_TOKEN_KEY:format(targetBanId, tokIndex))
        end
    end

    DeleteResourceKvp(BAN_KEY:format(targetBanId))
    DeleteResourceKvp(BAN_EXPIRES_KEY:format(targetBanId))
    self.bans[targetBanId] = nil

    print(string.format('^2[Apex-Anticheat]^7 Successfully revoked ban ID %s (matched via "%s").', targetBanId, tostring(banIdOrIdentifier)))
    return true
end

function ApexBanManager:RevokeAll(licenseOrTarget)
    if not licenseOrTarget then return 0 end
    local query = tostring(licenseOrTarget):lower()
    local revokedCount = 0
    local targetIdsToRemove = {}

    for banId, record in pairs(self.bans) do
        local matches = false
        if record.identifiers then
            for _, val in pairs(record.identifiers) do
                if val:lower() == query then matches = true break end
            end
        end
        if not matches and record.target and tostring(record.target):lower() == query then
            matches = true
        end

        if matches then
            table.insert(targetIdsToRemove, banId)
        end
    end

    for _, targetBanId in ipairs(targetIdsToRemove) do
        local ban = self.bans[targetBanId]
        if ban then
            for idType, idVal in pairs(ban.identifiers or {}) do 
                self.identifierLookup[idVal] = nil 
                DeleteResourceKvp(BAN_IDENTIFIER_KEY:format(targetBanId, idType))
            end
            for tokIndex, tokVal in pairs(ban.tokens or {}) do 
                self.tokenLookup[tokVal] = nil 
                DeleteResourceKvp(BAN_TOKEN_KEY:format(targetBanId, tokIndex))
            end
        end

        DeleteResourceKvp(BAN_KEY:format(targetBanId))
        DeleteResourceKvp(BAN_EXPIRES_KEY:format(targetBanId))
        self.bans[targetBanId] = nil
        revokedCount = revokedCount + 1
    end

    print(string.format('^2[Apex-Anticheat]^7 Successfully bulk-revoked %d bans matching "%s".', revokedCount, tostring(licenseOrTarget)))
    return revokedCount
end

exports('BanPlayer', function(source, reason, duration, customBanId)
    ApexBanManager:Ban(source, reason, duration, customBanId)
end)