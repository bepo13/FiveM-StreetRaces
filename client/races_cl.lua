-- DEFINITIONS AND CONSTANTS
local RACE_STATE_NONE = 0
local RACE_STATE_JOINED = 1
local RACE_STATE_RACING = 2
local RACE_STATE_RECORDING = 3
local RACE_STATE_SPECTATING = 4

-- RACE CHECKPOINT TYPES
local RACE_CHECKPOINT_TYPE = 7 --6 --31
local RACE_CHECKPOINT_LAP_TYPE = 9
local RACE_CHECKPOINT_FINISH_TYPE = 10 --9 --34

-- START POSITION CHECKPOINT TYPE
local STARTPOS_CHECKPOINT_TYPE = 45

-- SPEEDOMETER AND TIME PARAMETERS
local speedColorText = {200, 200, 200}
local clockColorText = {220, 220, 220}

-- Races and race status
local races = {}
local raceStatus = {
-- Race Info
    state = RACE_STATE_NONE,        -- Current Race State
    index = 0,                      -- Index of the Current Race
    checkpoint = 0,                 -- Index of the Next Checkpoint
    checkpointsPerLap = 1,          -- Number of Checkpoints per Lap

-- Leaderboard Logic
    lastCheckpointPos = 0,          -- Coords of the Last Checkpoint
    totalDistance = 0,              -- Total Driven Distance (of Race)
    checkpointDistance = 0,         -- Distance to Last Checkpoint
    remainingDistance = 0,          -- Remaining Distance (to Next Checkpoint)

-- Starting Positions
    firstPos = vector3(0, 0, 0),    -- First Start Position (as Reference for Start Point)
    startPos = vector3(0, 0, 0),    -- Start Position for Current Player
    startHeading = 0,               -- Start Heading for Current Player

-- Position and Finish Logic
    position = 0,                   -- Position in Current Race
    totalPlayers = 0,               -- Total Players in Current Race
    finished = false,               -- Player has finished Race
    finishedCP = 0,                 -- The Checkpoint of the Finish Line
    dnfTime = 0,                    -- DNF Timeout

-- Multi Lap Config
    laps = 1,                       -- Number of Laps
    finishMode = 1,                 -- Mode 1 (DNF Timer until Final Finish Line), Mode 2 (DNF Timer until Next Finish Line)
}

-- Scoreboard (PlayerID as Key)
local scoreboard = {}
local leaderboard = {}
local hudComponents = {}

-- Internal Flags
local debugFlag = false
local radarBigmapEnabled = false

-- Recorded checkpoints
local recordedCheckpoints = {}
local recordedStartPositions = {}

-- Used for Frames per Second Calculation
local fps = {
    prevFrames = 0,
    prevTime = 0,
    curTime = 0,
    curFrames = 0,
    value = 0
}

-- Constants (HUD Components)
local VEHICLE_NAME = 6
local AREA_NAME = 7
local VEHICLE_CLASS = 8
local STREET_NAME = 9

-- Shows a Notification on the player's screen
function ShowNotification( text )
    SetNotificationTextEntry("STRING")
    AddTextComponentSubstringPlayerName(text)
    DrawNotification(false, false)
end

-- Tasks for Plugin Initialization
function Initialize()
    -- Get Initial Position of Bottom Right HUD Components
    hudComponents[VEHICLE_NAME] = GetHudComponentPosition(VEHICLE_NAME)
    hudComponents[VEHICLE_CLASS] = GetHudComponentPosition(VEHICLE_CLASS)
    hudComponents[STREET_NAME] = GetHudComponentPosition(STREET_NAME)
    hudComponents[AREA_NAME] = GetHudComponentPosition(AREA_NAME)
end

