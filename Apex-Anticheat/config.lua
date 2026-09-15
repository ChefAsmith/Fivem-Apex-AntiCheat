Config = {}

-- When true, config.lua always overrides previous KVP database settings on server start
Config.ForceConfigDefaults = true

-- Discord Webhook for alert logs and screenshots
Config.DiscordWebhook = "https://discord.com/api/webhooks/"

-- Permissions & Bypass
Config.Permission = {
    bypassPermission = "apex.bypass", -- ACE bypass permission
    useTxAdmin = false                -- Automatic bypass for txAdmin admins
}

Config.Warning = {
    useTxAdmin = false,     -- Triggers txAdmin's interactive full-screen warning modal
    sendPrivateChat = false,-- Sends a private chat message strictly to the offender as backup
    showHudTicker = true   -- Shows a native GTA V red alert banner above the offender's minimap
}

-- -------------------------------------------------------------
-- Cloud Web Panel Configuration
-- -------------------------------------------------------------
Config.Cloud = {
    enabled = true,
    panelUrl = "http://127.0.0.1:3000",
    serverKey = "key_example",
    syncInterval = 3000
}

-- Client Loop Defaults
Config.Client = {
    antiSpectate = true,
    maxCamDistance = 150.0,
    antiVehicleModifiers = true,
    maxVehicleModifier = 1.15,
    scanBlacklistedVariables = true
}

-- -------------------------------------------------------------
-- Detection Cooldown Settings
-- -------------------------------------------------------------
-- Duration in seconds to throttle duplicate alerts for the same player.
-- NOTE: All detections with punishment = "ban" immediately bypass this cooldown!
Config.DetectionCooldown = 15

-- -------------------------------------------------------------
-- Granular Detections & Punishments
-- Modes: "ban" | "kick" | "warn" | "alert"
-- -------------------------------------------------------------
Config.Detections = {
    -- Combat & Weapons
    ["BlacklistedWeapon"] = { enabled = true, punishment = "warn" },
    ["FoldExploit"]       = { enabled = true, punishment = "warn" },
    ["TazerExploit"]      = { enabled = true, punishment = "warn" },
    ["WeaponModifier"]    = { enabled = true, punishment = "warn" },
    ["Aimbot"]            = { enabled = true, punishment = "warn" },
    ["RapidFire"]         = { enabled = true, punishment = "warn" },
    ["ProjectileSpam"]    = { enabled = true, punishment = "warn" },
    ["VehicleWeapons"]    = { enabled = true, punishment = "warn" },
    
    -- Health & Damage
    ["Godmode"]           = { enabled = true, punishment = "warn" },
    ["NoRagdoll"]         = { enabled = true, punishment = "warn" },
    
    -- World, Entities & Peds
    ["IllegalEntity"]     = { enabled = true, punishment = "warn" },
    ["ClearTasks"]        = { enabled = true, punishment = "warn" },
    ["BlacklistedTask"]   = { enabled = true, punishment = "warn" },
    ["WeaponTransfer"]    = { enabled = true, punishment = "warn" },
    ["EntityFlood"]       = { enabled = true, punishment = "warn" },
    
    -- Network Events & Explosions
    ["BlacklistedEvent"]  = { enabled = true, punishment = "warn" },
    ["ExplosionFilter"]   = { enabled = true, punishment = "warn" },
    ["FireExploit"]       = { enabled = true, punishment = "warn" },
    ["ParticleFx"]        = { enabled = true, punishment = "warn" },
    
    -- Movement
    ["SuperJump"]         = { enabled = true, punishment = "warn" },
    ["NoClip"]            = { enabled = true, punishment = "warn" },
    ["Teleportation"]     = { enabled = true, punishment = "warn" },
    ["UnderwaterWalk"]    = { enabled = true, punishment = "warn" },
    
    -- Client-Side Integrity
    ["VehicleModifier"]   = { enabled = true, punishment = "warn" },
    ["FreecamSpectate"]   = { enabled = true, punishment = "warn" },
    ["AntiTamper"]        = { enabled = true, punishment = "warn" },
    ["VisualExploits"]    = { enabled = true, punishment = "warn" },
    ["Invisibility"]      = { enabled = true, punishment = "warn" },
    ["ClientEventTrap"]   = { enabled = true, punishment = "warn" },
    ["BlacklistedCheatVar"]= { enabled = true, punishment = "warn" },
    ["VehicleSuperSpeed"] = { enabled = true, punishment = "warn" },
    ["InfiniteAmmo"]      = { enabled = true, punishment = "warn" }
}

