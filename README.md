# **Apex Security Suite | FiveM Antiheat & Cloud Panel**

![Lua](https://img.shields.io/badge/Lua-5.4-blue?style=for-the-badge&logo=lua&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-Express-green?style=for-the-badge&logo=node.js)
![FiveM](https://img.shields.io/badge/Platform-Cfx.re_/_FiveM-orange?style=for-the-badge)
![TailwindCSS](https://img.shields.io/badge/Tailwind_CSS-38B2AC?style=for-the-badge&logo=tailwind-css)
![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)

A comprehensive, high-performance security suite for the FiveM platform. Combining a purely Lua-based client/server detection engine with an independent Node.js Express cloud dashboard, this system provides real-time telemetry, automated ban management, and advanced exploit mitigation tailored for serious roleplay communities.

---

## Included Resources
### Apex AntiCheat (FiveM Resource)
A highly optimized, server-authoritative security engine designed to prevent malicious client-side modifications and exploits.
* **100% Pure Lua Engine:** Zero reliance on obfuscated binaries or heavy external dependencies. Performance-optimized loops ensure zero impact on client-side frame times.
* **Advanced Detections:** Real-time monitoring for rapid fire, godmode, vehicle modifiers, entity flooding, underwater walking, and unauthorized weapon spawning.
* **Dynamic KVP Ban System:** Persistent ban management using the native KVP database, automatically capturing hardware tokens, licenses, and Discord identifiers to prevent ban evasion.
* **Core Dependency:** Requires onesync to be active and utilizes screenshot-basic for capturing client evidence.

### Apex Cloud Panel (Node.js Backend)
An external administrative web console for monitoring game server telemetry and auditing player evidence.
* **Live Telemetry Dashboard:** View connected players, real-time server health, active detections, and security alerts through a sleek, responsive Tailwind CSS interface.
* **Evidence Management:** Automatically ingests, indexes, and stores base64 screenshot evidence tied to specific player server IDs and hardware licenses.
* **Remote Administration:** Issue bans, kick players, wipe rogue entities, and revoke bans directly from the web panel via secure API hooks.
* **Core Dependency:** Requires a Node.js environment with `express`, `multer`, and `cors` running on a dedicated port (default 3000).

---

## Technical Architecture

| Feature | Implementation |
| :--- | :--- |
| **API Integration** | Secure REST API linking the FiveM server (`sv_cloud.lua`) to the Node.js backend using `X-Server-Key` header authentication. |
| **State Sync** | Centralized `ApexDetections` controller managing per-player strike cooldowns and dynamic punishment routing (Kick, Warn, Ban). |
| **Security** | Client-side honeypot events (`cl_handlers.lua`) and global variable scanning (`cl_variables.lua`) to trap common executor menus. |
| **Storage** | Flat-file JSON databases (`users.json`, `bans.json`, `screenshots.json`) for the web panel and native KVP for FiveM server persistence. |

---

## Installation

1. **Clone the Repository**
```Bash
git clone https://github.com/ChefAsmith/Fivem-Apex-AntiCheat.git
```

2. **Deploy the Cloud Panel**

Navigate to the `apex-panel` directory, install the required dependencies, and start the application server:
```Bash
npm install
node panel_server.js
```

3. **Deploy the FiveM Resource**

Ensure `onesync` and `screenshot-basic` are running on your server. Add the `apex-anticheat` folder to your `resources/` directory and ensure it in your `server.cfg`:
```cfg
ensure screenshot-basic
ensure apex-anticheat
```

---

## **Configuration**
Both the FiveM resource and the Cloud Panel must share the exact same secure Server Key to authorize REST API payloads.

1. **FiveM Server Config (`config.lua`): **

```Lua
Config.Cloud = {
    enabled = true,
    panelUrl = "http://127.0.0.1:3000",
    serverKey = "key_example", -- MUST MATCH PANEL KEY
    syncInterval = 3000
}
```

2. **Cloud Panel Config (panel_server.js):***

Open `panel_server.js` and ensure the `SERVER_KEY` variable at the top of the file matches the key set in your FiveM config.


```JavaScript
const IP = process.env.IP || '127.0.0.1';
const PORT = process.env.PORT || 3000;
const SERVER_KEY = "key_example"; // Must match Config.Cloud.serverKey in FiveM config.lua
```

**Active Detections & Punishments**
**IMPORTANT:** All detections are set to warn by default. You must customize the punishment type (ban, kick, warn, or alert) in your `config.lua` to fit your server's specific security specifications.

---

**Combat & Weapons**

---

BlacklistedWeapon: Detects usage of weapons defined in the blacklist (e.g., RPG, Minigun).

FoldExploit: Flags abnormal fall damage weapon types and silenced zero-damage exploits (C1/C2).

TazerExploit: Blocks rapid tazer firing and firing beyond maximum configured ranges.

WeaponModifier: Catches client-side weapon damage multipliers, melee multipliers, defense modifiers, and explosive/fire ammo flags.

Aimbot: Analyzes silent aimbot vector angle mismatches (camera view vs. bullet impact).

RapidFire: Identifies triggerbots and rapid-fire exploits based on minimum shot intervals per weapon.

ProjectileSpam: Mitigates rapid spawning of projectiles like grenades.

VehicleWeapons: Detects players firing restricted/mounted weapons from standard civilian vehicles.

---

**Health & Damage**

---

Godmode: Checks for player/vehicle invincibility flags and abnormally high body health limits.

NoRagdoll: Detects when ragdoll physics are unnaturally disabled.

---

**World, Entities & Peds**

---

IllegalEntity: Prevents the spawning of blacklisted models (e.g., tanks, jets).

ClearTasks: Flags unauthorized ClearPedTasks triggered on remote players.

BlacklistedTask: Prevents the execution of prohibited and potentially malicious scripted tasks.

WeaponTransfer: Flags unauthorized giving, removing, or stripping of weapons from remote peds.

EntityFlood: Mitigates script-kiddie entity flooding by tracking spawn counts within specific time windows.

---

**Network Events & Explosions**

---

BlacklistedEvent: Blocks and flags malicious network events commonly used by mod menus.

ExplosionFilter: Blocks non-whitelisted explosion types, invisible explosions, and excessive damage scales.

FireExploit: Prevents spawning fire on players from distances exceeding the maximum configured range.

ParticleFx: Restricts particle scale sizes and prevents attaching particles to remote entities.

---

**Movement**

---

SuperJump: Detects active super jump flags.

NoClip: Analyzes abnormal speeds when a player's position is frozen or collision is disabled.

Teleportation: Flags instantaneous movement beyond allowed distance thresholds.

UnderwaterWalk: Detects players walking normally deep underwater without swimming.

---

**Client-Side Integrity**

---

VehicleModifier: Identifies torque/speed power increases, instant auto-repair, and unrealistic acceleration.

FreecamSpectate: Flags active spectator mode or camera distances exceeding maximum thresholds.

AntiTamper: Detects if the anticheat resource is stopped or restarted on the client.

VisualExploits: Detects unauthorized thermal or night vision toggles.

Invisibility: Flags invisible player peds or vehicles.

ClientEventTrap: Honeypot triggers designed to catch common executor client events.

BlacklistedCheatVar: Scans the global _G table for known cheat menu variables (e.g., WarMenu, LynxEvo).

VehicleSuperSpeed: Flags unrealistic vehicle speeds over 480 km/h.

InfiniteAmmo: Detects frozen ammo clip counts while shooting.

---

## **License**
Distributed under the MIT License. Created as a demonstration of game engine interfacing, network security, and full-stack development.
**Maintainer:** *ChefAmbrosia* – Backend & Infrastructure Developer