function displayHelpText(str)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentString(str)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Main command for races
RegisterCommand("race", function(source, args)
    if args[1] == "clear" or args[1] == "leave" then
        -- If player is part of a race, clean up map and send leave event to server
        if raceStatus.state == RACE_STATE_JOINED or raceStatus.state == RACE_STATE_RACING then
            cleanupRace()
            TriggerServerEvent('mrp_races:leaveRace_sv', raceStatus.index)
        elseif raceStatus.state == RACE_STATE_RECORDING then
            cleanupRace()
            cleanupRecording()
        end

        -- Reset state
        raceStatus.index = 0
        raceStatus.checkpoint = 0
        raceStatus.state = RACE_STATE_NONE
    elseif args[1] == "record" then
        -- Clear waypoint, cleanup recording and set flag to start recording
        SetWaypointOff()
        cleanupRecording()
        raceStatus.state = RACE_STATE_RECORDING
    elseif args[1] == "pos" then
        -- Cleanup Previous Start Positions
        SetWaypointOff()
        cleanupRace();
        
        local mode = args[2]
        if mode ~= nil and mode == "clear" then
            -- Clean Positions
            cleanupRace();
            cleanupRecording();
        elseif mode ~= nil and mode == "save" then
            if (#args < 3) then
                ShowNotification("Usage: /race pos save [name]")
                return
            end
            local name = args[3]
            
            -- Send Start Positions to Server
            if name ~= nil and #recordedStartPositions > 0 then
                -- Send event to server to save checkpoints
                TriggerServerEvent('mrp_races:saveStartPos_sv', name, recordedStartPositions)
            end
        else
            -- Generate Start Positions
            generateStartPositions(args)
        end
    elseif args[1] == "save" then
        -- Check name was provided and checkpoints are recorded
        local name = args[2]
        local laps = args[3]
        if laps ~= nil then
            laps = tonumber(laps)
        end
        if name ~= nil and #recordedCheckpoints > 0 then
            -- Send event to server to save checkpoints
            TriggerServerEvent('mrp_races:saveRace_sv', name, recordedCheckpoints, laps)
        end
    elseif args[1] == "delete" then
        -- Check name was provided and send event to server to delete saved race
        local name = args[2]
        if name ~= nil then
            TriggerServerEvent('mrp_races:deleteRace_sv', name)
        end
    elseif args[1] == "list" then
        -- Send event to server to list saved races
        TriggerServerEvent('mrp_races:listRaces_sv')
    elseif args[1] == "load" then
        -- Check name was provided and send event to server to load saved race
        local name = args[2]
        local flags = args[3]
        
        if name ~= nil then
            debugFlag = (flags ~= nil and flags == "debug")
            TriggerServerEvent('mrp_races:loadRace_sv', name)
        end
    elseif args[1] == "start" then
        -- Parse arguments and create race
        local amount = tonumber(args[2])
        if amount then
            -- Get optional start delay argument and starting coordinates
            local startDelay = tonumber(args[3])
            startDelay = startDelay and startDelay*1000 or config_cl.joinDuration
            local startCoords = GetEntityCoords(GetPlayerPed(-1))

            -- Create a race using checkpoints or waypoint if none set
            if #recordedCheckpoints > 0 then
                -- Create race using custom checkpoints
                TriggerServerEvent('mrp_races:createRace_sv', amount, startDelay, startCoords, recordedCheckpoints)
            elseif IsWaypointActive() then
                -- Create race using waypoint as the only checkpoint
                local waypointCoords = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
                local retval, nodeCoords = GetClosestVehicleNode(waypointCoords.x, waypointCoords.y, waypointCoords.z, 1)
                table.insert(recordedCheckpoints, {blip = nil, coords = nodeCoords})
                TriggerServerEvent('mrp_races:createRace_sv', amount, startDelay, startCoords, recordedCheckpoints)
            end

            -- Set state to none to cleanup recording blips while waiting to join
            raceStatus.state = RACE_STATE_NONE
        end
    elseif args[1] == "cancel" then
        -- Send cancel event to server
        TriggerServerEvent('mrp_races:cancelRace_sv')
    end
end)

-- Client event for when a player died
RegisterNetEvent("mrp_races:playerNotification_cl")
AddEventHandler("mrp_races:playerNotification_cl", function(message)
    ShowNotification(message)
end)

-- Client event for when a race is created
RegisterNetEvent("mrp_races:createRace_cl")
AddEventHandler("mrp_races:createRace_cl", function(index, amount, startDelay, startCoords, checkpoints, raceData)
    -- Create race struct and add to array
    local race = {
        amount = amount,
        started = false,
        startTime = GetGameTimer() + startDelay,
        startCoords = startCoords,
        checkpoints = checkpoints,
        originalCheckpoints = checkpoints
    }
    if raceData ~= nil then
        race['data'] = raceData
    end
    races[index] = race
end)

-- Client event for DNF Timer
RegisterNetEvent("mrp_races:createTimerDNF_cl")
AddEventHandler("mrp_races:createTimerDNF_cl", function(finishTimeout)
    -- Update DNF Timer
    raceStatus.dnfTime = GetGameTimer() + finishTimeout
end)

-- Client event for loading a race
RegisterNetEvent("mrp_races:loadRace_cl")
AddEventHandler("mrp_races:loadRace_cl", function(checkpoints)
    -- Load and show all checkpoints
    if debugFlag then
        loadRaceDebug(checkpoints)
        return
    end

    -- Cleanup recording, save checkpoints and set state to recording
    cleanupRecording()
    recordedCheckpoints = checkpoints
    raceStatus.state = RACE_STATE_RECORDING
    
    -- Add map blips
    for index, checkpoint in pairs(recordedCheckpoints) do
        checkpoint.coords.x = checkpoint.coords.x + .0
        checkpoint.coords.y = checkpoint.coords.y + .0
        checkpoint.coords.z = checkpoint.coords.z + .0
        checkpoint.blip = AddBlipForCoord(checkpoint.coords.x, checkpoint.coords.y, checkpoint.coords.z)
        SetBlipColour(checkpoint.blip, config_cl.checkpointBlipColor)
        SetBlipAsShortRange(checkpoint.blip, true)
        ShowNumberOnBlip(checkpoint.blip, index)
    end
    
    -- Clear waypoint and add route for first checkpoint blip
    SetWaypointOff()
    SetBlipRoute(checkpoints[1].blip, true)
    SetBlipRouteColour(checkpoints[1].blip, config_cl.checkpointBlipColor)
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

-- Client event for when a race is joined
RegisterNetEvent("mrp_races:joinedRace_cl")
AddEventHandler("mrp_races:joinedRace_cl", function(index, startPos, firstPos, raceData)
    -- Set index and state to joined
    raceStatus.index = index
    raceStatus.state = RACE_STATE_JOINED
    raceStatus.firstPos = firstPos.coords
    raceStatus.startPos = startPos.coords
    raceStatus.startHeading = startPos.heading
    
    -- Set Race Data
    raceStatus.laps = raceData.laps
    raceStatus.finishMode = raceData.finishMode

    -- Initialize Random Seed
    math.randomseed(GetGameTimer())

    -- Reset Race Status
    raceStatus.totalDistance = 0
    raceStatus.remainingDistance = 0
    raceStatus.finished = false
    raceStatus.finishedCP = 0
    raceStatus.position = 1
    raceStatus.totalPlayers = 1
    
    -- Teleport Player (without Car)
    --SetEntityCoords(PlayerPedId(), startPos.coords.x, startPos.coords.y, startPos.coords.z, 0, 0, 0, false)
    FreezeEntityPosition(PlayerPedId(), true)
    
    -- Add map blips
    local race = races[index]
    local checkpoints = race.checkpoints
    for index, checkpoint in pairs(checkpoints) do
        checkpoint.coords.x = checkpoint.coords.x + .0
        checkpoint.coords.y = checkpoint.coords.y + .0
        checkpoint.coords.z = checkpoint.coords.z + .0
        checkpoint.blip = AddBlipForCoord(checkpoint.coords.x, checkpoint.coords.y, checkpoint.coords.z)
        SetBlipColour(checkpoint.blip, config_cl.checkpointBlipColor)
        SetBlipAsShortRange(checkpoint.blip, true)
        ShowNumberOnBlip(checkpoint.blip, index)
        SetBlipScale(checkpoint.blip, 0.75)
    end

    -- Clear waypoint and add route for first checkpoint blip
    SetWaypointOff()
    SetBlipRoute(checkpoints[1].blip, false)
    SetBlipRouteColour(checkpoints[1].blip, config_cl.checkpointBlipColor)

    -- New Checkpoints
    local totalCheckpoints = {}

    -- Create Checkpoints for Every Lap
    for i=1,raceStatus.laps do
        if raceStatus.laps > 1 then
            for num, checkpoint in pairs(checkpoints) do
                if num ~= 1 then
                    table.insert(totalCheckpoints, checkpoint)
                end
            end
            -- change order the first checkpoint is the finish line
            table.insert(totalCheckpoints, checkpoints[1])
        else
            for num, checkpoint in pairs(checkpoints) do
                table.insert(totalCheckpoints, checkpoint)
            end
        end
    end

    -- Update Checkpoints
    races[index].checkpoints = totalCheckpoints
    races[index].originalCheckpoints = checkpoints

    -- Also Store Number of Checkpoints in Race Status
    raceStatus.checkpointsPerLap = #checkpoints
end)

-- Client event for when a race is removed
RegisterNetEvent("mrp_races:removeRace_cl")
AddEventHandler("mrp_races:removeRace_cl", function(index)
    -- Check if index matches active race
    if index == raceStatus.index then
        -- Cleanup Map Blips and Checkpoints
        cleanupRace()

        -- Reset Racing State
        raceStatus.checkpoint = 0
        raceStatus.state = RACE_STATE_NONE

        -- Show Notification for Player
        ShowNotification("~g~Race Finished!~w~")
    elseif index < raceStatus.index then
        -- Decrement raceStatus.index to match new index after removing race
        raceStatus.index = raceStatus.index - 1
    end
    
    -- Remove race from table
    if races[index] ~= nil then
        table.remove(races, index)
    end
end)

-- Main thread
Citizen.CreateThread(function()
    -- Loop forever and update every frame
    while true do
        Citizen.Wait(0)

        -- Get player and check if they're in a vehicle
        local player = GetPlayerPed(-1)

        -- Get player position and vehicle
        local position = GetEntityCoords(player)

        -- Player is racing
        if raceStatus.state == RACE_STATE_RACING then
            -- Get Current Race from Index
            local race = races[raceStatus.index]
            
            -- Initialize first checkpoint if not set
            if raceStatus.checkpoint == 0 then
                -- Increment to first checkpoint
                raceStatus.checkpoint = 1
                local checkpoint = race.checkpoints[raceStatus.checkpoint]

                -- Create checkpoint when enabled
                if config_cl.checkpointRadius > 0 then
                    local pointer = raceStatus.checkpoint < #race.checkpoints and race.checkpoints[raceStatus.checkpoint + 1].coords or vector3(0, 0, 0)
                    local checkpointType = raceStatus.checkpoint < #race.checkpoints and RACE_CHECKPOINT_TYPE or RACE_CHECKPOINT_FINISH_TYPE
                    checkpoint.checkpoint = CreateCheckpoint(checkpointType, checkpoint.coords.x,  checkpoint.coords.y, checkpoint.coords.z, pointer.x, pointer.y, pointer.z, config_cl.checkpointRadius, 230, 230, 120, 128, 0)
                    SetCheckpointCylinderHeight(checkpoint.checkpoint, config_cl.checkpointHeight, config_cl.checkpointHeight, config_cl.checkpointRadius)
                    SetCheckpointIconRgba(checkpoint.checkpoint, 137, 209, 254, 128)
                end

                -- Set blip route for navigation
                SetBlipRoute(checkpoint.blip, true)
                SetBlipRouteColour(checkpoint.blip, config_cl.checkpointBlipColor)
                SetBlipAsShortRange(checkpoint.blip, false)
                SetBlipScale(checkpoint.blip, 1.0)
                
                -- Set Last Checkpoint Coords to First Starting Position
                raceStatus.lastCheckpointPos = raceStatus.firstPos
            else
                -- Check player distance from current checkpoint
                local checkpoint = race.checkpoints[raceStatus.checkpoint]
                if GetDistanceBetweenCoords(position.x, position.y, position.z, checkpoint.coords.x, checkpoint.coords.y, checkpoint.coords.z, true) < config_cl.checkpointProximity then
                    -- Passed the checkpoint, delete map blip and checkpoint
                    RemoveBlip(checkpoint.blip)
                    if config_cl.checkpointRadius > 0 then
                        DeleteCheckpoint(checkpoint.checkpoint)
                    end
                    
                    -- Give Parachute to Player (only for GFRED)
                    GiveWeaponToPed(PlayerPedId(), GetHashKey("gadget_parachute"), 2, false, false)
                    
                    -- Check Current Checkpoint
                    if raceStatus.checkpoint > 1 then
                        -- Get Previous Checkpoints
                        local checkpointA = race.checkpoints[raceStatus.checkpoint - 1].coords
                        local checkpointB = race.checkpoints[raceStatus.checkpoint].coords
                        
                        -- Calculate Distance of Last Track
                        local distanceLastTrack = GetDistanceBetweenCoords(checkpointA.x, checkpointA.y, checkpointA.z, checkpointB.x, checkpointB.y, checkpointB.z, true)
                        
                        -- Add Distance of Last Track to Total Distance
                        raceStatus.totalDistance = raceStatus.totalDistance + distanceLastTrack
                    elseif raceStatus.checkpoint == 1 then
                        -- Get First Starting Position (Equal for All Players)
                        local checkpointA = raceStatus.firstPos
                        local checkpointB = race.checkpoints[raceStatus.checkpoint].coords
                    
                        -- Calculate Distance of Last Track
                        local distanceLastTrack = GetDistanceBetweenCoords(checkpointA.x, checkpointA.y, checkpointA.z, checkpointB.x, checkpointB.y, checkpointB.z, true)
                    
                        -- Add Distance from Start to First Checkpoint
                        raceStatus.totalDistance = raceStatus.totalDistance + distanceLastTrack
                    end
                    
                    -- Set Last Checkpoint Coords to Current Checkpoint (before Incrementing)
                    raceStatus.lastCheckpointPos = race.checkpoints[raceStatus.checkpoint].coords
                    
                    -- Get Number of Checkpoints per Lap
                    local checkpointsPerLap = #(race.originalCheckpoints)
                    
                    -- Check if at Finish Line
                    if raceStatus.checkpoint == #(race.checkpoints) then
                        -- Play Finish Line Sound
                        PlaySoundFrontend(-1, "Checkpoint_Finish", "DLC_sum20_Open_Wheel_Racing_Sounds")

                        -- Send finish event to server
                        local currentTime = (GetGameTimer() - race.startTime)
                        TriggerServerEvent('mrp_races:finishedRace_sv', raceStatus.index, currentTime, raceStatus.checkpoint + 1, raceStatus.totalDistance)
                        
                        -- Reset state
                        raceStatus.finished = true
                        raceStatus.finishedCP = raceStatus.checkpoint + 1
                        raceStatus.state = RACE_STATE_SPECTATING
                        
                        -- Cleanup Race
                        cleanupRace()
                    else
                        -- Check Finish Line for Multi-Lap and Mid-Round Vehicle Change if Cars Per Lap > 1
                        local vehicleChange = raceStatus.checkpoint % checkpointsPerLap == checkpointsPerLap
                        local multiLapFinishLine = raceStatus.checkpoint % checkpointsPerLap == 0

                        -- Check Finish Line for Multi-Lap (or Vehicle Change)
                        if multiLapFinishLine or vehicleChange then
                            -- Check if DNF Timer is active (then this is the Finish Line for the Current Player)
                            if multiLapFinishLine and raceStatus.finishMode == 2 and raceStatus.dnfTime > GetGameTimer() then
                                -- Play Finish Line Sound
                                PlaySoundFrontend(-1, "Checkpoint_Finish", "DLC_sum20_Open_Wheel_Racing_Sounds")

                                -- Send finish event to server
                                local currentTime = (GetGameTimer() - race.startTime)
                                TriggerServerEvent('mrp_races:finishedRace_sv', raceStatus.index, currentTime, raceStatus.checkpoint + 1, raceStatus.totalDistance)
                                
                                -- Reset state
                                raceStatus.finished = true
                                raceStatus.finishedCP = raceStatus.checkpoint + 1
                                raceStatus.state = RACE_STATE_SPECTATING
                                
                                -- Cleanup Race
                                cleanupRace()
                            else
                                -- Play Checkpoint Sound
                                PlaySoundFrontend(-1, "Out_Of_Area", "DLC_Lowrider_Relay_Race_Sounds")

                                -- Create Checkpoint Blips on Minimap and Map
                                for index, checkpoint in pairs(race.originalCheckpoints) do
                                    checkpoint.blip = AddBlipForCoord(checkpoint.coords.x, checkpoint.coords.y, checkpoint.coords.z - config_cl.checkpointOffset)
                                    SetBlipColour(checkpoint.blip, config_cl.checkpointBlipColor)
                                    SetBlipAsShortRange(checkpoint.blip, true)
                                    ShowNumberOnBlip(checkpoint.blip, index)
                                    SetBlipScale(checkpoint.blip, 0.75)
                                end

                                -- Get Current Player Vehicle
                                local playerVehicle = GetVehiclePedIsIn(player)

                                -- Get Position, Speed and Heading of Current Vehicle
                                local vehiclePos = GetEntityCoords(playerVehicle)
                                local vehicleSpeed = GetEntitySpeed(playerVehicle)
                                local vehicleHeading = GetEntityHeading(playerVehicle)
                            end
                        else
                            -- Play Checkpoint Sound
                            PlaySoundFrontend(-1, "Out_Of_Area", "DLC_Lowrider_Relay_Race_Sounds")
                        end

                        -- Increment checkpoint counter and get next checkpoint
                        raceStatus.checkpoint = raceStatus.checkpoint + 1
                        local nextCheckpoint = race.checkpoints[raceStatus.checkpoint]

                        -- Create checkpoint when enabled
                        if config_cl.checkpointRadius > 0 then
                            -- Check Checkpoint Type for Multi-Lap or Mid-Round Vehicle Change if Cars per Lap > 1
                            local changeCarIcon = raceStatus.checkpoint % checkpointsPerLap == checkpointsPerLap
                            local multiLapIcon = raceStatus.checkpoint % checkpointsPerLap == 0

                            -- Get Pointer to Next Checkpoint and Find Checkpoint Type
                            local pointer = raceStatus.checkpoint < #race.checkpoints and race.checkpoints[raceStatus.checkpoint + 1].coords or vector3(0, 0, 0)
                            local checkpointType = (raceStatus.checkpoint == #race.checkpoints and RACE_CHECKPOINT_FINISH_TYPE) or ((multiLapIcon or changeCarIcon) and RACE_CHECKPOINT_LAP_TYPE) or RACE_CHECKPOINT_TYPE

                            -- Create Checkpoint
                            nextCheckpoint.checkpoint = CreateCheckpoint(checkpointType, nextCheckpoint.coords.x,  nextCheckpoint.coords.y, nextCheckpoint.coords.z, pointer.x, pointer.y, pointer.z, config_cl.checkpointRadius, 230, 230, 120, 128, 0)
                            SetCheckpointCylinderHeight(nextCheckpoint.checkpoint, config_cl.checkpointHeight, config_cl.checkpointHeight, config_cl.checkpointRadius)
                            SetCheckpointIconRgba(nextCheckpoint.checkpoint, 137, 209, 254, 128)
                        end

                        -- Set blip route for navigation
                        SetBlipRoute(nextCheckpoint.blip, true)
                        SetBlipRouteColour(nextCheckpoint.blip, config_cl.checkpointBlipColor)
                        SetBlipAsShortRange(nextCheckpoint.blip, false)
                        SetBlipScale(nextCheckpoint.blip, 1.0)
                    end
                end
            end
            
            -- Calculate Distance to Next Checkpoint (and Distance to Last Checkpoint)
            if raceStatus.checkpoint > 0 and raceStatus.checkpoint <= #(race.checkpoints) then
                local nextCheckpoint = race.checkpoints[raceStatus.checkpoint].coords
                local lastCheckpoint = raceStatus.lastCheckpointPos
                
                -- Calculate Remaining Distance to Next Checkpoint, and Driven Distance since Last Checkpoint
                raceStatus.remainingDistance = GetDistanceBetweenCoords(position.x, position.y, position.z, nextCheckpoint.x, nextCheckpoint.y, nextCheckpoint.z, true)
                raceStatus.checkpointDistance = GetDistanceBetweenCoords(position.x, position.y, position.z, lastCheckpoint.x, lastCheckpoint.y, lastCheckpoint.z, true)
            end
            
            -- Used for Scoreboard
            CalculateFPS()
            
            -- Draw HUD when it's enabled
            if config_cl.hudEnabled then
                -- Shadow Box
                local width = 0.15
                local height = 0.038
                
                -- Shadow Box (Short)
                local widthShort = 0.10
                
                -- Display Clock and Speed
                DisplayClockAndSpeed(player)
                
                -- Draw Position in Current Race
                DrawRect(config_cl.hudPosition.x + (width / 2) - 0.002, config_cl.hudPosition.y + (height / 2), width, height, 20, 20, 20, 160)
                DrawRaceText(config_cl.hudPosition.x, config_cl.hudPosition.y, ("%d/%d"):format(raceStatus.position, raceStatus.totalPlayers), 0.5, 5, true, width - 0.006)
                DrawRaceText(config_cl.hudPosition.x, config_cl.hudPosition.y + 0.008, "POSITION", 0.3, 0, false)
                
                -- Draw Current Race Time
                local timeSeconds = (GetGameTimer() - race.startTime)/1000.0
                local timeMinutes = math.floor(timeSeconds/60.0)
                timeSeconds = timeSeconds - 60.0*timeMinutes
                
                DrawRect(config_cl.hudPosition.x + (width / 2) - 0.002, config_cl.hudPosition.y + 0.042 + (height / 2), width, height, 20, 20, 20, 160)
                DrawRaceText(config_cl.hudPosition.x, config_cl.hudPosition.y + 0.042, ("%02d:%05.2f"):format(timeMinutes, timeSeconds), 0.5, 5, true, width - 0.006)
                DrawRaceText(config_cl.hudPosition.x, config_cl.hudPosition.y + 0.050, "TIME", 0.3, 0, false)
                
                -- Draw Lap/Checkpoint Progress
                local checkpoint = race.checkpoints[raceStatus.checkpoint]
                local checkpointDist = math.floor(GetDistanceBetweenCoords(position.x, position.y, position.z, checkpoint.coords.x, checkpoint.coords.y, checkpoint.coords.z, true))
                
                DrawRect(config_cl.hudPosition.x - 0.11 + (widthShort / 2) - 0.002, config_cl.hudPosition.y + 0.042 + (height / 2), widthShort, height, 20, 20, 20, 160)
                DrawRaceText(config_cl.hudPosition.x - 0.11, config_cl.hudPosition.y + 0.042, ("%d/%d"):format(math.floor((raceStatus.checkpoint - 1) / #race.originalCheckpoints) + 1, raceStatus.laps), 0.5, 5, true, widthShort - 0.006)
                DrawRaceText(config_cl.hudPosition.x - 0.11, config_cl.hudPosition.y + 0.050, "LAP", 0.3, 0, false)
                
                -- Draw DNF Timer
                if (raceStatus.dnfTime > GetGameTimer()) then
                    local timeSeconds = (raceStatus.dnfTime - GetGameTimer())/1000.0
                    local timeMinutes = math.floor(timeSeconds/60.0)
                    timeSeconds = timeSeconds - 60.0*timeMinutes
                    
                    local hudPositionX = 0.45
                    
                    DrawRect(hudPositionX + (width / 2) - 0.002, config_cl.hudPosition.y + 0.042 + (height / 2), width, height, 20, 20, 20, 160)
                    DrawRaceText(hudPositionX, config_cl.hudPosition.y + 0.042, ("%02d:%05.2f"):format(timeMinutes, timeSeconds), 0.5, 5, true, width - 0.006)
                    DrawRaceText(hudPositionX, config_cl.hudPosition.y + 0.050, "DNF TIMER", 0.3, 0, false)
                end
                
                -- Hide HUD Component of Street Name
                HideHudComponentThisFrame(STREET_NAME)
            end
        -- Player has joined a race
        elseif raceStatus.state == RACE_STATE_JOINED then
            -- Check countdown to race start
            local race = races[raceStatus.index]
            local currentTime = GetGameTimer()
            local count = race.startTime - currentTime
            local vehicle = GetVehiclePedIsIn(player, false)
            
            if count <= 0 then
                -- Race started, set racing state and unfreeze vehicle position
                raceStatus.state = RACE_STATE_RACING
                raceStatus.checkpoint = 0
                FreezeEntityPosition(vehicle, false)
            elseif count <= config_cl.freezeDuration then
                -- Display countdown text and freeze vehicle position
                Draw2DText(0.5, 0.4, ("~y~%d"):format(math.ceil(count/1000.0)), 3.0, 4)
                
                if vehicle ~= 0 then
                    -- Freeze Vehicle (For Countdown)
                    FreezeEntityPosition(vehicle, true)
                    FreezeEntityPosition(PlayerPedId(), false)
                else
                    -- Unfreeze Player
                    FreezeEntityPosition(PlayerPedId(), false)
                    
                    -- Freeze Vehicle
                    FreezeEntityPosition(vehicle, true)
                end
            else
                -- Draw 3D start time and join text
                local temp, zCoord = GetGroundZFor_3dCoord(race.startCoords.x, race.startCoords.y, 9999.9, 1)
                
                -- Display countdown text
                Draw2DText(0.4, 0.4, ("Race for ~g~$%d~w~ starting in ~y~%d~w~s"):format(race.amount, math.ceil(count/1000.0)), 0.8, 4)
            end
        elseif raceStatus.state == RACE_STATE_SPECTATING then
            -- Draw DNF Timer
            if (raceStatus.dnfTime > GetGameTimer()) then
                -- Shadow Box
                local width = 0.15
                local height = 0.038
                
                -- Calculate DNF Time
                local timeSeconds = (raceStatus.dnfTime - GetGameTimer())/1000.0
                local timeMinutes = math.floor(timeSeconds/60.0)
                timeSeconds = timeSeconds - 60.0*timeMinutes
                
                local hudPositionX = 0.45
                
                DrawRect(hudPositionX + (width / 2) - 0.002, config_cl.hudPosition.y + 0.042 + (height / 2), width, height, 20, 20, 20, 160)
                DrawRaceText(hudPositionX, config_cl.hudPosition.y + 0.042, ("%02d:%05.2f"):format(timeMinutes, timeSeconds), 0.5, 5, true, width - 0.006)
                DrawRaceText(hudPositionX, config_cl.hudPosition.y + 0.050, "DNF TIMER", 0.3, 0, false)
            end
        -- Player is not in a race
        else
            -- Loop through all races
            for index, race in pairs(races) do
                -- Get current time and player proximity to start
                local currentTime = GetGameTimer()
                -- local proximity = GetDistanceBetweenCoords(position.x, position.y, position.z, race.startCoords.x, race.startCoords.y, race.startCoords.z, true)

                -- When in proximity and race hasn't started draw 3D text and prompt to join
                if currentTime < race.startTime then -- and proximity < config_cl.joinProximity
                    -- Draw 3D text
                    local count = math.ceil((race.startTime - currentTime)/1000.0)
                    local temp, zCoord = GetGroundZFor_3dCoord(race.startCoords.x, race.startCoords.y, 9999.9, 0)

                    -- Display Text for Joining Race
                    Draw2DText(0.4, 0.4, ("Race for ~g~$%d~w~ starting in ~y~%d~w~s"):format(race.amount, count), 0.8, 4)
                    Draw2DText(0.4, 0.4 + 0.05, "Press [~g~E~w~] to join", 0.8, 4)

                    -- Check if player enters the race and send join event to server
                    if IsControlJustReleased(1, config_cl.joinKeybind) then
                        TriggerServerEvent('mrp_races:joinRace_sv', index)
                        break
                    end
                end
            end
        end
    end
end)

function CalculateFPS()
    -- Get Current Time and Frame Count
    fps.curTime = GetGameTimer()
    fps.curFrames = GetFrameCount()

    -- Calculate Frames per Second
    if (fps.curTime - fps.prevTime) > 1000 then
        fps.value = (fps.curFrames - fps.prevFrames) - 1
        fps.prevTime = fps.curTime
        fps.prevFrames = fps.curFrames
    end
end

-- Minimap Anchor by glitchdetector (Feb 16 2018 version)
function GetMinimapAnchor()
    -- Safezone goes from 1.0 (no gap) to 0.9 (5% gap (1/20))
    -- 0.05 * ((safezone - 0.9) * 10)
    local safezone = GetSafeZoneSize()
    local safezone_x = 1.0 / 20.0
    local safezone_y = 1.0 / 20.0
    local aspect_ratio = GetAspectRatio(0)
    local res_x, res_y = GetActiveScreenResolution()
    local xscale = 1.0 / res_x
    local yscale = 1.0 / res_y
    local Minimap = {}
    Minimap.width = xscale * (res_x / (4 * aspect_ratio))
    Minimap.height = yscale * (res_y / 5.674)
    Minimap.left_x = xscale * (res_x * (safezone_x * ((math.abs(safezone - 1.0)) * 10)))
    Minimap.bottom_y = 1.0 - yscale * (res_y * (safezone_y * ((math.abs(safezone - 1.0)) * 10)))
    Minimap.right_x = Minimap.left_x + Minimap.width
    Minimap.top_y = Minimap.bottom_y - Minimap.height
    Minimap.x = Minimap.left_x
    Minimap.y = Minimap.top_y
    Minimap.xunit = xscale
    Minimap.yunit = yscale
    return Minimap
end

-- Get Minimap Anchor
local minimap = GetMinimapAnchor();

-- Display Clock and Speed around Minimap
function DisplayClockAndSpeed(player)
    -- Default Positions for Speed and Time
    local speedPos = vec(minimap.right_x - 0.042, 0.900)
    local clockPos = vec(0.015, 0.768)

    -- Check for Big Map
    if radarBigmapEnabled then
        -- Update Position of Speed Text
        speedPos = vec(speedPos.x + 0.082, speedPos.y)
    else
        -- Update Clock Text
        local hour = GetClockHours()
        local minute = GetClockMinutes()

        -- Display Local Time when in Active Race
        DrawHudText(("%.2d:%.2d"):format(hour, minute), 4, clockColorText, 0.4, clockPos.x, clockPos.y)
    end

    -- Get Current Player Vehicle
    local vehicle = GetVehiclePedIsIn(player, false)

    -- Check Vehicle
    if vehicle ~= 0 then
        -- Get Current Vehicle Speed
        local vehicleSpeed = GetEntitySpeed(vehicle)
        
        -- Check what units should be used for speed
        if ShouldUseMetricMeasurements() then
            -- Get vehicle speed in KPH and draw speedometer
            local speed = vehicleSpeed*3.6

            DrawHudText(("%3s"):format(tostring(math.ceil(speed))), 2, speedColorText, 0.6, speedPos.x + 0.000, speedPos.y + 0.030)
            DrawHudText("KPH", 2, speedColorText, 0.4, speedPos.x + 0.025, speedPos.y + 0.04)
        else
            -- Get vehicle speed in MPH and draw speedometer
            local speed = vehicleSpeed*2.23694

            DrawHudText(("%3s"):format(tostring(math.ceil(speed))), 2, speedColorText, 0.6, speedPos.x + 0.000, speedPos.y + 0.030)
            DrawHudText("MPH", 2, speedColorText, 0.4, speedPos.x + 0.025, speedPos.y + 0.04)
        end
    end
end

-- Checkpoint recording thread
Citizen.CreateThread(function()
    -- Loop forever and record checkpoints every 100ms
    local lastControl = false
    while true do
        Citizen.Wait(0)
        
        -- When recording flag is set, save checkpoints
        if raceStatus.state == RACE_STATE_RECORDING then
            displayHelpText("Recording race track press ~INPUT_PICKUP~ to set checkpoints or use map waypoints~b~")
            
            -- Create new checkpoint when waypoint is set
            local currentReleased = IsControlReleased(1, 38);
            
            local justReleased = (currentReleased == false and lastControl == 1)
            
            if IsWaypointActive() or justReleased then -- also can add waypoints with E
                -- Get closest vehicle node to waypoint coordinates and remove waypoint
                local waypointCoords = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
                if justReleased then
                    waypointCoords = GetEntityCoords(PlayerPedId())
                end
                local retval, coords = GetClosestVehicleNode(waypointCoords.x, waypointCoords.y, waypointCoords.z, 1)
                SetWaypointOff()

                -- Check if coordinates match any existing checkpoints
                for index, checkpoint in pairs(recordedCheckpoints) do
                    if GetDistanceBetweenCoords(coords.x, coords.y, coords.z, checkpoint.coords.x, checkpoint.coords.y, checkpoint.coords.z, false) < 1.0 then
                        -- Delete Checkpoint
                        DeleteCheckpoint(checkpoint.id)

                        -- Matches existing checkpoint, remove blip and checkpoint from table
                        RemoveBlip(checkpoint.blip)
                        table.remove(recordedCheckpoints, index)
                        coords = nil

                        -- Update existing checkpoint blips
                        for i = index, #recordedCheckpoints do
                            ShowNumberOnBlip(recordedCheckpoints[i].blip, i)
                        end
                        break
                    end
                end

                -- Add new checkpoint
                if (coords ~= nil) then
                    -- Create Checkpoint (for Visualization)
                    local checkpointId = CreateCheckpoint(RACE_CHECKPOINT_TYPE,coords.x, coords.y, coords.z, 0, 0, 0, config_cl.checkpointRadius, 230, 230, 120, 128, 0)
                    SetCheckpointCylinderHeight(checkpointId, config_cl.checkpointHeight, config_cl.checkpointHeight, config_cl.checkpointRadius)

                    -- Add numbered checkpoint blip
                    local blip = AddBlipForCoord(coords.x, coords.y, coords.z - config_cl.checkpointOffset)
                    SetBlipColour(blip, config_cl.checkpointBlipColor)
                    SetBlipAsShortRange(blip, true)
                    ShowNumberOnBlip(blip, #recordedCheckpoints+1)

                    -- Add checkpoint to array
                    table.insert(recordedCheckpoints, {blip = blip, coords = coords, id = checkpointId})
                end
            end
            
            lastControl = currentReleased
        else
            -- Not recording, do cleanup
            cleanupRecording()
        end
    end
end)

-- Helper function to clean up race blips, checkpoints and status
function cleanupRace()
    -- Cleanup active race
    if raceStatus.index ~= 0 then
        -- Cleanup map blips and checkpoints
        local race = races[raceStatus.index]
        local checkpoints = race.checkpoints
        
        -- Cleanup map blips and checkpoints
        for _, checkpoint in pairs(checkpoints) do
            if checkpoint.blip then
                RemoveBlip(checkpoint.blip)
            end
            if checkpoint.checkpoint then
                DeleteCheckpoint(checkpoint.checkpoint)
            end
        end

        -- Set new waypoint to finish if racing
        if raceStatus.state == RACE_STATE_RACING then
            local lastCheckpoint = checkpoints[#checkpoints]
            SetNewWaypoint(lastCheckpoint.coords.x, lastCheckpoint.coords.y)
        end

        -- Unfreeze vehicle
        local vehicle = GetVehiclePedIsIn(GetPlayerPed(-1), false)
        FreezeEntityPosition(vehicle, false)
    end

    -- Reset Position of HUD Components
    for componentId, _ in pairs(hudComponents) do
        ResetHudComponentValues(componentId)
    end
end

-- Helper function to clean up recording blips
function cleanupRecording()
    -- Remove map blips and clear recorded checkpoints
    for _, checkpoint in pairs(recordedCheckpoints) do
        RemoveBlip(checkpoint.blip)
        DeleteCheckpoint(checkpoint.id)
        checkpoint.blip = nil
    end
    recordedCheckpoints = {}
end

-- Draw 3D text at coordinates
function Draw3DText(x, y, z, text)
    -- Check if coords are visible and get 2D screen coords
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        -- Calculate text scale to use
        local dist = GetDistanceBetweenCoords(GetGameplayCamCoords(), x, y, z, 1)
        local scale = 1.8*(1/dist)*(1/GetGameplayCamFov())*100

        -- Draw text on screen
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextDropShadow(0, 0, 0, 0,255)
        SetTextDropShadow()
        SetTextEdge(4, 0, 0, 0, 255)
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- Draw 2D text on screen
function Draw2DText(x, y, text, scale, font)
    -- Draw text on screen
    SetTextFont(font)
    SetTextProportional(7)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextEdge(4, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Draw 2D text on screen
function DrawRaceText(x, y, text, scale, font, rightJustify, width)
    -- Draw text on screen
    SetTextFont(font)
    SetTextProportional(7)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextEdge(4, 0, 0, 0, 255)
    if rightJustify then
        SetTextRightJustify(true)
        SetTextWrap(x, x + width)
    end
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Helper function to draw text to screen
function DrawHudText(text, font, colour, scale, x, y)
    SetTextFont(font)
    SetTextScale(scale, scale)
    SetTextColour(colour[1], colour[2], colour[3], 255)
    SetTextEntry("STRING")
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextEdge(4, 0, 0, 0, 255)
    SetTextOutline()
    AddTextComponentString(text)
    DrawText(x, y)
end

function generateStartPositions(args)
    -- Check Args
    if (#args < 3) then
        ShowNotification("Usage: /race pos [rows] [cols]")
        return
    end
    
    -- Parse Args
    local rows = tonumber(args[2]) - 1
    local cols = tonumber(args[3]) - 1
    
    -- Create Fake Race (for Cleanup)
    local race = {
        amount = 10,
        started = false,
        startTime = GetGameTimer(),
        startCoords = vector3(0, 0, 0),
        checkpoints = {}
    }
    
    -- Create Fake Race Status (for Cleanup)
    raceStatus.index = 1
    raceStatus.state = RACE_STATE_RECORDING
    raceStatus.checkpoint = 0
    recordedStartPositions = {}
    
    -- Generate Starting Positions (Rows and Cols)
    for row=0,rows do
        for col=0,cols do
            -- Get Next Starting Position based on Player Position
            local x,y,z = table.unpack(GetOffsetFromEntityInWorldCoords(PlayerPedId(), col * config_cl.colSpacing, row * -config_cl.rowSpacing, -0.5))
        
            -- Increment checkpoint counter and get next checkpoint
            raceStatus.checkpoint = raceStatus.checkpoint + 1
            local nextCheckpoint = { blip = nil, checkpoint = nil } 
            
            local checkpointRadius = 1.0
            local checkpointHeight = 2.0
            
            -- Create checkpoint when enabled
            local checkpointType = STARTPOS_CHECKPOINT_TYPE
            nextCheckpoint.checkpoint = CreateCheckpoint(checkpointType, x, y, z, 0, 0, 0, checkpointRadius, 255, 255, 0, 127, 0)
            SetCheckpointCylinderHeight(nextCheckpoint.checkpoint, checkpointHeight, checkpointHeight, checkpointRadius)
            
            race.checkpoints[raceStatus.checkpoint] = nextCheckpoint
            table.insert(recordedStartPositions, { coords = vector3(x, y, z), heading = GetEntityHeading(PlayerPedId()) })
        end
    end
    
    -- Assign Fake Race (for Cleanup)
    races[raceStatus.index] = race
end

function loadRaceDebug(checkpoints)
    -- Cleanup recording, save checkpoints and set state to recording
    cleanupRecording()
    recordedCheckpoints = checkpoints
    raceStatus.state = RACE_STATE_RECORDING
    
    -- Create Fake Race (for Cleanup)
    local race = {
        amount = 10,
        started = false,
        startTime = GetGameTimer(),
        startCoords = vector3(0, 0, 0),
        checkpoints = {}
    }
    
    -- Create Fake Race Status (for Cleanup)
    raceStatus.index = 1
    raceStatus.state = RACE_STATE_RECORDING
    raceStatus.checkpoint = 0

    -- Add map blips
    for index, checkpoint in pairs(recordedCheckpoints) do
        checkpoint.blip = AddBlipForCoord(checkpoint.coords.x, checkpoint.coords.y, checkpoint.coords.z - config_cl.checkpointOffset)
        SetBlipColour(checkpoint.blip, config_cl.checkpointBlipColor)
        SetBlipAsShortRange(checkpoint.blip, false)
        ShowNumberOnBlip(checkpoint.blip, index)
        
        -- Increment checkpoint counter and get next checkpoint
        local nextCheckpoint = { blip = checkpoint.blip, checkpoint = nil }

        -- Create checkpoint when enabled
        if config_cl.checkpointRadius > 0 then
            local pointer = index < #recordedCheckpoints and recordedCheckpoints[index + 1].coords or vector3(0, 0, 0)
            local checkpointType = index < #recordedCheckpoints and RACE_CHECKPOINT_TYPE or RACE_CHECKPOINT_FINISH_TYPE
            nextCheckpoint.checkpoint = CreateCheckpoint(checkpointType, checkpoint.coords.x,  checkpoint.coords.y, checkpoint.coords.z, pointer.x, pointer.y, pointer.z, config_cl.checkpointRadius, 230, 230, 120, 128, 0)
            SetCheckpointCylinderHeight(nextCheckpoint.checkpoint, config_cl.checkpointHeight, config_cl.checkpointHeight, config_cl.checkpointRadius)
            SetCheckpointIconRgba(nextCheckpoint.checkpoint, 137, 209, 254, 128)
        end
        
        -- Add Checkpoint to Fake Race (for Cleanup)
        race.checkpoints[index] = nextCheckpoint
    end

    -- Assign Fake Race (for Cleanup)
    races[raceStatus.index] = race
    
    -- Clear Waypoint
    SetWaypointOff()
end

-- Helper Function to Sanitize HTML
function sanitizeHTML(txt)
    local replacements = {
        ['&' ] = '&amp;',
        ['<' ] = '&lt;',
        ['>' ] = '&gt;',
        ['\n'] = '<br/>'
    }
    return txt
        :gsub('[&<>\n]', replacements)
        :gsub(' +', function(s) return ' '..('&nbsp;'):rep(#s-1) end)
end

-- Send Scoreboard Updates every Second
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        -- Check Race Status
        if raceStatus.state == RACE_STATE_RACING or raceStatus.state == RACE_STATE_SPECTATING then
            -- Player FPS, Checkpoints, TotalDistance, RemainingDistance, VehicleName
            -- Player Id, Player Name, Player Ping

            -- Get player and check if they're in a vehicle
            local playerPed = GetPlayerPed(-1)
            local playerVehicle = GetVehiclePedIsIn(playerPed, false)
            local playerVehicleName = "NULL"
            
            -- Check Vehicle
            if playerVehicle ~= 0 then
                playerVehicleName = GetDisplayNameFromVehicleModel(GetEntityModel(playerVehicle))
            end
            
            -- Create Scoreboard Entry for Player
            local entry = {
                checkpoint = raceStatus.checkpoint,
                totalDistance = raceStatus.totalDistance + raceStatus.checkpointDistance,
                remainingDistance = raceStatus.remainingDistance,
                vehicleName = playerVehicleName,
                playerFPS =  fps.value,
                finished = raceStatus.finished
            }
            
            -- Send Scoreboard Entry to Server
            TriggerServerEvent('mrp_races:scoreboardUpdate_sv', raceStatus.index, entry)
        end
    end
end)

-- Client event for scoreboard updates
RegisterNetEvent("mrp_races:scoreboardUpdate_cl")
AddEventHandler("mrp_races:scoreboardUpdate_cl", function(serverScoreboard, serverLeaderboard)
    -- Update Local Leaderboard
    leaderboard = serverLeaderboard
    
    -- Update Local Scoreboard (per Player)
    for key, value in pairs(serverScoreboard) do
        scoreboard[key] = serverScoreboard[key]
    end
    
    -- Get Server Id of Player
    local playerServerId = GetPlayerServerId(PlayerId())
    
    -- Check Positions of All Players
    for pos, playerId in pairs(leaderboard) do
        -- Check Position of Player
        if playerId == playerServerId then
            raceStatus.position = pos
        end
    end
    
    -- Update Total Number of Players
    raceStatus.totalPlayers = #leaderboard
end)

-- Helper Function to Clone Tables
function table.clone(org)
  return { table.unpack(org) }
end

-- Player FPS, Checkpoints, TotalDistance, RemainingDistance, VehicleName
-- Player Id, Player Name, Player Ping
function showScoreboard()
    -- HTML Data
    local htmlText = {}

    -- Make a Copy of Leaderboard
    local positions = table.clone(leaderboard)
    local playerServerId = GetPlayerServerId(PlayerId())
    
    -- Get Current Player Score from Server
    local playerScore = scoreboard[playerServerId];
    local playerPosition = raceStatus.position;
    
    -- Get Player Positions (Sorted by Server)
    for pos, playerId in pairs(positions) do
        -- Get Player Score from Scoreboard
        local score = scoreboard[playerId];
        
        -- Format Vehicle Name and Checkpoint Text
        local vehicleName = score.vehicleName ~= "NULL" and GetLabelText(score.vehicleName) or "-"
        local checkpointText = score.checkpoint > 1 and tostring(score.checkpoint - 1) or "-"
        local playerLap = math.floor((score.checkpoint - 1) / raceStatus.checkpointsPerLap) + 1
        
        -- Distance to Next / Previous Player
        local distance = 0

        -- Check Player Position and Checkpoint
        if score.checkpoint == playerScore.checkpoint then
            -- Equal Checkpoints for Both Players (use Remaining Distance to Next Checkpoint)
            distance = math.abs(score.remainingDistance - playerScore.remainingDistance)
        else
            -- These Players are not a the same Checkpoint (use Total Distance)
            distance = math.abs(score.totalDistance - playerScore.totalDistance)
        end

        -- Calculate Time Difference (based on Average Vehicle Speed)
        local timeSeconds = distance / config_cl.avgVehicleSpeed
        local timeMinutes = math.floor(timeSeconds/60.0)
        timeSeconds = timeSeconds - 60.0*timeMinutes

        -- Format Time Difference (Format "--:--.---")
        local signPosition = pos < playerPosition and "-" or "+"
        local timeDifference = ("%s%02d:%06.3f"):format(signPosition, timeMinutes, timeSeconds)

        -- Set CSS Class (Current Player, DNF, etc.)
        local class = "normal"
        
        -- Check for Current Player
        if playerId == playerServerId then
            -- Highlight Current Player
            class = class .. " player"
            
            -- Hide Time Difference for Current Player
            timeDifference = ""
        end
        
        -- Check for Finished Players
        if score.finished then
            -- Highlight Finished Players
            class = class .. " finished"
            
            -- Use Finish Time instead of Time Difference
            timeDifference = score.finishTime
        end
        
        -- Add Player Score to HTML Table
        table.insert(htmlText, ("<tr class='%s'><td>%d</td><td>%s</td><td>%s</td><td>%s</td><td>%d</td><td>%s</td><td>%d</td><td>%d</td></tr>"):format(
            class, pos, sanitizeHTML(score.playerName), vehicleName, timeDifference, playerLap, checkpointText, score.playerPing, score.playerFPS
        ));
    end

    -- Send HTML Table to NUI Overlay Browser
    SendNUIMessage({ text = table.concat(htmlText), race = "Point to Point" })
end

function hideScoreboard()
    SendNUIMessage({ meta = 'close' })
end

-- Big Map (Double Press DPAD_DOWN)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Check DPAD_DOWN Pressed
        if (IsControlJustReleased(0, 20)) then
            local pressedAgain = false
            local timer = GetGameTimer()

            while true do
                Citizen.Wait(0)
                if (IsControlJustPressed(0, 20)) then
                    pressedAgain = true
                    break
                end
                if (GetGameTimer() - timer >= 200) then
                    break
                end
            end

            -- Check Double Press
            if pressedAgain then
                -- Enable Big Radar Map and Trigger Event
                SetRadarBigmapEnabled(true, false)
                radarBigmapEnabled = true

                -- Display Time
                Citizen.Wait(4350)

                -- Disable Big Radar Map and Trigger Event
                SetRadarBigmapEnabled(false, false)
                radarBigmapEnabled = false
            end
        end
    end
end)

-- Show Scoreboard (Single Press DPAD_DOWN)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Check DPAD_DOWN Pressed and Race Status is RACING or SPECTATING
        if (IsControlJustReleased(0, 20)) and (raceStatus.state == RACE_STATE_RACING or raceStatus.state == RACE_STATE_SPECTATING) then
            local pressedAgain = false
            local timer = GetGameTimer()

            -- Show Scoreboard after Button Press
            showScoreboard()

            while true do
                Citizen.Wait(0)
                if (IsControlJustPressed(0, 20)) then
                    pressedAgain = true
                    break
                end
                if (GetGameTimer() - timer >= 200) then
                    break
                end
            end

            -- Check Double Press
            if pressedAgain then
                -- Hide Scoreboard Again (for Big Map)
                Citizen.Wait(200)
            else
                -- Show Scoreboard for Longer Period
                Citizen.Wait(3000)
            end

            -- Hide Scoreboard after Timeout
            hideScoreboard()
        end
    end
end)

-- Check Respawn Button (Hold Down DPAD_UP)
CreateThread(function()
    local pressed = false
    
    while true do
        Citizen.Wait(0)

        -- Check Active Racing State
        if raceStatus.state == RACE_STATE_RACING then
            -- Create a timer variable
            local timer = 0
        
            -- Loop as long as the control is held down.
            while IsControlPressed(0, 27) do
                Citizen.Wait(20)
                
                -- Add 1 to the timer
                timer = timer + 1
                
                -- If the timer is 50 or more
                if timer > 50 and pressed == false then
                    pressed = true -- Update Button State

                    -- Get Checkpoint Index and Current Race
                    local checkpointIndex = raceStatus.checkpoint - 1
                    local race = races[raceStatus.index]

                    -- Check Checkpoint or Starting Position
                    if checkpointIndex > 0 then
                        local coords = race.checkpoints[checkpointIndex].coords
                        local next = checkpointIndex < #(race.checkpoints) and race.checkpoints[checkpointIndex + 1].coords or race.checkpoints[checkpointIndex].coords
                    else
                    end
                    
                    -- Show Notification for Player
                    ShowNotification("Respawned")
                end
            end
            -- Reset the pressed variable
            pressed = false
        else
            -- Race Idle Sleep
            Citizen.Wait(4 * 1000)
        end
    end
end)

-- Call Plugin Initialization
Initialize()
