# ESX Core Concepts

## Framework Architecture

ESX Legacy is a **modular framework** that provides:
- Player management and persistence
- Job and economy systems
- Inventory and weapon management
- UI components (menus, notifications, progress bars)
- Database integration (MySQL/MariaDB)

## Getting ESX Object

### Client Side

```lua
-- RECOMMENDED: Using CreateThread
CreateThread(function()
    while not ESX do
        Wait(100)
    end
    
    while not ESX.IsPlayerLoaded() do
        Wait(100)
    end
    
    -- ESX is now available and player is loaded
    print('Player loaded:', ESX.PlayerData.firstName, ESX.PlayerData.lastName)
end)
```

### Server Side

```lua
-- ESX is immediately available on server
ESX = exports['es_extended']:getSharedObject()

-- Or if using newer exports pattern
ESX = exports.es_extended.getSharedObject()
```

## PlayerData Structure

**Available on CLIENT only** via `ESX.PlayerData`:

```lua
ESX.PlayerData = {
    coords = vector3(x, y, z),        -- Last known position
    ped = PlayerPedId(),              -- Player ped handle
    group = "user",                    -- Permission group (user/admin/superadmin)
    identifier = "char1:license...",   -- Character identifier
    ssn = "123-45-6789",              -- Social Security Number
    inventory = {},                    -- Items (table with item name as key)
    job = {},                          -- Job data (name, label, grade, salary, etc.)
    loadout = {},                      -- Weapons
    name = "John Doe",                 -- Player name (Steam/FiveM)
    playerId = 1,                      -- Server ID
    source = 1,                        -- Server ID
    variables = {},                    -- Custom variables set by server
    weight = 12,                       -- Current inventory weight
    maxWeight = 24,                    -- Maximum inventory weight
    metadata = {},                     -- Custom metadata
    admin = false,                     -- Is admin (based on group)
    license = "license:...",           -- Rockstar license
    dateofbirth = "01/01/2000",       -- Character DOB
    height = 181,                      -- Character height
    dead = false,                      -- Is player dead
    firstName = "John",                -- Character first name
    lastName = "Doe",                  -- Character last name
    sex = "m",                         -- Character gender (m/f)
    money = 187,                       -- Cash amount (use accounts instead)
    accounts = {                       -- Money accounts
        money = 187,
        bank = 5000,
        black_money = 0
    }
}
```

## xPlayer Object (Server)

**Available on SERVER only** — represents a player with methods:

### Getting xPlayer

```lua
-- Standard way
local xPlayer = ESX.GetPlayerFromId(source)

-- By identifier
local xPlayer = ESX.GetPlayerFromIdentifier("license:abc123...")
```

### xPlayer contains same data as PlayerData PLUS server-only methods:

```lua
xPlayer.identifier      -- Player identifier
xPlayer.name           -- Player name
xPlayer.job            -- Job data
xPlayer.accounts       -- Money accounts
xPlayer.inventory      -- Items
xPlayer.loadout        -- Weapons
xPlayer.group          -- Permission group
xPlayer.coords         -- Last known coords
-- ... many methods (see xplayer-methods.md)
```

## Framework Initialization

### Client Startup Flow

1. ESX object becomes available
2. Player connects to server
3. Server creates xPlayer
4. Client receives PlayerData via `esx:playerLoaded` event
5. `ESX.PlayerLoaded` becomes true
6. `ESX.PlayerData` is populated

### Server Startup Flow

1. ESX loads from database
2. Jobs are loaded (`ESX.Jobs`)
3. Items are loaded (`ESX.Items`)
4. Resources can now use ESX

## Important Events

### Client Events

```lua
-- Player loaded (character selected)
AddEventHandler('esx:playerLoaded', function(playerData)
    ESX.PlayerData = playerData
end)

-- Player data updated
AddEventHandler('esx:updatePlayerData', function(key, value)
    ESX.PlayerData[key] = value
end)

-- Job changed
AddEventHandler('esx:setJob', function(job)
    ESX.PlayerData.job = job
end)

-- Player died
AddEventHandler('esx:onPlayerDeath', function(data)
    -- Handle death
end)

-- Player spawned
AddEventHandler('esx:onPlayerSpawn', function()
    -- Handle spawn
end)
```

### Server Events

```lua
-- Player joined (before character selection)
AddEventHandler('esx:onPlayerJoined', function()
    local _source = source
    -- Player connected
end)

-- Player loaded (character selected)
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    -- xPlayer is now available
end)

-- Player dropped
AddEventHandler('esx:playerDropped', function(playerId, reason)
    -- Player left server
end)
```

## Constants and Configuration

```lua
-- Use UPPERCASE for constants
local MAX_DISTANCE <const> = 10.0  -- Lua 5.4 const
local INTERACTION_KEY = 38          -- E key

-- Use Config for resource settings
Config = {}
Config.MaxWeight = 24
Config.EnableSocieties = true
```

## Best Practices

1. **Always wait for player load on client**:
   ```lua
   while not ESX.IsPlayerLoaded() do
       Wait(100)
   end
   ```

2. **Check for nil on server**:
   ```lua
   local xPlayer = ESX.Player(source)
   if not xPlayer then return end
   ```

3. **Cache ESX object**:
   ```lua
   -- Do this once at resource start
   ESX = exports.es_extended.getSharedObject()
   
   -- NOT in every function/event
   ```

4. **Use ESX.GetPlayerFromId**:
   ```lua
   local xPlayer = ESX.GetPlayerFromId(source)
   if not xPlayer then return end
   ```
