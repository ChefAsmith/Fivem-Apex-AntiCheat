local ProhibitedVariables = {
    'WarMenu', 'AlikhanCheats', 'LynxEvo', 'FendinX', 'HamMafia',
    'TiagoMenu', 'BrutanPremium', 'd0pamine', 'Dopameme', 'Lux',
    'rootMenu', 'SwagMenu', 'AlphaV', 'Infinity', 'gaybuild', 'nukeserver'
}

CreateThread(function()
    while true do
        Wait(10000)
        for _, var in ipairs(ProhibitedVariables) do
            if _G[var] ~= nil then
                TriggerServerEvent('apex:clientDetection', 'BlacklistedCheatVar', 'Blacklisted variable detected: ' .. var)
                break
            end
        end
    end
end)