-- Module Options
Config.Modules = {
    Deferrals = {
        enabled = true,
        NameFilter = { enabled = true, rejectionMsg = "Your username contains forbidden characters." }
    },
    EntityLimiter = {
        enabled = true,
        maxSpawns = 100,
        windowDuration = 5000
    },
    EntityCreate = {
        cleanUpEntities = true
    },
    ExplosionFilter = {
        enabled = true,
        explosionSpoofer = true,
        hydrantExplosion = true,
        whitelistedExplosionTypes = {
            6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
            22, 23, 24, 27, 28, 30, 31, 34, 38, 39, 78, 79
        }
    },
    Combat = {
        enabled = true,
        maxTazerDistance = 12.0,
        tazerCooldown = 12000,
        projectileCooldown = 50,
        maxDamageModifier = 1.0
    },
    Entities = {
        blacklistedTasks = { 12, 100, 101, 151, 205, 221, 222, 224, 307, 343, 356 }
    },
    Movement = {
        speedThreshold = 25.0
    },
    Fire = {
        maxFireDistance = 128.0
    },
    Particles = {
        maxParticleScale = 5.0
    }
}

Config.BlacklistedWeapons = {
    "WEAPON_RPG", "WEAPON_MINIGUN", "WEAPON_RAILGUN", "WEAPON_HOMINGLAUNCHER",
    "WEAPON_COMPACTLAUNCHER", "WEAPON_RAYMINIGUN", "WEAPON_EMPLAUNCHER",
    "WEAPON_GRENADELAUNCHER", "WEAPON_RAILGUNXM3", "WEAPON_STICKYBOMB"
}

Config.IllegalModels = {
    "apc", "rhino", "hydra", "lazer", "khanjali", "oppressor", "oppressor2",
    "chernobog", "avenger", "hunter", "insurgent", "technical", "minitank",
    "cerberus", "scarab", "thruster", "stromberg", "deluxo", "ruiner2",
    "deathbike", "brutus", "bruiser", "slamvan4", "slamvan5", "slamvan6",
    "prop_beach_fire", "p_spinning_anus_s", "stt_prop_stunt_tube_l"
}

-- Allowed Military / Weaponized Vehicles that legitimately have mounted guns
Config.WeaponizedVehicles = {
    [GetHashKey("rhino")] = true,
    [GetHashKey("khanjali")] = true,
    [GetHashKey("apc")] = true,
    [GetHashKey("buzzard")] = true,
    [GetHashKey("hunter")] = true,
    [GetHashKey("savage")] = true,
    [GetHashKey("hydra")] = true,
    [GetHashKey("lazer")] = true,
    [GetHashKey("ruiner2")] = true,
    [GetHashKey("scramjet")] = true,
    [GetHashKey("vigilante")] = true,
    [GetHashKey("deluxo")] = true,
    [GetHashKey("oppressor")] = true,
    [GetHashKey("oppressor2")] = true
}

Config.BlacklistedEvents = {
    "adminmenu:allowall", "AdminMenu:giveBank", "AdminMenu:giveCash",
    "antilynx8:anticheat", "antilynxr4:detect", "lynx8:anticheat",
    "bank:deposit", "bank:withdraw", "BsCuff:Cuff696999",
    "DFWM:adminmenuenable", "DFWM:ViolationDetected", "dmv:success",
    "esx_ambulancejob:revive", "esx_drugs:startHarvestWeed",
    "esx_jail:sendToJail", "LegacyFuel:PayFuel", "mellotrainer:adminTempBan",
    "HCheat:TempDisableDetection", "esx:giveInventoryItem", "esx_billing:sendBill",
    "cuffServer", "uncuffGranted", "OG_cuffs:cuffCheckNearest"
}