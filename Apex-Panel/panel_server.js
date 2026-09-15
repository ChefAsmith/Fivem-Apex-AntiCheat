const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const cors = require('cors');

const app = express();
const IP = process.env.IP || '127.0.0.1';
const PORT = process.env.PORT || 3000;
const SERVER_KEY = "key_example"; // Must match Config.Cloud.serverKey in FiveM config.lua

const DATA_DIR = path.join(__dirname, 'data');
const UPLOAD_DIR = path.join(__dirname, 'public', 'screenshots');

if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const USERS_FILE = path.join(DATA_DIR, 'users.json');
const BANS_FILE = path.join(DATA_DIR, 'bans.json');
const SCREENSHOTS_FILE = path.join(DATA_DIR, 'screenshots.json');

function readJson(file) {
    try {
        return JSON.parse(fs.readFileSync(file, 'utf8'));
    } catch {
        return [];
    }
}

function writeJson(file, data) {
    fs.writeFileSync(file, JSON.stringify(data, null, 2));
}

if (!fs.existsSync(USERS_FILE)) {
    const defaultUsers = [
        {
            id: 'admin_1',
            username: 'admin',
            password: 'adminpassword',
            role: 'Administrator',
            mustChangePassword: true,
            createdAt: new Date().toISOString()
        }
    ];
    writeJson(USERS_FILE, defaultUsers);
}

if (!fs.existsSync(BANS_FILE)) writeJson(BANS_FILE, []);
if (!fs.existsSync(SCREENSHOTS_FILE)) writeJson(SCREENSHOTS_FILE, []);

let serverState = {
    serverName: "Offline",
    playerCount: 0,
    uptime: 0,
    lastSeen: 0,
    onlinePlayers: [],
    detections: {},
    totalBans: 0
};

let commandQueue = [];
let violationsByPlayer = {};
let recentScreenshotTargets = {};

const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, UPLOAD_DIR),
    filename: (req, file, cb) => {
        const target = req.query.target || 'unknown';
        cb(null, `shot_${target}_${Date.now()}.png`);
    }
});
const upload = multer({ storage, limits: { fileSize: 50 * 1024 * 1024 } });

app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

app.use(express.static(path.join(__dirname, 'public')));
app.use('/public', express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', time: Date.now() });
});

function authenticateServer(req, res, next) {
    const key = req.headers['x-server-key'] || req.query.key;
    if (key !== SERVER_KEY) {
        return res.status(401).json({ error: "Unauthorized: Invalid Server Key" });
    }
    next();
}

function getPlayerMeta(targetId) {
    const targetStr = String(targetId);
    const p = serverState.onlinePlayers.find(pl => String(pl.source) === targetStr);
    if (p) {
        return {
            playerName: p.name,
            license: (p.identifiers && p.identifiers.license) ? p.identifiers.license : 'N/A'
        };
    }
    const v = violationsByPlayer[targetStr];
    if (v && v.playerName) {
        return {
            playerName: v.playerName,
            license: 'N/A'
        };
    }
    const cached = recentScreenshotTargets[targetStr];
    if (cached && cached.playerName) {
        return {
            playerName: cached.playerName,
            license: cached.license || 'N/A'
        };
    }
    return {
        playerName: `Player ${targetStr}`,
        license: 'N/A'
    };
}

// =============================================================
// AUTHENTICATION & STAFF APIS
// =============================================================
app.post('/api/auth/login', (req, res) => {
    const { username, password } = req.body || {};
    const users = readJson(USERS_FILE);
    const user = users.find(u => u.username.toLowerCase() === (username || '').trim().toLowerCase() && u.password === (password || '').trim());

    if (user) {
        res.json({
            success: true,
            user: {
                id: user.id,
                username: user.username,
                role: user.role,
                mustChangePassword: user.mustChangePassword || false
            }
        });
    } else {
        res.status(401).json({ success: false, error: 'Invalid username or password' });
    }
});

app.post('/api/auth/change-password', (req, res) => {
    const { username, currentPassword, newPassword } = req.body || {};
    let users = readJson(USERS_FILE);
    const userIndex = users.findIndex(u => u.username.toLowerCase() === (username || '').trim().toLowerCase() && u.password === currentPassword);

    if (userIndex === -1) {
        return res.status(400).json({ success: false, error: 'Current credentials invalid' });
    }

    if (!newPassword || newPassword.length < 6) {
        return res.status(400).json({ success: false, error: 'New password must be at least 6 characters' });
    }

    users[userIndex].password = newPassword.trim();
    users[userIndex].mustChangePassword = false;
    writeJson(USERS_FILE, users);

    res.json({ success: true, message: 'Password updated successfully' });
});

