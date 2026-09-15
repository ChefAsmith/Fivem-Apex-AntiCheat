ApexPermissions = {
    permitted = {},
    excuses = {}
}

ApexSpawnGrace = {}

function IsPlayerInSpawnGrace(source)
    local src = tonumber(source)
    if not src then return false end
    return os.time() < (ApexSpawnGrace[src] or 0)
end

function SetPlayerSpawnGrace(source, seconds)
    local src = tonumber(source)
    if not src then return end
    ApexSpawnGrace[src] = os.time() + (seconds or 45)
end

-- Give 45 seconds on initial connection to download assets & spawn
AddEventHandler('playerJoining', function()
    SetPlayerSpawnGrace(source, 45)
end)

-- Give 30 seconds on character spawn/respawn
RegisterNetEvent('playerSpawned', function()
    SetPlayerSpawnGrace(source, 30)
end)

AddEventHandler('respawnPlayerPedEvent', function(source)
    SetPlayerSpawnGrace(source, 30)
end)

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if src then
        ApexSpawnGrace[src] = nil
    end
end)

function ApexPermissions:Init()
    if Config.Permission.useTxAdmin then
        AddEventHandler('txAdmin:events:adminAuth', function(data)
            local src = data.netid
            if src == -1 then
                self.permitted = {}
                return
            end
            if data.isAdmin then
                self.permitted[src] = true
                TriggerClientEvent('chat:addMessage', src, {
                    args = { '^3[Apex]^0 You have been granted bypass permissions due to your txAdmin role.' }
                })
            else
                self.permitted[src] = nil
            end
        end)
    end
end

function ApexPermissions:HasPermission(source, moduleName)
    local src = tonumber(source)
    if not src then return false end
    if self.permitted[src] then return true end

    local srcStr = tostring(src)
    if IsPlayerAceAllowed(srcStr, Config.Permission.bypassPermission) then return true end

    if moduleName then
        local modPerm = ('apex.%s'):format(moduleName:lower())
        if IsPlayerAceAllowed(srcStr, modPerm) then return true end
    end
    return false
end

function ApexPermissions:AddExcuse(source, timeout, moduleName)
    local src = tonumber(source)
    if not src then return end
    self.excuses[src] = self.excuses[src] or {}
    local mod = moduleName or '*'
    self.excuses[src][mod] = true

    if timeout and timeout > 0 then
        SetTimeout(timeout, function()
            if self.excuses[src] then
                self.excuses[src][mod] = nil
            end
        end)
    end
end

function ApexPermissions:RemoveExcuse(source, moduleName)
    local src = tonumber(source)
    if not src or not self.excuses[src] then return end
    if moduleName then
        self.excuses[src][moduleName] = nil
    else
        self.excuses[src] = nil
    end
end

function ApexPermissions:IsExcused(source, moduleName)
    local src = tonumber(source)
    if not src or not self.excuses[src] then return false end
    if self.excuses[src]['*'] then return true end
    if moduleName and self.excuses[src][moduleName] then return true end
    return false
end

-- Exported Functions
exports('AddExcuseForPlayer', function(source, timeout, moduleName)
    ApexPermissions:AddExcuse(source, timeout, moduleName)
end)

exports('RemoveExcuseFromPlayer', function(source, moduleName)
    ApexPermissions:RemoveExcuse(source, moduleName)
end)

exports('IsPlayerExcused', function(source, moduleName)
    return ApexPermissions:IsExcused(source, moduleName)
end)