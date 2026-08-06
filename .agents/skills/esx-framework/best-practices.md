# ESX Best Practices

Based on official ESX documentation: https://docs.esx-framework.org/en/tutorial/coding_practices

## Naming Conventions

### camelCase for local variables and functions

```lua
local myVariable = 10
local playerCount = 0

local function calculateDistance(pos1, pos2)
    return #(pos1 - pos2)
end
```

### PascalCase for global functions

```lua
function MyGlobalFunction()
    print('This is global')
end
```

### UPPERCASE for constants

```lua
local MAX_DISTANCE <const> = 10.0  -- Lua 5.4
local INTERACTION_KEY = 38
local DEFAULT_SALARY = 500
```

## Use Local Variables

**ALWAYS prefer local over global** — locals are faster and prevent scope pollution.

```lua
-- GOOD
local playerPed = PlayerPedId()
local playerCoords = GetEntityCoords(playerPed)

-- BAD (global variables)
playerPed = PlayerPedId()
playerCoords = GetEntityCoords(playerPed)
```

## Caching

Cache frequently accessed values to improve performance.

```lua
-- GOOD: Cache once
local playerPed = PlayerPedId()
local playerCoords = GetEntityCoords(playerPed)

CreateThread(function()
    while condition do
        -- Use cached values
        local distance = #(playerCoords - targetCoords)
        Wait(1000)
    end
end)

-- Listen for ped changes
AddEventHandler('esx:playerPedChanged', function(newPed)
    playerPed = newPed
end)

-- BAD: Call every iteration
CreateThread(function()
    while condition do
        local distance = #(GetEntityCoords(PlayerPedId()) - targetCoords)
        Wait(1000)
    end
end)
```

### Common caching patterns

```lua
local playerId = PlayerId()
local serverId = GetPlayerServerId(playerId)
local playerPed = PlayerPedId()

-- Update on ped change
AddEventHandler('esx:playerPedChanged', function(newPed)
    playerPed = newPed
end)
```

## Avoid Infinite Loops

Always include a condition to exit loops.

```lua
-- BAD: True infinite loop
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, 38) then
            -- Do something
        end
    end
end)

-- GOOD: Conditional loop
local function startPoliceThread()
    CreateThread(function()
        while ESX.PlayerData.job and ESX.PlayerData.job.name == 'police' do
            Wait(0)
            if IsControlJustPressed(0, 38) then
                -- Do something
            end
        end
    end)
end

-- Start thread when job changes
AddEventHandler('esx:setJob', function(job)
    if job.name == 'police' then
        startPoliceThread()
    end
end)

-- Check on resource start
if ESX.PlayerData.job and ESX.PlayerData.job.name == 'police' then
    startPoliceThread()
end
```

## Proper Wait Times

Don't use `Wait(0)` unless absolutely necessary — adjust based on your needs.

```lua
-- BAD: Unnecessary high frequency check
CreateThread(function()
    while true do
        Wait(0) -- Runs every frame!
        local health = GetEntityHealth(playerPed)
    end
end)

-- GOOD: Reasonable frequency
CreateThread(function()
    while true do
        Wait(1000) -- Check every second
        local health = GetEntityHealth(playerPed)
    end
end)
```

## Modern Natives & Methods

Use modern alternatives over outdated functions.

```lua
-- Use PlayerPedId() instead of GetPlayerPed(-1)
local ped = PlayerPedId()

-- Use vector math for distance
local distance = #(vector3(x1, y1, z1) - vector3(x2, y2, z2))
-- NOT: GetDistanceBetweenCoords(x1, y1, z1, x2, y2, z2, true)

-- Use joaat() for hashes
local hash = joaat('adder')
-- NOT: GetHashKey('adder')

-- Use table insertion shortcut
table[#table + 1] = value
-- NOT: table.insert(table, value)

-- Use direct nil assignment
table[index] = nil
-- NOT: table.remove(table, index)
```

## DRY (Don't Repeat Yourself)

Write reusable code.

```lua
-- BAD: Repeated code
RegisterNetEvent('myResource:giveItem1')
AddEventHandler('myResource:giveItem1', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    if xPlayer.canCarryItem('bread', 1) then
        xPlayer.addInventoryItem('bread', 1)
        xPlayer.showNotification('Received bread', 'success')
    end
end)

RegisterNetEvent('myResource:giveItem2')
AddEventHandler('myResource:giveItem2', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    if xPlayer.canCarryItem('water', 1) then
        xPlayer.addInventoryItem('water', 1)
        xPlayer.showNotification('Received water', 'success')
    end
end)

-- GOOD: Reusable function
local function giveItem(playerId, item, count, label)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    if xPlayer.canCarryItem(item, count) then
        xPlayer.addInventoryItem(item, count)
        xPlayer.showNotification('Received ' .. label, 'success')
        return true
    else
        xPlayer.showNotification('Inventory full', 'error')
        return false
    end
end

RegisterNetEvent('myResource:giveItem')
AddEventHandler('myResource:giveItem', function(item, count, label)
    giveItem(source, item, count, label)
end)
```

## Comments & Documentation

Use clear comments for complex logic.

