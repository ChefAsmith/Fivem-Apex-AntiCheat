local ClientDetections = {}

RegisterNetEvent('apex:syncDetections', function(states)
    ClientDetections = states or {}
end)

local function IsDetectionEnabled(key)
    if ClientDetections[key] ~= nil then
        return ClientDetections[key]
    end
    return true
end

-- Allowed Drive-by Weapons in GTA V
local ALLOWED_DRIVEBY_WEAPONS = {
    [GetHashKey("WEAPON_PISTOL")] = true, [GetHashKey("WEAPON_PISTOL_MK2")] = true,
    [GetHashKey("WEAPON_COMBATPISTOL")] = true, [GetHashKey("WEAPON_APPISTOL")] = true,
    [GetHashKey("WEAPON_PISTOL50")] = true, [GetHashKey("WEAPON_SNSPISTOL")] = true,
    [GetHashKey("WEAPON_SNSPISTOL_MK2")] = true, [GetHashKey("WEAPON_HEAVYPISTOL")] = true,
    [GetHashKey("WEAPON_VINTAGEPISTOL")] = true, [GetHashKey("WEAPON_CERAMICPISTOL")] = true,
    [GetHashKey("WEAPON_REVOLVER")] = true, [GetHashKey("WEAPON_REVOLVER_MK2")] = true,
    [GetHashKey("WEAPON_DOUBLEACTION")] = true, [GetHashKey("WEAPON_NAVYREVOLVER")] = true,
    [GetHashKey("WEAPON_GADGETPISTOL")] = true, [GetHashKey("WEAPON_MICROSMG")] = true,
    [GetHashKey("WEAPON_MACHINEPISTOL")] = true, [GetHashKey("WEAPON_MINISMG")] = true,
    [GetHashKey("WEAPON_SAWNOFFSHOTGUN")] = true, [GetHashKey("WEAPON_DBSHOTGUN")] = true,
    [GetHashKey("WEAPON_COMPACTRIFLE")] = true, [GetHashKey("WEAPON_TECPISTOL")] = true
}

local SEMI_AUTO_WEAPONS = {
    [GetHashKey('WEAPON_PISTOL')] = 130, [GetHashKey('WEAPON_COMBATPISTOL')] = 120,
    [GetHashKey('WEAPON_PISTOL50')] = 200, [GetHashKey('WEAPON_HEAVYPISTOL')] = 150,
    [GetHashKey('WEAPON_REVOLVER')] = 320, [GetHashKey('WEAPON_SNIPERRIFLE')] = 750,
    [GetHashKey('WEAPON_HEAVYSNIPER')] = 700, [GetHashKey('WEAPON_HEAVYSNIPER_MK2')] = 550,
    [GetHashKey('WEAPON_PUMPSHOTGUN')] = 600, [GetHashKey('WEAPON_SAWNOFFSHOTGUN')] = 380,
    [GetHashKey('WEAPON_MARKSMANPISTOL')] = 600, [GetHashKey('WEAPON_MUSKET')] = 1300
}

-- 1. Rapid Fire & Triggerbot Fast Shot Tracker (Catches shots into sky/walls)
CreateThread(function()
    local lastShotTime = 0
    local lastWeapon = 0
    local lastAmmoInClip = -1
    local frozenAmmoCount = 0

    while true do
        Wait(10)
        local ped = PlayerPedId()

        if IsPedShooting(ped) then
            local now = GetGameTimer()
            local weapon = GetSelectedPedWeapon(ped)
            local minInterval = SEMI_AUTO_WEAPONS[weapon]

            -- Rapid Fire Check
            if minInterval and weapon == lastWeapon and IsDetectionEnabled('RapidFire') then
                local timeSinceLastShot = now - lastShotTime
                if timeSinceLastShot < minInterval then
                    TriggerServerEvent('apex:clientDetection', 'RapidFire', string.format('Rapid Fire / Triggerbot (%dms interval, min %dms)', timeSinceLastShot, minInterval))
                end
            end

            -- Infinite Ammo (Frozen Clip) Check
            if IsDetectionEnabled('InfiniteAmmo') then
                local _, ammoInClip = GetAmmoInClip(ped, weapon)
                if weapon == lastWeapon and ammoInClip >= lastAmmoInClip and ammoInClip > 0 then
                    frozenAmmoCount = frozenAmmoCount + 1
                    if frozenAmmoCount >= 3 then
                        TriggerServerEvent('apex:clientDetection', 'InfiniteAmmo', 'Clip ammo frozen while shooting')
                        frozenAmmoCount = 0
                    end
                else
                    frozenAmmoCount = 0
                end
                lastAmmoInClip = ammoInClip
            end

            lastShotTime = now
            lastWeapon = weapon
        end
    end
end)

