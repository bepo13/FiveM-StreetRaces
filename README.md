# FiveM StreetRaces

FiveM resource for street races with custom checkpoints and HUD.

## Installation

1. Add the StreetRaces folder to your FiveM resources directory
2. Edit your server.cfg and add "start StreetRaces"

commands:
/race start amount [delay] - Start a race for money using waypoint or recorded checkpoints
Optional argument for delay before race starts (default 30s)
/race cancel - Cancel a created race before it starts and refund money
/race leave - Withdraw from the active race (no refunds)
/race record - Record checkpoints using map
Set waypoints on the map to create checkpoints (snaps to nearest vehicle path node)
Double click existing checkpoints to remove
/race clear - Clear recorded checkpoints
/race save name - Save recorded checkpoints with name
/race load name - Load recorded checkpoints with name
/race delete name - Delete recorded checkpoints with name
/race list - List saved checkpoints by name
