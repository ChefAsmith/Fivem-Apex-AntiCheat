local playerSpawnCounts = {}
local MAX_SPAWNS_PER_WINDOW <const> = 100
local WINDOW_DURATION <const> = 5000 

AddEventHandler('entityCreating', function(entity)
    local owner = NetworkGetFirstEntityOwner(entity)
    if not owner or owner <= 0 then return end

    if IsPlayerInSpawnGrace(owner) or ApexPermissions:HasPermission(owner) or ApexPermissions:IsExcused(owner) then
        return
    end

    local populationType = GetEntityPopulationType(entity)
    if populationType >= 6 then
        return
    end

    local now = GetGameTimer()
    playerSpawnCounts[owner] = playerSpawnCounts[owner] or { count = 0, resetTime = now + WINDOW_DURATION }

    if now > playerSpawnCounts[owner].resetTime then
        playerSpawnCounts[owner].count = 1
        playerSpawnCounts[owner].resetTime = now + WINDOW_DURATION
    else
        playerSpawnCounts[owner].count = playerSpawnCounts[owner].count + 1
        if playerSpawnCounts[owner].count > MAX_SPAWNS_PER_WINDOW then
            CancelEvent()
            ApexDetections:Trigger(owner, 'EntityFlood', string.format('Script Entity Flood (%d entities in 5s)', playerSpawnCounts[owner].count))
        end
    end
end)