MRP = nil
Citizen.CreateThread(function()
    while MRP == nil do
        Citizen.Wait(0)
        TriggerEvent('mrp:getSharedObject', function(obj) MRP = obj end)
    end
end)

-- Helper function for getting player money
function getMoney(source)
    local char = MRP.getSpawnedCharacter(source)
    if char ~= nil then
        return char.stats.cash
    end
    return 0
end

-- Helper function for removing player money
function removeMoney(source, amount)
    TriggerEvent('mrp:bankin:server:add:cash', source, -amount)
end

-- Helper function for adding player money
function addMoney(source, amount)
    TriggerEvent('mrp:bankin:server:add:cash', source, amount)
end

-- Helper function for getting player name
function getName(source)
    local char = MRP.getSpawnedCharacter(source)
    if char ~= nil then
        return char.name .. ' ' .. char.surname
    end
    return 'Unavailable'
end

-- Helper function for notifying players
function notifyPlayer(source, msg)
    if msg == nil then
        msg = "no races"
    end
    -- Add custom notification here (use chat by default)
    TriggerClientEvent('chatMessage', source, "[StreetRaces]", {255, 0, 0}, msg)
end

-- Helper function for loading saved player data
function loadPlayerData(source)
    local playerData = nil
    
    MRP.find('race_tracks', {}, {}, {skip = false, limit = false}, function(res)
        playerData = {}
        
        for name, value in pairs(res) do
            for k, race in pairs(value) do
                if k ~= "name" and k ~= "_id" then
                    playerData[k] = {
                        checkpoints = race,
                        data = value.data,
                    }
                end
            end
        end
    end)
    
    while playerData == nil do
        Citizen.Wait(0)
    end
    
    return playerData
end

-- Helper function for saving player data
function savePlayerData(source, data)
    print(json.encode(data))
    MRP.update('race_tracks', data, {name = data.name}, {upsert=true}, function(res)
        print('race track saved')
    end)
end

-- helper for deleting race
function deleteRace(name)
    MRP.deleteQuery('race_tracks', {name = name})
end
