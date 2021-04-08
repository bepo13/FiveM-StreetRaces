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

-- Saved player data and file
local playersData = nil
local playersDataFile = "./StreetRaces_saveData.txt"

-- Helper function for loading saved player data
function loadPlayerData(source)
    -- Load data from file if not already initialized
    if playersData == nil then
        playersData = {}
        local file = io.open(playersDataFile, "r")
        if file then
            local contents = file:read("*a")
            playersData = json.decode(contents);
            io.close(file)
        end
    end

    -- Get player steamID from source and use as key to get player data
    -- local playerId = string.sub(GetPlayerIdentifier(source, 0), 7, -1)
    local playerData = playersData["all"]

    -- Return saved player data
    if playerData == nil then
        playerData = {}
    end
    return playerData
end

-- Helper function for saving player data
function savePlayerData(source, data)
    -- Load data from file if not already initialized
    if playersData == nil then
        playersData = {}
        local file = io.open(playersDataFile, "r")
        if file then
            local contents = file:read("*a")
            playersData = json.decode(contents);
            io.close(file)
        end
    end

    -- Get player steamID from source and use as key to save player data
    -- local playerId = string.sub(GetPlayerIdentifier(source, 0), 7, -1)
    playersData["all"] = data

    -- Save file
    local file = io.open(playersDataFile, "w+")
    if file then
        local contents = json.encode(playersData)
        file:write(contents)
        io.close(file)
    end
end
