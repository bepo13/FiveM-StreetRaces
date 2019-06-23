-- Server side array of active races
local races = {}

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

            -- Check start time and player count
            if (time > race.startTime) and (#players == 0) then
                -- Race past start time with no players, remove race and send event to all clients
                table.remove(races, index)
                TriggerClientEvent("races:removeRace_cl", -1, index)
            -- Check if race has finished and expired
            elseif (race.finishTime ~= 0) and (time > race.finishTime + race.finishTimeout) then
                -- Did not finish, notify players still racing
                for _, player in pairs(players) do
                    notifyPlayer(player, "DNF (timeout)")
                end

                -- Remove race and send event to all clients
                table.remove(races, index)
                TriggerClientEvent("races:removeRace_cl", -1, index)
            end
        end
    end
end)

-- Server event for creating a race
RegisterNetEvent("races:createRace_sv")
AddEventHandler("races:createRace_sv", function(amount, startDelay, startCoords, checkpoints, finishTimeout)
    -- Add fields to race struct and add to races array
    local race = {
        owner = source,
        amount = amount,
        startTime = GetGameTimer() + startDelay,
        startCoords = startCoords,
        checkpoints = checkpoints,
        players = {},
        finishTimeout = finishTimeout,
        finishTime = 0
    }
    table.insert(races, race)

    -- Send race data to all clients
    local index = #races
    TriggerClientEvent("races:createRace_cl", -1, index, amount, startDelay, startCoords, checkpoints)
end)

-- Server event for canceling a race
RegisterNetEvent("races:cancelRace_sv")
AddEventHandler("races:cancelRace_sv", function()
    -- Iterate through races
    for index, race in pairs(races) do
        -- Find if source player owns a race that hasn't started
        local time = GetGameTimer()
        if source == race.owner and time < race.startTime then
            -- Send notification and refund money for all entered players
            for _, player in pairs(race.players) do
                local msg = "Race canceled"
                notifyPlayer(player, msg)
                addMoney(player, race.amount)
            end

            -- Remove race from table and send client event
            table.remove(races, index)
            TriggerClientEvent("races:removeRace_cl", -1, index)
        end
    end
end)

-- Server event for joining a race
RegisterNetEvent("races:joinRace_sv")
AddEventHandler("races:joinRace_sv", function(index)
    -- Validate and deduct player money
    local amount = races[index].amount
    local playerMoney = getMoney(source)
    if playerMoney >= amount then
        -- Deduct money and add player to race
        removeMoney(source, amount)
        table.insert(races[index].players, source)

        -- Send join event back to client
        TriggerClientEvent("races:joinedRace_cl", source, index)
    else
        -- Insufficient money, send notification back to client
        local msg = "Insuffient funds to join race"
        notifyPlayer(source, msg)
    end
end)

-- Server event for leaving a race
RegisterNetEvent("races:leaveRace_sv")
AddEventHandler("races:leaveRace_sv", function(index)
    -- Validate player is part of the race
    local race = races[index]
    local players = race.players
    for index, player in pairs(players) do
        if source == player then
            -- Remove player from race and break
            table.remove(players, index)
            break
        end
    end
end)

-- Server event for finishing a race
RegisterNetEvent("races:finishedRace_sv")
AddEventHandler("races:finishedRace_sv", function(index, time)
    -- Check player was part of the race
    local race = races[index]
    local players = race.players
    for index, player in pairs(players) do
        if source == player then 
            -- Calculate finish time
            local time = GetGameTimer()
            local timeSeconds = (time - race.startTime)/1000.0
            local timeMinutes = math.floor(timeSeconds/60.0)
            timeSeconds = timeSeconds - 60.0*timeMinutes

            -- If race has not finished already
            if race.finishTime == 0 then
                -- Winner, set finish time and award prize money
                race.finishTime = time
                local prize = race.amount * #players
                addMoney(source, prize)

                -- Send winner notification to all clients
                local msg = ("%s won (%02d:%06.3f)"):format(getName(source), timeMinutes, timeSeconds)
                notifyPlayer(-1, msg)
            else
                -- Loser, send notification to only the player
                local msg = ("You lost (%02d:%06.3f)"):format(timeMinutes, timeSeconds)
                notifyPlayer(source, msg)
            end

            -- Remove player form list and break
            table.remove(players, index)
            break
        end
    end
end)