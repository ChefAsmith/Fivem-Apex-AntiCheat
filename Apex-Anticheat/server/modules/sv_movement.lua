local lastPositions = {}
local wasDead = {}

CreateThread(function()
    while true do
        Wait(1000)
        local players = GetPlayers()

        for _, player in ipairs(players) do
            local ped = GetPlayerPed(player)
            local srcNum = tonumber(player)

            if DoesEntityExist(ped) and not ApexPermissions:HasPermission(srcNum) and not ApexPermissions:IsExcused(srcNum) then
                -- 1. Ignore if in connect / spawn grace period
                if IsPlayerInSpawnGrace(srcNum) then
                    lastPositions[srcNum] = nil
                    wasDead[srcNum] = nil
                else
                    local health = GetEntityHealth(ped)

                    -- 2. Track death state to prevent hospital respawn false positives
                    if health <= 100 then
                        wasDead[srcNum] = true
                        lastPositions[srcNum] = nil
                    else
                        local currentPos = GetEntityCoords(ped)
                        local veh = GetVehiclePedIsIn(ped, false)
                        local srcStr = tostring(srcNum)

                        -- A. SuperJump Detection
                        if IsPlayerUsingSuperJump(player) then
                            ApexDetections:Trigger(srcNum, 'SuperJump', 'SuperJump Active')
                        end

                        -- B. NoClip Movement Detection (Calculated from previous 1s tick without freezing thread)
                        if lastPositions[srcNum] and not wasDead[srcNum] and veh == 0 then
                            local isNoClipState = (IsEntityPositionFrozen(ped) or GetPlayerInvincible(srcStr))
                                and (not IsEntityVisible(ped) or GetEntityCollisionDisabled(ped))

                            if isNoClipState then
                                local deltaDist = #(currentPos - lastPositions[srcNum])
                                local speedKmh = deltaDist * 3.6
                                local threshold = (Config.Modules.Movement and Config.Modules.Movement.speedThreshold) or 25.0

                                if speedKmh > threshold then
                                    ApexDetections:Trigger(srcNum, 'NoClip', string.format('NoClip Movement (%.1f km/h)', speedKmh))
                                end
                            end
                        end

                        -- C. Teleportation Detection (with Vehicle speed awareness)
                        if lastPositions[srcNum] and not wasDead[srcNum] then
                            local dist = #(currentPos - lastPositions[srcNum])
                            local maxAllowedDist = (veh ~= 0) and 220.0 or 45.0

                            if dist > maxAllowedDist then
                                ApexDetections:Trigger(srcNum, 'Teleportation', string.format('Teleported %.1fm in 1s', dist))
                            end
                        end

                        wasDead[srcNum] = false
                        lastPositions[srcNum] = currentPos
                    end
                end
            else
                lastPositions[srcNum] = nil
                wasDead[srcNum] = nil
            end
        end
    end
end)