-- 2. Client-Side Weapon Damage Multiplier Check
CreateThread(function()
    while true do
        Wait(3000)
        if IsDetectionEnabled('WeaponModifier') then
            local damageModifier = GetPlayerWeaponDamageModifier(PlayerId())
            local meleeModifier = GetPlayerMeleeWeaponDamageModifier(PlayerId())
            local maxMod = Config.Modules.Combat.maxDamageModifier or 1.0

            if damageModifier > (maxMod + 0.05) then
                TriggerServerEvent('apex:clientDetection', 'WeaponModifier', string.format('Client Weapon Damage Multiplier: %.2fx', damageModifier))
            end
            if meleeModifier > (maxMod + 0.05) then
                TriggerServerEvent('apex:clientDetection', 'WeaponModifier', string.format('Client Melee Damage Multiplier: %.2fx', meleeModifier))
            end
        end
    end
end)

-- 3. Vehicle Mounted Guns & Invalid Drive-by Weapons
CreateThread(function()
    while true do
        Wait(500)
        if IsDetectionEnabled('VehicleWeapons') then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh ~= 0 then
                local model = GetEntityModel(veh)
                -- If not a military/weaponized vehicle (tank/hydra/apc)
                if not Config.WeaponizedVehicles[model] then
                    local weapon = GetSelectedPedWeapon(ped)
                    -- If holding a heavy sniper, minigun, RPG, or tazer from inside a normal street car
                    if weapon ~= GetHashKey('WEAPON_UNARMED') and not ALLOWED_DRIVEBY_WEAPONS[weapon] then
                        if IsPedShooting(ped) or IsControlPressed(0, 24) or IsControlPressed(0, 86) then
                            TriggerServerEvent('apex:clientDetection', 'VehicleWeapons', 'Fired restricted/mounted weapon from vehicle seat')
                            Wait(3000)
                        end
                    end
                end
            end
        end
    end
end)

-- 4. Walk Underwater Detection (Water Plane Calculation)
CreateThread(function()
    while true do
        Wait(2500)
        if IsDetectionEnabled('UnderwaterWalk') then
            local ped = PlayerPedId()
            local playerId = PlayerId()

            if not IsPedInAnyVehicle(ped, false) and not IsPlayerDead(playerId) then
                local coords = GetEntityCoords(ped)
                local hasWater, waterHeight = GetWaterHeight(coords.x, coords.y, coords.z)

                -- If ped altitude is 1.2m below water surface and not swimming
                if hasWater and (coords.z < (waterHeight - 1.2)) then
                    if not IsPedSwimming(ped) and not IsPedSwimmingUnderWater(ped) and not IsEntityPlayingAnim(ped, "swimming@base", "swim", 3) then
                        TriggerServerEvent('apex:clientDetection', 'UnderwaterWalk', string.format('Walking underwater (Depth: %.1fm)', waterHeight - coords.z))
                        Wait(3000)
                    end
                end
            end
        end
    end
end)

-- 5. Vehicle Modifier & Acceleration
CreateThread(function()
    local lastSpeed = 0.0
    local lastVeh = 0

    while true do
        Wait(1000)
        if IsDetectionEnabled('VehicleModifier') then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local maxMod = Config.Client.maxVehicleModifier or 1.15

                if GetVehicleTopSpeedModifier(veh) > maxMod or GetVehicleCheatPowerIncrease(veh) > maxMod then
                    TriggerServerEvent('apex:clientDetection', 'VehicleModifier', 'Vehicle torque/speed power increase')
                end

                local curSpeed = GetEntitySpeed(veh)
                local accel = (curSpeed - lastSpeed)
                local model = GetEntityModel(veh)

                if veh == lastVeh and accel > 28.0 and not IsThisModelAPlane(model) and not IsThisModelAHeli(model) then
                    TriggerServerEvent('apex:clientDetection', 'VehicleModifier', string.format('Excessive vehicle acceleration: %.1f m/s²', accel))
                end

                lastSpeed = curSpeed
                lastVeh = veh
            else
                lastSpeed = 0.0
                lastVeh = 0
            end
        end
    end
end)

