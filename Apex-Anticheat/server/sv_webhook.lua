ApexWebhook = {}

local function GetIdentifier(source, idType)
    local src = tostring(source)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:sub(1, #idType + 1) == (idType .. ':') then
            return id:sub(#idType + 2)
        end
    end
    return 'unknown'
end

local ACTION_COLORS <const> = {
    ['BAN']                    = 16711680, -- Red
    ['KICK']                   = 16744448, -- Orange
    ['WARN']                   = 16776960, -- Yellow
    ['FLAGGED (STAFF REVIEW)'] = 3447003   -- Blue
}

function ApexWebhook:SendAlert(source, actionType, reason, detectionKey)
    local webhook = Config.DiscordWebhook
    if not webhook or webhook == '' then return end

    local src = tostring(source)
    local name = GetPlayerName(src) or 'Unknown'
    local license = GetIdentifier(src, 'license')
    local steam = GetIdentifier(src, 'steam')
    local discord = GetIdentifier(src, 'discord')

    local embed = {
        {
            ['color'] = ACTION_COLORS[actionType] or 16711680,
            ['title'] = string.format('🛡️ Apex Detection: %s [%s]', detectionKey or 'General', actionType),
            ['fields'] = {
                { ['name'] = 'Player', ['value'] = string.format('%s (ID: %s)', name, src), ['inline'] = true },
                { ['name'] = 'Action Taken', ['value'] = string.format('**%s**', actionType), ['inline'] = true },
                { ['name'] = 'Violation', ['value'] = reason, ['inline'] = false },
                { ['name'] = 'Discord', ['value'] = discord ~= 'unknown' and ('<@' .. discord .. '>') or 'Not Linked', ['inline'] = true },
                { ['name'] = 'License', ['value'] = string.format('```%s```', license), ['inline'] = false },
                { ['name'] = 'Steam ID', ['value'] = string.format('```%s```', steam), ['inline'] = false }
            },
            ['footer'] = { ['text'] = 'Apex-Anticheat v3.1.0' },
            ['timestamp'] = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }
    }

    PerformHttpRequest(webhook, function() end, 'POST', json.encode({
        username = 'Apex Anticheat',
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

function ApexWebhook:SendBanAlert(source, reason, banId)
    local webhook = Config.DiscordWebhook
    if not webhook or webhook == '' then return end

    local src = tostring(source)
    local name = GetPlayerName(src) or 'Unknown'
    local license = GetIdentifier(src, 'license')
    local steam = GetIdentifier(src, 'steam')
    local discord = GetIdentifier(src, 'discord')

    local embed = {
        {
            ['color'] = 16711680, -- Red
            ['title'] = '🚨 Cheater Banned Permanently',
            ['fields'] = {
                { ['name'] = 'Player', ['value'] = string.format('%s (ID: %s)', name, src), ['inline'] = true },
                { ['name'] = 'Ban ID', ['value'] = banId, ['inline'] = true },
                { ['name'] = 'Violation', ['value'] = reason, ['inline'] = false },
                { ['name'] = 'Discord', ['value'] = discord ~= 'unknown' and ('<@' .. discord .. '>') or 'Not Linked', ['inline'] = true },
                { ['name'] = 'License', ['value'] = string.format('```%s```', license), ['inline'] = false },
                { ['name'] = 'Steam ID', ['value'] = string.format('```%s```', steam), ['inline'] = false }
            },
            ['footer'] = { ['text'] = 'Apex-Anticheat v3.1.0' },
            ['timestamp'] = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }
    }

    PerformHttpRequest(webhook, function() end, 'POST', json.encode({
        username = 'Apex Anticheat',
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end