```lua
---@param playerId number The player's server ID
---@param item string The item name
---@param count number The amount to give
---@return boolean success Whether the item was given
local function giveItem(playerId, item, count)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return false end
    
    -- Check if player has inventory space
    if not xPlayer.canCarryItem(item, count) then
        xPlayer.showNotification('Inventory full', 'error')
        return false
    end
    
    xPlayer.addInventoryItem(item, count)
    return true
end
```

## Security

### Never trust client data

```lua
-- BAD: Client sends price
RegisterNetEvent('shop:buyItem')
AddEventHandler('shop:buyItem', function(item, price)
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.removeMoney(price) -- Client controls price!
end)

-- GOOD: Server validates price
RegisterNetEvent('shop:buyItem')
AddEventHandler('shop:buyItem', function(item)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    local price = Config.Items[item].price -- Server controls price
    if xPlayer.getMoney() >= price then
        xPlayer.removeMoney(price, 'Bought ' .. item)
        xPlayer.addInventoryItem(item, 1)
    end
end)
```

### Use SecureNetEvent for client events

```lua
-- CLIENT: Can only be triggered by server
ESX.SecureNetEvent('myResource:rewardPlayer', function(reward)
    -- Safe to use, server-only trigger
    print('Received reward:', reward)
end)

-- SERVER: Trigger the secure event
xPlayer.triggerEvent('myResource:rewardPlayer', 1000)
```

### Validate everything server-side

```lua
RegisterNetEvent('garage:takeVehicle')
AddEventHandler('garage:takeVehicle', function(vehiclePlate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    -- Validate player owns this vehicle
    MySQL.Async.fetchScalar('SELECT 1 FROM owned_vehicles WHERE plate = @plate AND owner = @owner', {
        ['@plate'] = vehiclePlate,
        ['@owner'] = xPlayer.identifier
    }, function(result)
        if result then
            -- Player owns vehicle, spawn it
            spawnVehicle(source, vehiclePlate)
        else
            -- Cheater trying to spawn vehicle they don't own
            xPlayer.kick('Attempted to spawn vehicle they don\'t own')
        end
    end)
end)
```

## Error Handling

Always check for nil and handle errors.

```lua
-- GOOD
local xPlayer = ESX.GetPlayerFromId(source)
if not xPlayer then 
    print('ERROR: xPlayer is nil for source ' .. source)
    return 
end

local itemData = xPlayer.getInventoryItem('bread')
if not itemData then
    print('ERROR: Item not found')
    return
end

if itemData.count >= 1 then
    xPlayer.removeInventoryItem('bread', 1)
end
```

## Indentation

Use **2 spaces** for indentation (ESX standard).

```lua
if condition then
  if anotherCondition then
    doSomething()
  end
end
```

## Lua 5.4 Features

If you have Lua 5.4 enabled in your fxmanifest:

```lua
lua54 'yes'
```

You can use:

```lua
-- Constants
local MAX_DISTANCE <const> = 10.0

-- Compound operators
count += 1
count -= 1
count *= 2
count /= 2

-- to-be-closed variables
local file <close> = io.open('file.txt', 'r')
```

## Folder Structure

Organize your resource properly:

```
myresource/
├── fxmanifest.lua
├── config.lua
├── client/
│   ├── main.lua
│   └── menu.lua
├── server/
│   ├── main.lua
│   └── callbacks.lua
└── shared/
    └── utils.lua
```

## Resource Optimization Checklist

- [ ] Use `local` for all variables unless they must be global
- [ ] Cache frequently accessed values (PlayerPedId, coords, etc.)
- [ ] Use appropriate Wait times (avoid Wait(0) when possible)
- [ ] Use modern natives and methods
- [ ] Avoid infinite loops (add exit conditions)
- [ ] Minimize database queries (batch when possible)
- [ ] Don't create threads unnecessarily
- [ ] Use `exports` over triggers when possible
- [ ] Validate all client data server-side
- [ ] Use ESX.SecureNetEvent for client events
- [ ] Check for nil before using objects
- [ ] Use descriptive variable/function names
- [ ] Add comments for complex logic
- [ ] Follow ESX naming conventions

## Performance Tips

1. **Cache ESX object once**:
   ```lua
   -- Resource start
   ESX = exports.es_extended.getSharedObject()
   
   -- NOT in every function
   ```

2. **Minimize GetPlayerFromId calls**:
   ```lua
   -- GOOD
   local xPlayer = ESX.GetPlayerFromId(source)
   local money = xPlayer.getMoney()
   local job = xPlayer.getJob()
   
   -- BAD
   local money = ESX.GetPlayerFromId(source).getMoney()
   local job = ESX.GetPlayerFromId(source).getJob()
   ```

3. **Use GetExtendedPlayers with filters**:
   ```lua
   -- GOOD
   local police = ESX.GetExtendedPlayers('job', 'police')
   
   -- BAD (loops all players)
   local police = {}
   for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
       if xPlayer.job.name == 'police' then
           table.insert(police, xPlayer)
       end
   end
   ```

4. **Batch database operations**:
   ```lua
   -- GOOD: One query
   MySQL.Async.execute('INSERT INTO logs (player, action) VALUES (?, ?), (?, ?)', {
       player1, action1,
       player2, action2
   })
   
   -- BAD: Multiple queries
   MySQL.Async.execute('INSERT INTO logs (player, action) VALUES (?, ?)', {player1, action1})
   MySQL.Async.execute('INSERT INTO logs (player, action) VALUES (?, ?)', {player2, action2})
   ```