-- 6. Vehicle Auto-Repair Check
CreateThread(function()
    local lastHealth = 1000.0
    local lastVeh = 0

    while true do
        Wait(1000)
        if IsDetectionEnabled('VehicleModifier') then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local bodyHealth = GetVehicleBodyHealth(veh)
                if veh == lastVeh and lastHealth < 850.0 and bodyHealth >= 995.0 then
                    TriggerServerEvent('apex:clientDetection', 'VehicleModifier', 'Instant vehicle auto-repair detected')
                end
                lastHealth = bodyHealth
                lastVeh = veh
            else
                lastHealth = 1000.0
                lastVeh = 0
            end
        end
    end
end)

-- 7. Freecam / Spectator Check
CreateThread(function()
    local maxDist = Config.Client.maxCamDistance or 150.0
    local strikes = 0
    while true do
        Wait(2500)
        if IsDetectionEnabled('FreecamSpectate') then
            local ped = PlayerPedId()

            if NetworkIsInSpectatorMode() then strikes = strikes + 1 end
            local camDist = #(GetEntityCoords(ped) - GetFinalRenderedCamCoord())
            if camDist >= maxDist then strikes = strikes + 1 end

            if strikes >= 4 then
                TriggerServerEvent('apex:clientDetection', 'FreecamSpectate', string.format('Camera Offset: %.1fm', camDist))
                strikes = 0
            end
        end
    end
end)

-- 8. Heartbeat & Anti-Resource Stop
CreateThread(function()
    while true do
        Wait(30000)
        TriggerServerEvent('apex:heartbeat')
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        TriggerServerEvent('apex:clientDetection', 'AntiTamper', 'Anticheat resource stopped on client')
    end
end)

-- 9. Thermal / Night Vision Check
CreateThread(function()
    local THERMAL_SNIPER <const> = GetHashKey('WEAPON_HEAVYSNIPER_MK2')
    local THERMAL_SCOPE <const> = GetHashKey('COMPONENT_AT_SCOPE_THERMAL')

    while true do
        Wait(4000)
        if IsDetectionEnabled('VisualExploits') then
            local ped = PlayerPedId()
            if not IsPedInAnyHeli(ped) and not IsPedInAnyPlane(ped) then
                if GetUsingnightvision() or GetUsingseethrough() then
                    local currentWeapon = GetSelectedPedWeapon(ped)
                    local hasThermalScope = (currentWeapon == THERMAL_SNIPER and HasPedGotWeaponComponent(ped, currentWeapon, THERMAL_SCOPE))
                    
                    if not (IsPlayerFreeAiming(PlayerId()) and hasThermalScope) then
                        TriggerServerEvent('apex:clientDetection', 'VisualExploits', 'Unauthorized Thermal/Nightvision toggled')
                    end
                end
            end
        end
    end
end)

-- 10. Invisibility Check (Ped & Vehicle Aware)
CreateThread(function()
    local invisibleStrikes = 0
    while true do
        Wait(3000)
        if IsDetectionEnabled('Invisibility') then
            local ped = PlayerPedId()
            local playerId = PlayerId()

            if not NetworkIsInSpectatorMode() 
                and not IsPlayerDead(playerId) 
                and not IsScreenFadedOut() 
                and not IsScreenFadingOut() 
                and GetEntityHealth(ped) > 0 then
                
                local veh = GetVehiclePedIsIn(ped, false)
                if veh == 0 then
                    if not IsEntityVisible(ped) or GetEntityAlpha(ped) < 50 then
                        invisibleStrikes = invisibleStrikes + 1
                        if invisibleStrikes >= 3 then
                            TriggerServerEvent('apex:clientDetection', 'Invisibility', 'Local ped set to invisible on foot')
                            invisibleStrikes = 0
                        end
                    else
                        invisibleStrikes = 0
                    end
                else
                    if GetPedInVehicleSeat(veh, -1) == ped and (not IsEntityVisible(veh) or GetEntityAlpha(veh) < 50) then
                        TriggerServerEvent('apex:clientDetection', 'Invisibility', 'Vehicle set to invisible')
                    end
                end
            else
                invisibleStrikes = 0
            end
        end
    end
end)

