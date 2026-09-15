local illegalModels = {}
for _, model in ipairs(Config.IllegalModels) do
    illegalModels[GetHashKey(model)] = true
end

local blacklistedTasks = {}
for _, task in ipairs(Config.Modules.Entities.blacklistedTasks) do
    blacklistedTasks[task] = true
end

AddEventHandler('entityCreating', function(entity)
    local model = GetEntityModel(entity)
    if illegalModels[model] then
        CancelEvent()
        local owner = NetworkGetFirstEntityOwner(entity)
        if owner and owner > 0 then
            ApexDetections:Trigger(owner, 'IllegalEntity', 'Spawned Blacklisted Model: ' .. tostring(model))
        end
    end
end)

AddEventHandler('clearPedTasksEvent', function(sender, data)
    local targetPed = NetworkGetEntityFromNetworkId(data.pedId)
    if DoesEntityExist(targetPed) and IsPedAPlayer(targetPed) then
        local targetOwner = NetworkGetEntityOwner(targetPed)
        if sender ~= targetOwner then
            CancelEvent()
            ApexDetections:Trigger(sender, 'ClearTasks', 'ClearPedTasks Troll on Remote Player')
        end
    end
end)

AddEventHandler('givePedScriptedTaskEvent', function(sender, data)
    if blacklistedTasks[data.taskId] then
        CancelEvent()
        ApexDetections:Trigger(sender, 'BlacklistedTask', 'Blacklisted Scripted Task ID: ' .. tostring(data.taskId))
    end
end)

AddEventHandler('giveWeaponEvent', function(sender, data)
    local targetPed = NetworkGetEntityFromNetworkId(data.pedId)
    if DoesEntityExist(targetPed) and sender ~= NetworkGetEntityOwner(targetPed) then
        CancelEvent()
        ApexDetections:Trigger(sender, 'WeaponTransfer', 'Unauthorized GiveWeapon on Remote Ped')
    end
end)

AddEventHandler('removeWeaponEvent', function(sender, data)
    local targetPed = NetworkGetEntityFromNetworkId(data.pedId)
    if DoesEntityExist(targetPed) and sender ~= NetworkGetEntityOwner(targetPed) then
        CancelEvent()
        ApexDetections:Trigger(sender, 'WeaponTransfer', 'Unauthorized RemoveWeapon on Remote Ped')
    end
end)

AddEventHandler('removeAllWeaponsEvent', function(sender, data)
    local targetPed = NetworkGetEntityFromNetworkId(data.pedId)
    if DoesEntityExist(targetPed) and sender ~= NetworkGetEntityOwner(targetPed) then
        CancelEvent()
        ApexDetections:Trigger(sender, 'WeaponTransfer', 'Unauthorized RemoveAllWeapons on Remote Ped')
    end
end)

AddEventHandler('requestControlEvent', function(sender, data)
    local entity = NetworkGetEntityFromNetworkId(data.netId)
    if not DoesEntityExist(entity) then return end

    local currentOwner = NetworkGetEntityOwner(entity)
    if currentOwner and currentOwner > 0 and currentOwner ~= sender then
        local ped = GetPlayerPed(tostring(currentOwner))
        if DoesEntityExist(ped) and GetVehiclePedIsIn(ped, false) == entity then
            CancelEvent()
        end
    end
end)