local ACE = ACE


if CLIENT then
    --[[
        We verify that our addon meets the requirements it needs. We send an alert in case something is missing.
        Also, we will check and let the users know if there are other ACF/old ACE versions currently installed.
    ]]
    local function CheckAddon()
        if ACE.ArmorTypes then
            hook.Add("CreateMove", "ACE Conflict", function(Move)
                if Move:GetButtons() ~= 0 then
                    ACE.PrintChatMessage( false, "Outdated ACE version detected! Potential Integrity failure! Verify the installation." )
                    hook.Remove("CreateMove", "ACE Conflict")
                end
            end)
        end

        if ACF and ACF.Repositories then
            hook.Add("CreateMove", "ACE ACF3 Reminder", function(Move)
                if Move:GetButtons() ~= 0 then
                    ACE.PrintChatMessage( false, "ACF-3 detected! While ACE should work, probably certain stuff doesn't. Use it at your own risk." )
                    hook.Remove("CreateMove", "ACE ACF3 Reminder")
                end
            end)
        end

        if not WireLib then
            hook.Add("CreateMove", "ACE Missing Wiremod", function(Move)
                if Move:GetButtons() ~= 0 then
                    ACE.PrintChatMessage( false, "Wiremod not installed! ACE requires it to work properly. Get it at: https://steamcommunity.com/sharedfiles/filedetails/?id=160250458" )
                    hook.Remove("CreateMove", "ACE Missing Wiremod")
                end
            end)
        end

        if not CFW then
            hook.Add("CreateMove", "ACE Missing CFW", function(Move)
                if Move:GetButtons() ~= 0 then
                    ACE.PrintChatMessage( false, "CFW not installed! ACE requires it to work properly. Get it at: https://steamcommunity.com/sharedfiles/filedetails/?id=3154971187" )
                    hook.Remove("CreateMove", "ACE Missing CFW")
                end
            end)
        end
    end

    hook.Add("InitPostEntity", "ACE Addon Checker", function()
        CheckAddon()
        hook.Remove("InitPostEntity", "ACE Addon Checker")
    end)
end
