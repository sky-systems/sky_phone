# Lua / FiveM script optimization and best practices

Use this rule when writing or reviewing FiveM Lua for performance, readability, or security.

## General practices

### Localize functions and variables

Lua accesses local variables and functions faster than global ones. Prefer `local` unless the value must be global.

```lua
-- Don't
myVariable = false
function someFunction()
    print('Im a global function!')
end

-- Do
local myVariable = false
local function someFunction()
    print('Im a local function!')
end
```

### Prefer table indexing over table.insert

Direct assignment is more efficient than `table.insert`.

```lua
local t = {}
table.insert(t, {})     -- Don't
t[#t + 1] = {}         -- Do
```

### Simplify conditionals

Use `if something then` instead of `if something ~= nil then` when you want to treat both `nil` and `false` as falsy.

```lua
if bool then  -- true only when neither nil nor false
    print('bool was neither nil or false!')
end
```

### Keep functions universal

Write functions and events that accept parameters so they can handle multiple scenarios and stay reusable.

```lua
local function someFunction(param1, param2, param3)
    if param1 == 'something' then
        -- ...
    elseif param2 == 'somethingelse' then
        -- ...
    end
end

RegisterNetEvent('someEvent', function(param1, param2, param3)
    -- same idea
end)
```

### Short returns

Exit early when conditions are not met to avoid deep nesting.

```lua
local function someFunction(param1, param2, param3)
    if not param1 then return end
    -- ...
    if not param2 then return end
    -- ...
end
```

### Avoid re-creating tables in loops

Initialize once and reuse.

```lua
local reusableTable = {}
for i = 1, 10 do
    reusableTable[i] = i  -- reuse, don't create new table each iteration
end
```

### Free memory with nil

Assign unused variables to `nil` so the garbage collector can reclaim memory.

```lua
local largeData = { 1, 2, 3, 4 }
-- ... use it ...
largeData = nil
```

### Avoid hardcoding

Centralize configurable values (coords, item names, amounts) in a `config.lua` or similar.

```lua
Config = {
    Zones = {
        PoliceStation = vector3(441.1, -981.1, 30.7),
        Hospital = vector3(1151.21, -1529.62, 34.84)
    },
    Payments = { Police = 150, EMS = 120 }
}
```

### Logging and debugging

Use a debug flag so you can enable/disable logs without removing code.

```lua
local DEBUG = true
local function debugLog(message)
    if DEBUG then print(message) end
end
```

### Track performance

Use `os.clock()` or FiveM’s `GetGameTimer()` for performance-critical sections.

```lua
local start = os.clock()
-- code to measure
print("Execution time:", os.clock() - start)

-- or
local startTime = GetGameTimer()
Wait(1000)
print("Execution time (ms):", GetGameTimer() - startTime)
```

### Avoid overusing network events

For frequent sync, prefer shared state (state bags, entity state) instead of spamming `TriggerServerEvent` / `TriggerClientEvent`.

```lua
Entity(playerPed).state:set('exampleData', 123, true)
local data = Entity(playerPed).state.exampleData
```

### Optimize data transmission

Send only the data you need, not whole tables or large payloads.

```lua
TriggerServerEvent('exampleEvent', { x = 100, y = 200 })  -- minimal payload
```

## Code readability

### Comment your code

Explain non-obvious or complex logic.

```lua
-- Check if the player is in range of the target zone
if #(playerCoords - targetCoords) < 10 then
    print('Player is in range')
end
```

### Organize your script

Group variables, functions, event handlers, and main logic into clear sections.

```lua
-- Variables
local QBCore = exports['qb-core']:GetCoreObject()

-- Functions
local function calculateDistance(pos1, pos2)
    return #(pos1 - pos2)
end

-- Events
RegisterNetEvent('exampleEvent', function() ... end)

-- Main logic
CreateThread(function() ... end)
```

### Folder structure

Split scripts into smaller files instead of one huge file.

```
my_script/
├── client/
│   ├── main.lua
│   ├── utils.lua
├── server/
│   ├── main.lua
│   ├── events.lua
├── shared/
│   ├── config.lua
└── fxmanifest.lua
```

## Native usage

### Use PlayerPedId() instead of GetPlayerPed(-1)

```lua
local ped = GetPlayerPed(-1)   -- Don't
local ped = PlayerPedId()       -- Do
```

### Use vector distance instead of GetDistanceBetweenCoords

```lua
local dist = GetDistanceBetweenCoords(pCoords, coords, true)  -- Don't
local dist = #(pCoords - coords)                             -- Do
if dist < 5 then ... end
```

## Loops and threads

### Control when loops run

Only run loops when needed (e.g. when player is in zone); turn them off when not.

```lua
local listen = false
CreateThread(function()
    while listen do
        -- do work only when needed
        Wait(0)
    end
end)
-- set listen = true when entering zone, false when leaving
```

### Prefer variable Wait() over fixed Wait(0)

Use a variable wait time: long when idle, short when active.

```lua
CreateThread(function()
    while true do
        local sleep = 2500
        local inRange = #(GetEntityCoords(PlayerPedId()) - someCoords) < 10.0
        if inRange then
            sleep = 0
            -- do something
        end
        Wait(sleep)
    end
end)
```

### Restrict job-specific loops

Only run job-specific logic for players who have that job.

```lua
local job = QBCore.Functions.GetPlayerData().job.name
CreateThread(function()
    while job == 'police' do
        -- police-only logic
        Wait(0)
    end
end)
```

## Security

- Multiple checks and validation are good; don’t shy away from extra ifs or passing tokens through events.
- **Never** handle money or item transactions on the client; always validate and apply on the server.

## Event handlers

Use handlers to update state so you don’t have to poll constantly.

```lua
local isLoggedIn = false
local PlayerData = {}

AddStateBagChangeHandler('isLoggedIn', nil, function(_, _, value)
    if value then
        isLoggedIn = true
        PlayerData = QBCore.Functions.GetPlayerData()
    else
        isLoggedIn = false
        PlayerData = {}
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)
```
