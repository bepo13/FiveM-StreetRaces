-- Server side array of active races
local races = {}
local startPositions = {}
local serverRaceData = {}

-- Server side scoreboards, per race
local raceScoreboards = {}

-- Cleanup thread
Citizen.CreateThread(function()
    -- Loop forever and check status every 100ms
    while true do
        Citizen.Wait(100)

        -- Check active races and remove any that become inactive
        for index, race in pairs(races) do
            -- Get time and players in race
            local time = GetGameTimer()
            local players = race.players
            --local notifyPlayers = race.notifyPlayers
            
            -- Check start time and player count
            if (time > race.startTime) and (#players == 0) then
                -- Race past start time with no players, remove race and send event to all clients
                table.remove(races, index)
                
                -- Wait a Second before Disabling Spectate Mode
                Citizen.SetTimeout(1000, function()
                    -- Disable Spectate Mode and Cancel DNF Timer
                    TriggerClientEvent('BT:Client:Spectate', -1, false)
                    TriggerClientEvent("mrp_races:createTimerDNF_cl", -1, 0)
                end)
                
                -- Wait for 8 Seconds before Removing Race, so Everybody can look at the Scoreboard
                Citizen.SetTimeout(8000, function()
                    -- Remove and Cleanup Race for All Players
                    TriggerClientEvent("mrp_races:removeRace_cl", -1, index)
                end)
            -- Check if race has finished and expired
            elseif (race.finishTime ~= 0) and (race.timerDNF) and (time > race.finishTime + race.finishTimeout) then
                -- Did not finish, notify players still racing
                for _, player in pairs(players) do
                    notifyPlayer(player, "DNF (Timeout)")
                end

                -- Remove race and send event to all clients
                table.remove(races, index)

                -- Wait a Second before Disabling Spectate Mode
                Citizen.SetTimeout(1000, function()
                    -- Disable Spectate Mode and Cancel DNF Timer
                    TriggerClientEvent('BT:Client:Spectate', -1, false)
                    TriggerClientEvent("mrp_races:createTimerDNF_cl", -1, 0)
                end)
                
                -- Wait for 8 Seconds before Removing Race, so Everybody can look at the Scoreboard
                Citizen.SetTimeout(8000, function()
                    -- Remove and Cleanup Race for All Players
                    TriggerClientEvent("mrp_races:removeRace_cl", -1, index)
                end)
            end
        end
    end
end)

-- Sorted Pairs
function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

-- Sort Function for Scoreboard
function sortScoreboard(tbl, a, b)
    -- If both players are on the same checkpoint
    if tbl[b].checkpoint == tbl[a].checkpoint then
        -- Sort by remaining distance to next checkpoint
        return tbl[b].remainingDistance > tbl[a].remainingDistance
    else
        -- Sort by number of checkpoints
        return tbl[b].checkpoint < tbl[a].checkpoint
    end
end

-- Server event for scoreboard updates
RegisterNetEvent("mrp_races:scoreboardUpdate_sv")
AddEventHandler("mrp_races:scoreboardUpdate_sv", function(index, entry)
    -- Check Scoreboard
    if raceScoreboards[index] ~= nil then
        -- Get Scoreboard
        local scoreboard = raceScoreboards[index]
        local playerFinished = false
        
        -- Check if Player has already finished the race
        if scoreboard[source] ~= nil and scoreboard[source].finished then
            playerFinished = true
        end
        
        -- Only Update Score if not yet finished (because Remaining Distance contains Position, for Sorting)
        if not playerFinished and entry.finished == false then
            -- Create Player Entry in Scoreboard
            if scoreboard[source] == nil then
                scoreboard[source] = {}
            end
        
            -- Set Additonal Player Data
            entry.playerName = getName(source)
            entry.playerPing = GetPlayerPing(source)
            
            -- Update Player Entry of Scoreboard
            for key, value in pairs(entry) do
                scoreboard[source][key] = entry[key]
            end
        end

        -- Generate Leaderboard
        local leaderboard = {}
        
        -- Sort Player Scores and Generate Leaderboard
        for playerId, score in spairs(scoreboard, sortScoreboard) do
            table.insert(leaderboard, playerId)
        end
        
        -- Send Scoreboard and Leaderboard back to Player
        TriggerClientEvent("mrp_races:scoreboardUpdate_cl", source, scoreboard, leaderboard)
    end
end)

-- Server event for creating a race
RegisterNetEvent("mrp_races:createRace_sv")
AddEventHandler("mrp_races:createRace_sv", function(amount, startDelay, startCoords, checkpoints, finishTimeout)
    -- Add fields to race struct and add to races array
    local race = {
        owner = source,
        amount = amount,
        startTime = GetGameTimer() + startDelay,
        startCoords = startCoords,
        checkpoints = checkpoints,
        finishTimeout = config_sv.finishTimeout,
        players = {},
        notifyPlayers = {},
        prize = 0,
        finishTime = 0,
        finishPosition = 0,
        timerDNF = false
    }
    table.insert(races, race)
    
    local raceData = serverRaceData[source]

    -- Send race data to all clients
    local index = #races
    TriggerClientEvent("mrp_races:createRace_cl", -1, index, amount, startDelay, startCoords, checkpoints, raceData)
    
    -- Create Scoreboard for Race Index
    raceScoreboards[index] = {}
end)

-- Server event for canceling a race
RegisterNetEvent("mrp_races:cancelRace_sv")
AddEventHandler("mrp_races:cancelRace_sv", function()
    -- Iterate through races
    for index, race in pairs(races) do
        -- Find if source player owns a race that hasn't started
        local time = GetGameTimer()
        if source == race.owner and time < race.startTime then
            -- Send notification and refund money for all entered players
            for _, player in pairs(race.players) do
                -- Refund money to player and remove from prize pool
                addMoney(player, race.amount)
                race.prize = race.prize - race.amount

                -- Notify player race has been canceled
                local msg = "Race canceled"
                notifyPlayer(player, msg)
            end

            -- Remove race from table and send client event
            table.remove(races, index)
            TriggerClientEvent("mrp_races:removeRace_cl", -1, index)
            
            -- Reset Scoreboard for Race Index
            raceScoreboards[index] = {}
        end
    end
end)

function GetTableLng(tbl)
  local getN = 0
  for n in pairs(tbl) do 
    getN = getN + 1 
  end
  return getN
end

-- Server event for joining a race
RegisterNetEvent("mrp_races:joinRace_sv")
AddEventHandler("mrp_races:joinRace_sv", function(index)
    -- Validate and deduct player money
    local race = races[index]
    local amount = race.amount
    local playerId = source
    local playerMoney = getMoney(playerId)
    if playerMoney >= amount then
        -- Deduct money from player and add to prize pool
        removeMoney(playerId, amount)
        race.prize = race.prize + amount
        
        -- Get Start Positions
        --local positions = startPositions[race.owner]
        local positions = race.checkpoints
        local nextPosition = #races[index].players + 1
        local raceData = serverRaceData[race.owner]
        
        -- Check Number of Start Positions
        --if #positions >= nextPosition then
            -- Add player to race and send join event back to client
            table.insert(races[index].players, playerId)
            table.insert(races[index].notifyPlayers, playerId)
            --TriggerClientEvent("mrp_races:joinedRace_cl", playerId, index, positions[nextPosition], positions[1], raceData)
            TriggerClientEvent("mrp_races:joinedRace_cl", playerId, index, positions[1], positions[1], raceData)
        --else
            -- No More Start Positions, send notification back to client
            --local msg = "All start positions are already filled :("
            --notifyPlayer(playerId, msg)
        --end
    else
        -- Insufficient money, send notification back to client
        local msg = "Insuffient funds to join race"
        notifyPlayer(playerId, msg)
    end
end)

-- Server event for leaving a race
RegisterNetEvent("mrp_races:leaveRace_sv")
AddEventHandler("mrp_races:leaveRace_sv", function(index)
    -- Validate player is part of the race
    local race = races[index]
    local players = race.players
    local notifyPlayers = race.notifyPlayers
    for index, player in pairs(players) do
        if source == player then
            -- Remove player from race and break
            table.remove(players, index)
            table.remove(notifyPlayers, index)
            break
        end
    end
end)

-- Server event for finishing a race
RegisterNetEvent("mrp_races:finishedRace_sv")
AddEventHandler("mrp_races:finishedRace_sv", function(index, time, finishCP, totalDistance)
    -- Check player was part of the race
    local race = races[index]
    local players = race.players
    local playerId = source
    for playerIndex, player in pairs(players) do
        if source == player then 
            source = player
        
            -- Calculate finish time
            local time = GetGameTimer()
            local timeSeconds = (time - race.startTime)/1000.0
            local timeMinutes = math.floor(timeSeconds/60.0)
            local timeHours = math.floor(timeMinutes/60.0)
            timeSeconds = timeSeconds - 60.0*timeMinutes
            timeMinutes = timeMinutes - 60.0*timeHours
            
            -- Get Scoreboard
            local scoreboard = raceScoreboards[index]
            local playerScore = scoreboard[source]

            -- Update Finish Position
            race.finishPosition = race.finishPosition + 1
            
            -- Update Player Entry
            playerScore.finished = true
            playerScore.checkpoint = finishCP
            playerScore.totalDistance = totalDistance
            playerScore.remainingDistance = race.finishPosition
            playerScore.finishTime = ("%02d:%02d:%06.3f"):format(timeHours, timeMinutes, timeSeconds)
            
            -- Check Suffix for Position
            local suffixList = { "st", "nd", "rd" }
            local suffix = suffixList[race.finishPosition]
            
            -- Append "th" for other Positions
            if suffix == nil then
                suffix = "th"
            end
            
            -- Set Finish Time to Restart DNF Timer
            race.finishTime = time
            
            -- Send winner notification to players
            for _, pSource in pairs(race.notifyPlayers) do
                if pSource == player then
                    if race.finishPosition == 1 then
                        addMoney(pSource, race.prize)
                    end
                    local msg = ("You finished in %d%s place [%s]"):format(race.finishPosition, suffix, playerScore.finishTime)
                    notifyPlayer(pSource, msg)
                elseif config_sv.notifyOfWinner then
                    local msg = ("%s finished in %d%s [%s]"):format(getName(player), race.finishPosition, suffix, playerScore.finishTime)
                    notifyPlayer(pSource, msg)
                end
            end

            -- Notify Players of Current Race with Notification Popup (Above Minimap)
            TriggerClientEvent("mrp_races:playerNotification_cl", -1, ("~b~%s~w~ finished in %d%s"):format(getName(player), race.finishPosition, suffix))

            -- Trigger Spectating Mode for Player
            TriggerClientEvent('BT:Client:Spectate', player, true)
            TriggerClientEvent("mrp_races:playerNotification_cl", -1, ("~b~%s~w~ is now spectating"):format(getName(player)))
            
            -- Remove player form list and break
            table.remove(players, playerIndex)
            break
        end
    end
    
    -- Check DNF Timer
    if #race.players <= math.floor(#race.notifyPlayers / 2.0) then
        race.timerDNF = true
        
        TriggerClientEvent("mrp_races:createTimerDNF_cl", -1, race.finishTimeout)
        TriggerClientEvent("mrp_races:playerNotification_cl", -1, "~r~DNF Timer~w~ started!")
    end
end)

-- Server event for saving recorded checkpoints as a race
RegisterNetEvent("mrp_races:saveRace_sv")
AddEventHandler("mrp_races:saveRace_sv", function(name, checkpoints, numberOfLaps)
    -- Cleanup data so it can be serialized
    for _, checkpoint in pairs(checkpoints) do
        checkpoint.id = nil
        checkpoint.blip = nil
        checkpoint.coords = {x = checkpoint.coords.x, y = checkpoint.coords.y, z = checkpoint.coords.z}
    end
    
    local playerId = source
    
    local laps = 1
    if numberOfLaps ~= nil then
        laps = numberOfLaps
    end

    -- Get saved player races, add race and save
    local playerRaces = {name = name}
    playerRaces[name] = checkpoints

    -- Finish Mode 1 (DNF Timer until Final Finish Line), Finish Mode 2 (DNF Timer until Next Finish Line)
    playerRaces["data"] = { laps = laps, finishMode = 2 }
    savePlayerData(playerId, playerRaces)

    -- Send notification to player
    local msg = "Saved " .. name
    notifyPlayer(playerId, msg)
end)

-- Server event for saving recorded start positions
RegisterNetEvent("mrp_races:saveStartPos_sv")
AddEventHandler("mrp_races:saveStartPos_sv", function(name, positions)
    -- Get saved player races, add race and save
    local playerId = source
    local playerRaces = loadPlayerData(playerId)
    playerRaces["pos"] = positions
    savePlayerData(playerId, playerRaces)

    -- Send notification to player
    local msg = "Saved Positions for " .. name
    local playerId = source
    notifyPlayer(playerId, msg)
end)

-- Server event for deleting recorded race
RegisterNetEvent("mrp_races:deleteRace_sv")
AddEventHandler("mrp_races:deleteRace_sv", function(name)
    local playerId = source
    -- Get saved player races
    local playerRaces = loadPlayerData(playerId)

    -- Check if race with name exists
    if playerRaces[name] ~= nil then
        -- Delete race and save data
        playerRaces[name] = nil
        savePlayerData(playerId, playerRaces)

        -- Send notification to player
        local msg = "Deleted " .. name
        notifyPlayer(playerId, msg)
    else
        local msg = "No race found with name " .. name
        notifyPlayer(playerId, msg)
    end
end)

-- Server event for listing recorded races
RegisterNetEvent("mrp_races:listRaces_sv")
AddEventHandler("mrp_races:listRaces_sv", function()
    -- Get saved player races and iterate through saved races
    local msg = "Saved races: "
    local count = 0
    local playerId = source
    local playerRaces = loadPlayerData(playerId)
    for name, race in pairs(playerRaces) do
        msg = msg .. name .. ", "
        count = count + 1
    end

    -- Fix string formatting
    if count > 0 then
        msg = string.sub(msg, 1, -3)
    end

    -- Send notification to player with listing
    notifyPlayer(playerId, msg)
end)

-- Fisher Yates Shuffle
function FYShuffle(tInput)
    local tReturn = {}
    for i = #tInput, 1, -1 do
        local j = math.random(i)
        tInput[i], tInput[j] = tInput[j], tInput[i]
        table.insert(tReturn, tInput[i])
    end
    return tReturn
end

-- Server event for loaded recorded race
RegisterNetEvent("mrp_races:loadRace_sv")
AddEventHandler("mrp_races:loadRace_sv", function(name)
    local playerId = source
    -- Get saved player races and load race
    local playerRaces = loadPlayerData(playerId)
    local race = playerRaces[name]
    local raceData = race["data"]

    -- If race was found send it to the client
    if race ~= nil then
        -- Send race data to client
        TriggerClientEvent("mrp_races:loadRace_cl", playerId, race.checkpoints)

        -- Send notification to player
        local msg = "Loaded " .. name
        notifyPlayer(playerId, msg)
    else
        local msg = "No race found with name " .. name
        notifyPlayer(playerId, msg)
    end
    
    -- Use Empty Start Positions
    startPositions[playerId] = {}

    local msg = "No start positions found for race " .. name
    notifyPlayer(playerId, msg)
    
    if raceData ~= nil then
        -- Remember Race Data on Server
        serverRaceData[playerId] = raceData

        -- Send notification to player
        local msg = "Loaded Race Data for " .. name
        notifyPlayer(playerId, msg)
    else
        -- Use Default Race Data, Cars Per Lap = 1 (New Car on Finish Line), Cars Per Lap > 1 (New Car on Finish Line and Mid-Round)
        serverRaceData[playerId] = { laps = 1, finishMode = 2 }
    
        local msg = "No race data found for race " .. name
        notifyPlayer(playerId, msg)
    end
end)

-- Server event for a player death
RegisterNetEvent("baseevents:onPlayerDied")
AddEventHandler("baseevents:onPlayerDied", function(reason)
    TriggerClientEvent("mrp_races:playerNotification_cl", -1, ("~r~%s~w~ died"):format(getName(source)))
end)

-- Server event for a player kill
RegisterNetEvent("baseevents:onPlayerKilled")
AddEventHandler("baseevents:onPlayerKilled", function(killerID, deathData)
    TriggerClientEvent("mrp_races:playerNotification_cl", -1, ("~r~%s~w~ was killed by ~r~%s"):format(getName(source), getName(killerID)))
end)
