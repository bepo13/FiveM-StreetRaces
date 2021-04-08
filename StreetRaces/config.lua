-- CLIENT CONFIGURATION
config_cl = {
    joinProximity = 25,                 -- Proximity to draw 3D text and join race
    joinKeybind = 51,                   -- Keybind to join race ("E" by default)
    joinDuration = 30000,               -- Duration in ms to allow players to join the race
    freezeDuration = 5000,              -- Duration in ms to freeze players and countdown start (set to 0 to disable)
    checkpointProximity = 25.0,         -- Proximity to trigger checkpoint in meters
    checkpointRadius = 25.0,            -- Radius of 3D checkpoints in meters (set to 0 to disable cylinder checkpoints)
    checkpointHeight = 10.0,            -- Height of 3D checkpoints in meters
    checkpointBlipColor = 5,            -- Color of checkpoint map blips and navigation (see SetBlipColour native reference)
    hudEnabled = true,                  -- Enable racing HUD with time and checkpoints
    hudPosition = vec(0.015, 0.725),    -- Screen position to draw racing HUD

    showBlips = true,                   -- Draw blips on the map for custom races
    blipColor = 3,                      -- Map blip color
    blipsUpdateTime = 30000,            -- How often should the client update the blips on the map in milliseconds (dont set it to 0 or a small number, blips will blink or wont even show up)
    uniqueBlipNames = false,            -- True = blip's name will be the name of the race, False = every blip will be called Custom Race and will be grouped together
    quickStartMarkers = true,           -- Spawn quickstart markers on the game world. Press ~INPUT_DETONATE~ (G) to start the race lobby
    quickStartMarkerColorRed = 0,       -- Quickstart marker color red value
    quickStartMarkerColorGreen = 128,   -- Quickstart marker color green value
    quickStartMarkerColorBlue = 255,    -- Quickstart marker color blue value
    quickStartMoney = 0,                -- Quickstart wager 
    quickStartReadyUpTime = 20          -- Quickstart race wait time in seconds
}

-- SERVER CONFIGURATION
config_sv = {
    finishTimeout = 180000,             -- Timeout in ms for removing a race after winner finishes
    notifyOfWinner = true               -- Notify all players of the winner (false will only notify the winner)
}
