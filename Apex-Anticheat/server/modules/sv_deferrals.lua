AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(50)

    -- 1. Persistent KVP Ban Check
    local isBanned, ban = ApexBanManager:IsBanned(src)
    if isBanned then
        deferrals.done(string.format('\n[Apex-Anticheat]\nYou are banned from this server.\nBan ID: %s\nReason: %s', ban.id, ban.reason))
        return
    end

    -- 2. Name Validation
    if Config.Modules.Deferrals.NameFilter.enabled then
        if name:match('[^%w%s%._%-%[%]%(%)]') then
            deferrals.done(Config.Modules.Deferrals.NameFilter.rejectionMsg)
            return
        end
    end

    deferrals.done()
end)