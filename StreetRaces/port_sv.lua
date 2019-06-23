-- Helper function for getting player money
function getMoney(source)
    -- Add framework API's here (return large number by default)
    return 1000000
end

-- Helper function for removing player money
function removeMoney(source, amount)
    -- Add framework API's here
end

-- Helper function for adding player money
function addMoney(source, amount)
    -- Add framework API's here
end

-- Helper function for getting player name
function getName(source)
    -- Add framework API's here
    return GetPlayerName(source)
end

-- Helper function for notifying players
function notifyPlayer(source, msg)
    -- Add custom notification here (use chat by default)
    TriggerClientEvent('chatMessage', source, "[RACE]", {255,64,64}, msg)
end