app.get('/api/auth/users', (req, res) => {
    const users = readJson(USERS_FILE).map(u => ({
        id: u.id,
        username: u.username,
        role: u.role,
        createdAt: u.createdAt
    }));
    res.json(users);
});

app.post('/api/auth/users', (req, res) => {
    const { username, password, role } = req.body || {};
    if (!username || !password) {
        return res.status(400).json({ error: 'Username and password are required' });
    }

    let users = readJson(USERS_FILE);
    if (users.find(u => u.username.toLowerCase() === username.trim().toLowerCase())) {
        return res.status(400).json({ error: 'Username already exists' });
    }

    const newUser = {
        id: 'usr_' + Math.random().toString(36).substr(2, 9),
        username: username.trim(),
        password: password.trim(),
        role: role || 'Moderator',
        mustChangePassword: true,
        createdAt: new Date().toISOString()
    };

    users.push(newUser);
    writeJson(USERS_FILE, users);
    res.json({ success: true, user: newUser });
});

app.delete('/api/auth/users/:id', (req, res) => {
    let users = readJson(USERS_FILE);
    if (users.length <= 1) {
        return res.status(400).json({ error: 'Cannot delete the only remaining staff account' });
    }
    users = users.filter(u => u.id !== req.params.id);
    writeJson(USERS_FILE, users);
    res.json({ success: true });
});

// =============================================================
// FIVEM SYNC & INGESTION APIS
// =============================================================
app.post('/api/server/sync', authenticateServer, (req, res) => {
    const data = req.body || {};

    serverState.serverName = data.serverName || "FiveM Server";
    serverState.playerCount = data.playerCount || 0;
    serverState.uptime = data.uptime || 0;
    serverState.onlinePlayers = data.onlinePlayers || [];
    serverState.detections = data.detections || {};
    serverState.totalBans = data.totalBans || 0;
    serverState.lastSeen = Date.now();

    if (data.bans && Array.isArray(data.bans)) {
        let localBans = readJson(BANS_FILE);
        let updatedBans = false;

        data.bans.forEach(serverBan => {
            const existing = localBans.find(b => b.banId.toUpperCase() === serverBan.banId.toUpperCase());
            if (!existing) {
                const targetMatch = serverState.onlinePlayers.find(p => (p.identifiers && p.identifiers.license && serverBan.identifiers && serverBan.identifiers.license === p.identifiers.license));
                const pName = targetMatch ? targetMatch.name : (serverBan.license !== 'N/A' ? serverBan.license : `Banned Player (${serverBan.banId})`);

                localBans.unshift({
                    banId: serverBan.banId.toUpperCase(),
                    target: serverBan.license !== 'N/A' ? serverBan.license : serverBan.banId,
                    playerName: pName,
                    license: serverBan.license !== 'N/A' ? serverBan.license : 'N/A',
                    reason: serverBan.reason,
                    hours: serverBan.expires ? Math.max(1, Math.round((serverBan.expires - Math.floor(Date.now() / 1000)) / 3600)) : 720,
                    date: new Date().toLocaleString(),
                    revoked: false
                });
                updatedBans = true;
            } else {
                if (serverBan.license && serverBan.license !== 'N/A' && (!existing.license || existing.license === 'N/A')) {
                    existing.license = serverBan.license;
                    updatedBans = true;
                }
            }
        });

        const serverBanSet = new Set(data.bans.map(b => b.banId.toUpperCase()));
        localBans.forEach(b => {
            if (!serverBanSet.has(b.banId.toUpperCase()) && !b.revoked) {
                b.revoked = true;
                updatedBans = true;
            }
        });

        if (updatedBans) {
            writeJson(BANS_FILE, localBans);
        }
    }

    if (data.onlinePlayers && Array.isArray(data.onlinePlayers)) {
        const shots = readJson(SCREENSHOTS_FILE);
        let updatedShots = false;

        data.onlinePlayers.forEach(pl => {
            if (pl.source && pl.name) {
                const targetStr = String(pl.source);
                shots.forEach(s => {
                    if (String(s.target) === targetStr && (s.playerName.startsWith('Player ') || s.playerName === 'Unknown Player' || !s.playerName)) {
                        s.playerName = pl.name;
                        if (pl.identifiers && pl.identifiers.license && (s.license === 'N/A' || !s.license)) {
                            s.license = pl.identifiers.license;
                        }
                        updatedShots = true;
                    }
                });
            }
        });

        if (updatedShots) {
            writeJson(SCREENSHOTS_FILE, shots);
        }
    }

    if (data.ackCommands && Array.isArray(data.ackCommands)) {
        commandQueue = commandQueue.filter(cmd => !data.ackCommands.includes(cmd.id));
    }

    res.json({ commands: [...commandQueue] });
});

