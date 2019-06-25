ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Helper function for getting player money
function getMoney(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    local getmoney = xPlayer.getMoney()
    return getmoney
end

-- Helper function for removing player money
function removeMoney(source, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.removeMoney(amount)
end

-- Helper function for adding player money
function addMoney(source, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.addMoney(amount)
end

-- Helper function for getting player name
function getName(source)
    return GetPlayerName(source)
end

-- Helper function for notifying players
function notifyPlayer(source, msg)
    TriggerClientEvent('chatMessage', source, "[RACE]", {255,64,64}, msg)
end
