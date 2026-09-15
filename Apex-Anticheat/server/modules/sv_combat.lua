local blacklistedWeaponHashes = {}
for _, name in ipairs(Config.BlacklistedWeapons) do
    blacklistedWeaponHashes[GetHashKey(name)] = true
end

local tazerCooldowns = {}
local projectileCooldowns = {}
local weaponShotTimestamps = {}

local WEAPON_FALL_01 <const> = 2725352035
local WEAPON_FALL_02 <const> = 3452007600
local WEAPON_BIRD_CRAP <const> = 1834887169
local WEAPON_STUNGUN <const> = 0x3656c8c1
local WEAPON_STUNGUN_MP <const> = 0x45cd9cf3

local EXCLUDED_AIMBOT_WEAPONS = {
    [GetHashKey('WEAPON_UNARMED')] = true, [GetHashKey('WEAPON_KNIFE')] = true,
    [GetHashKey('WEAPON_NIGHTSTICK')] = true, [GetHashKey('WEAPON_HAMMER')] = true,
    [GetHashKey('WEAPON_BAT')] = true, [GetHashKey('WEAPON_GOLFCLUB')] = true,
    [GetHashKey('WEAPON_CROWBAR')] = true, [GetHashKey('WEAPON_PISTOL_WHIP')] = true,
    [GetHashKey('WEAPON_BOTTLE')] = true, [GetHashKey('WEAPON_DAGGER')] = true,
    [GetHashKey('WEAPON_HATCHET')] = true, [GetHashKey('WEAPON_KNUCKLE')] = true,
    [GetHashKey('WEAPON_MACHETE')] = true, [GetHashKey('WEAPON_FLASHLIGHT')] = true,
    [GetHashKey('WEAPON_SWITCHBLADE')] = true, [GetHashKey('WEAPON_POOLCUE')] = true,
    [GetHashKey('WEAPON_WRENCH')] = true, [GetHashKey('WEAPON_BATTLEAXE')] = true,
    [GetHashKey('WEAPON_STONE_HATCHET')] = true, [GetHashKey('WEAPON_GRENADE')] = true,
    [GetHashKey('WEAPON_BZGAS')] = true, [GetHashKey('WEAPON_MOLOTOV')] = true,
    [GetHashKey('WEAPON_STICKYBOMB')] = true, [GetHashKey('WEAPON_PROXMINE')] = true,
    [GetHashKey('WEAPON_SNOWBALL')] = true, [GetHashKey('WEAPON_PIPEBOMB')] = true,
    [GetHashKey('WEAPON_BALL')] = true, [GetHashKey('WEAPON_SMOKEGRENADE')] = true,
    [GetHashKey('WEAPON_FLARE')] = true, [GetHashKey('WEAPON_RPG')] = true,
    [GetHashKey('WEAPON_HOMINGLAUNCHER')] = true, [GetHashKey('WEAPON_GRENADELAUNCHER')] = true
}

-- Legitimate GTA V Drive-by Weapons
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

local MIN_SHOT_INTERVALS = {
    [GetHashKey('WEAPON_RPG')] = 1400,
    [GetHashKey('WEAPON_HOMINGLAUNCHER')] = 1400,
    [GetHashKey('WEAPON_GRENADELAUNCHER')] = 800,
    [GetHashKey('WEAPON_HEAVYSNIPER')] = 750,
    [GetHashKey('WEAPON_HEAVYSNIPER_MK2')] = 600,
    [GetHashKey('WEAPON_PUMPSHOTGUN')] = 650,
    [GetHashKey('WEAPON_SAWNOFFSHOTGUN')] = 400,
    -- Semi-automatic pistols & rifles to catch triggerbot / rapid fire
    [GetHashKey('WEAPON_PISTOL')] = 140,
    [GetHashKey('WEAPON_COMBATPISTOL')] = 130,
    [GetHashKey('WEAPON_PISTOL50')] = 220,
    [GetHashKey('WEAPON_HEAVYPISTOL')] = 160,
    [GetHashKey('WEAPON_REVOLVER')] = 350,
    [GetHashKey('WEAPON_MARKSMANPISTOL')] = 650,
    [GetHashKey('WEAPON_SNIPERRIFLE')] = 800,
    [GetHashKey('WEAPON_MUSKET')] = 1400,
    [GetHashKey('WEAPON_DOUBLEACTION')] = 250
}

local AIMBOT_OFFSET_DIST <const> = 7.0

local function GetForwardVector2D(yaw)
    local yawRad = math.rad(yaw)
    return vector2(-math.sin(yawRad), math.cos(yawRad))
end