app.post('/api/server/violation', authenticateServer, (req, res) => {
    const violation = req.body || {};
    const playerKey = String(violation.source || violation.playerName || 'Unknown');

    if (!violationsByPlayer[playerKey]) {
        violationsByPlayer[playerKey] = {
            source: violation.source,
            playerName: violation.playerName,
            totalCount: 0,
            lastSeen: new Date().toLocaleTimeString(),
            detections: {},
            history: []
        };
    }

    const entry = violationsByPlayer[playerKey];
    entry.totalCount += 1;
    entry.lastSeen = new Date().toLocaleTimeString();
    entry.playerName = violation.playerName || entry.playerName;
    entry.detections[violation.detection] = (entry.detections[violation.detection] || 0) + 1;
    entry.history.unshift({
        detection: violation.detection,
        reason: violation.reason,
        punishment: violation.punishment,
        coords: violation.coords,
        time: new Date().toLocaleTimeString()
    });

    if (entry.history.length > 25) entry.history.pop();
    res.json({ success: true });
});

app.post('/api/server/upload-screenshot-base64', authenticateServer, (req, res) => {
    const { target, image, playerName, license } = req.body || {};
    if (!image) return res.status(400).json({ error: "Missing image data" });

    const targetId = String(target || 'unknown');
    const playerMeta = getPlayerMeta(targetId);
    const resolvedName = (playerName && playerName !== `Player ${targetId}`) ? playerName : playerMeta.playerName;
    const resolvedLicense = (license && license !== 'N/A') ? license : playerMeta.license;

    const base64Data = image.replace(/^data:image\/\w+;base64,/, "");
    const now = Date.now();
    const filename = `shot_${targetId}_${now}.png`;
    const filepath = path.join(UPLOAD_DIR, filename);

    fs.writeFile(filepath, base64Data, 'base64', (err) => {
        if (err) return res.status(500).json({ error: "Failed to save screenshot" });

        const shots = readJson(SCREENSHOTS_FILE);
        shots.unshift({
            id: 'shot_' + now,
            filename: filename,
            target: targetId,
            playerName: resolvedName,
            license: resolvedLicense,
            timestamp: new Date().toISOString(),
            formattedDate: new Date().toLocaleString()
        });
        writeJson(SCREENSHOTS_FILE, shots);

        res.json({ success: true, file: filename });
    });
});

app.post('/api/server/upload-screenshot', authenticateServer, upload.any(), (req, res) => {
    const file = req.files && req.files[0];
    if (file) {
        const targetId = String(req.query.target || 'unknown');
        const playerMeta = getPlayerMeta(targetId);
        const shots = readJson(SCREENSHOTS_FILE);
        shots.unshift({
            id: 'shot_' + Date.now(),
            filename: file.filename,
            target: targetId,
            playerName: playerMeta.playerName,
            license: playerMeta.license,
            timestamp: new Date().toISOString(),
            formattedDate: new Date().toLocaleString()
        });
        writeJson(SCREENSHOTS_FILE, shots);
    }
    res.json({ success: true, file: file ? file.filename : null });
});

// =============================================================
// STAFF DASHBOARD APIS
// =============================================================
app.get('/api/panel/data', (req, res) => {
    res.json({
        server: serverState,
        isOnline: (Date.now() - serverState.lastSeen) < 15000,
        playerViolations: violationsByPlayer,
        queuedCount: commandQueue.length
    });
});

app.post('/api/panel/clear-violations', (req, res) => {
    const { playerKey } = req.body || {};
    if (playerKey && violationsByPlayer[playerKey]) {
        delete violationsByPlayer[playerKey];
    } else {
        violationsByPlayer = {};
    }
    res.json({ success: true });
});

app.post('/api/panel/command', (req, res) => {
    const { action, target, reason, hours, command, playerName, license } = req.body || {};
    const cmdId = "cmd_" + Math.random().toString(36).substr(2, 9);

    if (action === 'screenshot' && target) {
        recentScreenshotTargets[String(target)] = {
            playerName: playerName || null,
            license: license || null,
            time: Date.now()
        };
    }

    let generatedBanId = null;
    if (action === 'ban') {
        const bans = readJson(BANS_FILE);
        generatedBanId = (Math.random().toString(16).substr(2, 8)).toUpperCase();
        bans.unshift({
            banId: generatedBanId,
            target: String(target),
            playerName: playerName || `Player ${target}`,
            license: license || 'N/A',
            reason: reason || 'Manual panel ban',
            hours: hours || 24,
            date: new Date().toLocaleString(),
            revoked: false
        });
        writeJson(BANS_FILE, bans);
    }

    commandQueue.push({
        id: cmdId,
        action,
        target,
        banId: generatedBanId,
        playerName,
        license,
        reason,
        hours,
        command
    });

    res.json({ success: true, queuedId: cmdId });
});

