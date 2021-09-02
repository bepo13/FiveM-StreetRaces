-- CLIENT CONFIGURATION
config_cl = {
    colSpacing = 4.0,                   -- Column Spacing for Start Positions
    rowSpacing = 8.0,                   -- Row Spacing for Start Positions
    avgVehicleSpeed = 30.0,             -- Average Vehicle Speed (used for Time Difference in Scoreboard) Default: 30 m/s
    joinProximity = 25,                 -- Proximity to draw 3D text and join race
    joinKeybind = 51,                   -- Keybind to join race ("E" by default)
    joinDuration = 30000,               -- Duration in ms to allow players to join the race
    freezeDuration = 10000,             -- Duration in ms to freeze players and countdown start (set to 0 to disable)
    checkpointProximity = 16.0,         -- Proximity to trigger checkpoint in meters
    checkpointRadius = 10.0,            -- Radius of 3D checkpoints in meters (set to 0 to disable cylinder checkpoints)
    checkpointHeight =  8.0,            -- Height of 3D checkpoints in meters
    checkpointBlipColor = 5,            -- Color of checkpoint map blips and navigation (see SetBlipColour native reference)
    checkpointOffset = 6.0,             -- Offset for Checkpoint Height
    hudEnabled = true,                  -- Enable racing HUD with time and checkpoints
    hudPosition = vec(0.84, 0.900),     -- Screen position to draw racing HUD
    vehicle = 'club'                    -- Default Vehicle for Spawn e.g 'cruiser' for GFRED, Config Not Used anymore
}

-- SERVER CONFIGURATION
config_sv = {
    finishTimeout = 90000,              -- Timeout in ms for removing a race after winner finishes
    notifyOfWinner = true               -- Notify all players of the winner (false will only notify the winner)
}