-- 11. Invincibility Check (Ped & Vehicle)
CreateThread(function()
    local godmodeStrikes = 0
    while true do
        Wait(3000)
        if IsDetectionEnabled('Godmode') then
            local ped = PlayerPedId()
            local playerId = PlayerId()

            if not NetworkIsInSpectatorMode() and not IsPlayerDead(playerId) and GetEntityHealth(ped) > 0 then
                local isInvincible = GetPlayerInvincible(playerId) 
                    or GetPlayerInvincible_2(ped) 
                    or not GetEntityCanBeDamaged(ped)

                if isInvincible then
                    godmodeStrikes = godmodeStrikes + 1
                    if godmodeStrikes >= 2 then
                        TriggerServerEvent('apex:clientDetection', 'Godmode', 'Ped Invincibility flag active')
                        godmodeStrikes = 0
                    end
                else
                    godmodeStrikes = 0
                end

                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                    if not GetEntityCanBeDamaged(veh) or GetVehicleBodyHealth(veh) > 1000.0 then
                        TriggerServerEvent('apex:clientDetection', 'Godmode', 'Vehicle Invincibility flag active')
                    end
                end
            else
                godmodeStrikes = 0
            end
        end
    end
end)

-- 12. No-Ragdoll Detection
CreateThread(function()
    local ragdollStrikes = 0
    while true do
        Wait(3000)
        if IsDetectionEnabled('NoRagdoll') then
            local ped = PlayerPedId()
            local playerId = PlayerId()

            if not IsPedInAnyVehicle(ped, false) and not IsPlayerDead(playerId) and GetEntityHealth(ped) > 0 then
                local flag190 = GetPedConfigFlag(ped, 190, true)
                local cannotRagdoll = not CanPedRagdoll(ped)

                if flag190 or cannotRagdoll then
                    ragdollStrikes = ragdollStrikes + 1
                    if ragdollStrikes >= 2 then
                        TriggerServerEvent('apex:clientDetection', 'NoRagdoll', 'Ragdoll physics disabled')
                        ragdollStrikes = 0
                    end
                else
                    ragdollStrikes = 0
                end
            else
                ragdollStrikes = 0
            end
        end
    end
end)

-- 13. Explosive Bullets Ped Config Flag
CreateThread(function()
    while true do
        Wait(3000)
        if IsDetectionEnabled('WeaponModifier') then
            local ped = PlayerPedId()
            if GetPedConfigFlag(ped, 223, true) then
                TriggerServerEvent('apex:clientDetection', 'WeaponModifier', 'CPED_CONFIG_FLAG_ExplosiveAmmo active')
            end
            if GetPedConfigFlag(ped, 224, true) then
                TriggerServerEvent('apex:clientDetection', 'WeaponModifier', 'CPED_CONFIG_FLAG_FireAmmo active')
            end
        end
    end
end)

-- 14. Vehicle Super-Speed
CreateThread(function()
    while true do
        Wait(1000)
        if IsDetectionEnabled('VehicleSuperSpeed') then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local speedKmh = GetEntitySpeed(veh) * 3.6
                local model = GetEntityModel(veh)
                if speedKmh > 480.0 and not IsThisModelAPlane(model) and not IsThisModelAHeli(model) then
                    TriggerServerEvent('apex:clientDetection', 'VehicleSuperSpeed', string.format('Unrealistic vehicle speed: %.1f km/h', speedKmh))
                end
            end
        end
    end
end)

RegisterNetEvent('apex:showWarningNotification', function(msg)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName("~r~[Apex Warning]~s~ " .. msg)
    EndTextCommandThefeedPostTicker(true, false)
end)