AddEventHandler('weaponDamageEvent', function(sender, data)
    local srcStr = tostring(sender)

    -- 1. Blacklisted Weapon Detection
    if blacklistedWeaponHashes[data.weaponType] then
        CancelEvent()
        ApexDetections:Trigger(sender, 'BlacklistedWeapon', 'Blacklisted Weapon Hash: ' .. tostring(data.weaponType))
        return
    end

    -- 2. Fold Cheat Detection
    if data.silenced and data.weaponDamage == 0 and (data.weaponType == WEAPON_FALL_01 or data.weaponType == WEAPON_FALL_02) then
        CancelEvent()
        ApexDetections:Trigger(sender, 'FoldExploit', 'Fold Exploit [C1]')
        return
    end

    if not data.silenced and data.weaponDamage == 131071 and data.weaponType == WEAPON_BIRD_CRAP then
        CancelEvent()
        ApexDetections:Trigger(sender, 'FoldExploit', 'Fold Exploit [C2]')
        return
    end

    -- 3. Vehicle Invalid Weapons (Catches Menyoo Vehicle Mounted Guns, Heavy Snipers, Tazers on standard cars)
    local killer = GetPlayerPed(srcStr)
    local killerVeh = GetVehiclePedIsIn(killer, false)
    if killerVeh ~= 0 then
        local vehModel = GetEntityModel(killerVeh)
        if not Config.WeaponizedVehicles[vehModel] and not ALLOWED_DRIVEBY_WEAPONS[data.weaponType] then
            CancelEvent()
            ApexDetections:Trigger(sender, 'VehicleWeapons', string.format('Fired restricted weapon %s from standard vehicle', tostring(data.weaponType)))
            return
        end
    end

    -- 4. Tazer Range & Cooldown
    if data.weaponType == WEAPON_STUNGUN or data.weaponType == WEAPON_STUNGUN_MP then
        local hitEntity = NetworkGetEntityFromNetworkId(data.hitGlobalId or data.hitGlobalIds[1] or 0)
        if DoesEntityExist(hitEntity) and IsPedAPlayer(hitEntity) then
            local senderCoords = GetEntityCoords(killer)
            local victimCoords = GetEntityCoords(hitEntity)
            local dist = #(senderCoords - victimCoords)

            if dist > Config.Modules.Combat.maxTazerDistance then
                CancelEvent()
                ApexDetections:Trigger(sender, 'TazerExploit', string.format('Tazer Range (%.2fm)', dist))
                return
            end

            local now = GetGameTimer()
            if tazerCooldowns[sender] and (now - tazerCooldowns[sender]) < Config.Modules.Combat.tazerCooldown then
                CancelEvent()
                ApexDetections:Trigger(sender, 'TazerExploit', 'Tazer Rapid Cooldown Bypass')
                return
            end
            tazerCooldowns[sender] = now
        end
    end

    -- 5. Weapon Damage & Defense Modifiers
    if GetPlayerWeaponDamageModifier(srcStr) > (Config.Modules.Combat.maxDamageModifier + 0.05) or
       GetPlayerMeleeWeaponDamageModifier(srcStr) > (Config.Modules.Combat.maxDamageModifier + 0.05) or
       GetPlayerWeaponDefenseModifier(srcStr) > (Config.Modules.Combat.maxDamageModifier + 0.05) then
        CancelEvent()
        ApexDetections:Trigger(sender, 'WeaponModifier', 'Weapon Damage/Defense Multiplier Exploit')
        return
    end

    -- 6. Abnormal Single-Hit Bullet Damage (Menyoo Weapon Damage Multiplier)
    local isAoeOrHeavy = EXCLUDED_AIMBOT_WEAPONS[data.weaponType] or data.weaponType == GetHashKey('WEAPON_PUMPSHOTGUN')
    if data.weaponDamage > 65 and not isAoeOrHeavy then
        CancelEvent()
        ApexDetections:Trigger(sender, 'WeaponModifier', string.format('Abnormal bullet damage multiplier: %d DMG', data.weaponDamage))
        return
    end

    -- 7. Silent Aimbot Vector Verification
    if not EXCLUDED_AIMBOT_WEAPONS[data.weaponType] then
        local victim = NetworkGetEntityFromNetworkId(data.hitGlobalId or data.hitGlobalIds[1] or 0)
        if DoesEntityExist(victim) and IsPedAPlayer(victim) and GetEntityHealth(victim) > 0 and not IsPedRagdoll(victim) then
            if killerVeh == 0 and GetEntityHealth(killer) > 0 and not IsEntityPositionFrozen(killer) then
                local killerCamCoords = GetPlayerFocusPos(srcStr)
                local victimCoords = GetEntityCoords(victim)
                local killerCoords = GetEntityCoords(killer)

                if #(killerCoords - victimCoords) >= 4.0 then
                    local camRot = GetPlayerCameraRotation(srcStr)
                    local fwd = GetForwardVector2D(camRot.z)
                    local distToVictim = #(vector2(killerCamCoords.x, killerCamCoords.y) - vector2(victimCoords.x, victimCoords.y))

                    local projectedPoint = vector2(killerCamCoords.x + fwd.x * distToVictim, killerCamCoords.y + fwd.y * distToVictim)
                    local actualPoint = vector2(victimCoords.x, victimCoords.y)

                    if #(projectedPoint - actualPoint) > AIMBOT_OFFSET_DIST then
                        CancelEvent()
                        ApexDetections:Trigger(sender, 'Aimbot', 'Silent Aimbot Vector Angle Mismatch')
                        return
                    end
                end
            end
        end
    end

    -- 8. Rapid Fire / Triggerbot Check
    local minInterval = MIN_SHOT_INTERVALS[data.weaponType]
    if minInterval then
        local now = GetGameTimer()
        weaponShotTimestamps[sender] = weaponShotTimestamps[sender] or {}
        local lastShot = weaponShotTimestamps[sender][data.weaponType]

        if lastShot and (now - lastShot) < minInterval then
            CancelEvent()
            ApexDetections:Trigger(sender, 'RapidFire', string.format('Rapid Fire on Weapon %s (%dms)', tostring(data.weaponType), now - lastShot))
            return
        end
        weaponShotTimestamps[sender][data.weaponType] = now
    end
end)

-- 9. Projectile Spam
AddEventHandler('startProjectileEvent', function(sender, data)
    local now = GetGameTimer()
    if projectileCooldowns[sender] and (now - projectileCooldowns[sender]) < Config.Modules.Combat.projectileCooldown then
        CancelEvent()
        ApexDetections:Trigger(sender, 'ProjectileSpam', 'Projectile Rapid Spam')
        return
    end
    projectileCooldowns[sender] = now
end)