-- CAR CLASSES for RANDOM RACES
config_cars = {
    commercials = {
        "benson","biff","cerberus","cerberus2","hauler","hauler2","mule","packer","phantom","pounder2","stockade","stockade3","terbyte"
    },
    compacts = {
        "asbo","blista","brioso","brioso2","club","dilettante","dilettante2","issi2","issi3","issi5","kanjo","panto","prairie","rhapsody","weevil"
    },
    coupes = {
        "cogcabrio","exemplar","f620","felon","felon2","jackal","oracle","oracle2","sentinel","sentinel2","windsor","windsor2","zion","zion2"
    },
    emergency = {
        "ambulance","fbi","fbi2","firetruk","lguard","pbus","police","police2","police3","police4","policeold1","policeold2","policet","pranger","riot","riot2","sheriff","sheriff2"
    },
    industrial = {
        "flatbed","guardian","mixer","mixer2","rubble","tiptruck","tiptruck2"
    },
    military = {
        "apc","barracks2","barrage","chernobog","crusader","halftrack","khanjali","minitank","scarab2"
    },
    motorcycles = {
        "akuma","avarus","bagger","bati","bati2","bf400","carbonrs","chimera","cliffhanger","daemon","daemon2","deathbike","deathbike2","deathbike3","defiler","diablous","diablous2",
        "double","enduro","esskey","faggio","faggio2","faggio3","fcr","fcr2","gargoyle","hakuchou","hakuchou2","hexer","innovation","lectro","manchez","manchez2",
        "nemesis","nightblade","oppressor","oppressor2","pcj","ratbike","rrocket","ruffian","sanchez","sanchez2","sanctus","shotaro","sovereign","stryder",
        "thrust","vader","vindicator","vortex","wolfsbane","zombiea","zombieb"
    },
    muscle = {
        "blade","buccaneer","buccaneer2","chino","chino2","clique","coquette3","deviant","dominator","dominator2","dominator3",
        "dukes","dukes2","dukes3","ellie","faction","faction2","faction3","gauntlet","gauntlet2","gauntlet3","hermes","hotknife","hustler",
        "impaler","impaler2","imperator","imperator2","moonbeam","moonbeam2","nightshade","peyote2","phoenix","picador",
        "ratloader2","ruiner","ruiner2","sabregt","sabregt2","slamvan","slamvan3","slamvan4","stalion","stalion2",
        "tampa","tampa3","tulip","vamos","vigero","virgo","virgo3","voodoo","yosemite","yosemite2","yosemite3"
    },
    offroad = {
        "bfinjection","bifta","blazer","blazer2","blazer3","blazer4","blazer5","bodhi2","brawler","bruiser","bruiser2","brutus","brutus2",
        "caracara","caracara2","dloader","dubsta3","dune","dune2","dune3","dune5","everon","freecrawler","hellion","insurgent","insurgent2","insurgent3",
        "kalahari","kamacho","marshall","menacer","mesa3","monster","monster3","monster4","nightshark","outlaw","rancherxl","rancherxl2","rcbandito",
        "rebel2","riata","sandking","sandking2","technical","technical2","technical3","trophytruck","trophytruck2","vagrant","verus","winky","zhaba"
    },
    openwheel = {
        "formula","formula2","openwheel1","openwheel2"
    },
    suv = {
        "baller2","baller6","bjxl","cavalcade","cavalcade2","contender","dubsta","dubsta2","fq2","granger","gresley","habanero",
        "huntley","landstalker","landstalker2","mesa","mesa2","novak","patriot","patriot2","radi","rebla","rocoto","seminole","seminole2","serrano","squaddie","toros","xls","xls2"
    },
    sedans = {
        "asea","asea2","asterope","cog55","cog552","cognoscenti","cognoscenti2","emperor","emperor3","fugitive","glendale","glendale2","ingot","intruder","limo2",
        "premier","primo","primo2","regina","stafford","stanier","stratum","stretch","superd","surge","tailgater","warrener","washington"
    },
    service = {
        "airbus","brickade","bus","coach","pbus2","rallytruck","rentalbus","taxi","tourbus","trash","trash2","wastelander"
    },
    sports = {
        "alpha","banshee","bestiagts","blista2","blista3","buffalo","buffalo2","buffalo3","carbonizzare","comet2","comet3","comet4","comet5","coquette",
        "coquette4","deveste","drafter","elegy","elegy2","feltzer2","flashgt","furoregt","fusilade","futo","gb200","hotring","imorgon","issi7","italigto","italirsx",
        "jester","jester2","jester3","jugular","khamelion","komoda","kuruma","kuruma2","locust","lynx","massacro","massacro2","neo","neon","ninef","ninef2","omnis",
        "paragon","paragon2","pariah","penumbra","penumbra2","raiden","rapidgt","rapidgt2","raptor","revolter","ruston","schafter2","schafter6",
        "schlagen","schwarzer","sentinel3","seven70","specter","specter2","streiter","sugoi","sultan","sultan2","surano","tampa2","tropos",
        "verlierer2","veto","veto2","vstr","zr380","zr3802"
    },
    sportsclassic = {
        "ardent","btype","btype2","btype3","casco","cheburek","cheetah2","coquette2","deluxo","dynasty","fagaloa","feltzer3","gt500","infernus2",
        "jb700","jb7002","mamba","manana","manana2","michelli","monroe","nebula","peyote","peyote3","pigalle","rapidgt3","retinue","retinue2",
        "savestra","stinger","stingergt","stromberg","swinger","toreador","torero","tornado2","tornado5","tornado6",
        "turismo2","viseris","z190","zion3","ztype"
    },
    super = {
        "adder","autarch","banshee2","bullet","cheetah","cyclone","emerus","entity2","entityxf","fmj","furia","gp1","infernus",
        "italigtb","italigtb2","krieger","le7b","nero","nero2","osiris","penetrator","pfister811","prototipo","reaper",
        "s80","sc1","scramjet","sheava","sultanrs","t20","taipan","tempesta","tezeract","thrax","tigon","turismor","tyrant",
        "tyrus","vacca","vagner","vigilante","visione","voltic","voltic2","xa21","zentorno","zorrusso"
    },
    utility = {
        "airtug","caddy","caddy2","caddy3","docktug","forklift","mower","ripley","sadler","sadler2","scrap",
        "slamtruck","towtruck","towtruck2","tractor","tractor2","tractor3","utillitruck","utillitruck2","utillitruck3"
    },
    vans = {
        "bison","bobcatxl","boxville2","boxville3","burrito2","burrito3","camper","gburrito","gburrito2","journey","minivan","minivan2",
        "paradise","pony","pony2","rumpo","rumpo3","speedo","speedo4","surfer","taco","youga","youga3"
    }
}