app.get('/api/panel/bans', (req, res) => {
    res.json(readJson(BANS_FILE));
});

app.post('/api/panel/unban', (req, res) => {
    const { banId, license, target } = req.body || {};
    if (!banId && !license && !target) return res.status(400).json({ error: 'Ban ID or Identifier required' });

    let bans = readJson(BANS_FILE);
    const query = (banId || license || target || '').toLowerCase();
    const banRecord = bans.find(b => 
        (b.banId && b.banId.toLowerCase() === query) ||
        (b.license && b.license.toLowerCase() === query) ||
        (b.target && String(b.target).toLowerCase() === query)
    );

    if (banRecord) {
        banRecord.revoked = true;
        writeJson(BANS_FILE, bans);
    }

    const resolvedBanId = (banRecord ? banRecord.banId : banId) || null;
    const resolvedLicense = (banRecord ? banRecord.license : license) || null;
    const resolvedTarget = (banRecord ? banRecord.target : target) || null;

    commandQueue.push({
        id: "cmd_" + Math.random().toString(36).substr(2, 9),
        action: 'unban',
        banId: resolvedBanId ? resolvedBanId.toUpperCase() : null,
        license: resolvedLicense && resolvedLicense !== 'N/A' ? resolvedLicense : null,
        target: resolvedTarget
    });

    res.json({ success: true, message: `Unban requested for: ${resolvedBanId || resolvedLicense || resolvedTarget}` });
});

app.get('/api/panel/screenshots', (req, res) => {
    const targetFilter = req.query.target;
    let shots = readJson(SCREENSHOTS_FILE);

    if (targetFilter) {
        shots = shots.filter(s => String(s.target) === String(targetFilter));
    }
    res.json({ screenshots: shots });
});

app.put('/api/panel/screenshots/:id', (req, res) => {
    const shotId = req.params.id;
    const { playerName } = req.body || {};
    if (!playerName) return res.status(400).json({ error: 'Player name required' });

    let shots = readJson(SCREENSHOTS_FILE);
    const shot = shots.find(s => s.id === shotId);
    if (shot) {
        shot.playerName = playerName.trim();
        writeJson(SCREENSHOTS_FILE, shots);
        return res.json({ success: true, shot });
    }
    res.status(404).json({ error: 'Screenshot not found' });
});

app.delete('/api/panel/screenshots/:id', (req, res) => {
    const shotId = req.params.id;
    let shots = readJson(SCREENSHOTS_FILE);
    const shot = shots.find(s => s.id === shotId);

    if (shot) {
        const filePath = path.join(UPLOAD_DIR, shot.filename);
        if (fs.existsSync(filePath)) {
            try { fs.unlinkSync(filePath); } catch {}
        }
        shots = shots.filter(s => s.id !== shotId);
        writeJson(SCREENSHOTS_FILE, shots);
    }

    res.json({ success: true });
});

app.post('/api/panel/unban-all', (req, res) => {
    const { license, target } = req.body || {};
    if (!license && !target) return res.status(400).json({ error: 'License or Target required' });

    let bans = readJson(BANS_FILE);
    const query = (license || target || '').toLowerCase();
    
    let revokedCount = 0;
    bans.forEach(b => {
        if (
            (b.license && b.license.toLowerCase() === query) ||
            (b.target && String(b.target).toLowerCase() === query)
        ) {
            if (!b.revoked) {
                b.revoked = true;
                revokedCount++;
            }
        }
    });

    if (revokedCount > 0) {
        writeJson(BANS_FILE, bans);
    }

    commandQueue.push({
        id: "cmd_" + Math.random().toString(36).substr(2, 9),
        action: 'unban_all',
        license: license || target
    });

    res.json({ success: true, message: `Successfully revoked \({revokedCount} bans for license:\){license || target}` });
});

app.use((err, req, res, next) => {
    console.error("[Panel Server Error]", err.message);
    res.status(err.status || 500).json({ error: err.message });
});

app.listen(PORT, () => {
    console.log(`====================================================`);
    console.log(`Apex Anticheat Cloud Dashboard running on port ${PORT}`);
    console.log(`Open in Browser: ${IP}]:${PORT}`);
    console.log(`====================================================`);
});