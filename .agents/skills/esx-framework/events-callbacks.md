# ESX Events & Callbacks

## Server Callbacks

Server callbacks allow the client to request data from the server.

### Registering a Server Callback

```lua
-- SERVER
ESX.RegisterServerCallback('myResource:getPlayerData', function(source, cb, additionalParam)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(nil) end
    
    local data = {
        money = xPlayer.getMoney(),
        job = xPlayer.job.name,
        grade = xPlayer.job.grade,
        param = additionalParam
    }
    
    cb(data)
end)
```

### Calling a Server Callback

```lua
-- CLIENT
ESX.TriggerServerCallback('myResource:getPlayerData', function(data)
    if data then
        print('Money:', data.money)
        print('Job:', data.job)
    end
end, 'extraParam')
```

### Common Patterns

```lua
-- Check if player can afford something
ESX.RegisterServerCallback('shop:canAfford', function(source, cb, itemName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end
    
    local price = Config.Items[itemName].price
    cb(xPlayer.getMoney() >= price)
end)

-- CLIENT usage
ESX.TriggerServerCallback('shop:canAfford', function(canAfford)
    if canAfford then
        -- Show buy menu
    else
        lib.notify({title = 'Shop', description = 'Not enough money', type = 'error'})
    end
end, 'bread')
```

## Client Callbacks

**WARNING**: Client callbacks should NEVER be used for sensitive operations! Client can fake any data.

### Registering a Client Callback

```lua
-- CLIENT
ESX.RegisterClientCallback('myResource:getVehicleModel', function(cb, vehicle)
    local model = GetEntityModel(vehicle)
    cb(model)
end)
```

### Calling a Client Callback (Server)

```lua
-- SERVER
ESX.TriggerClientCallback(source, 'myResource:getVehicleModel', function(model)
    print('Vehicle model:', model)
end, vehicleNetId)
```

## ESX Events

### Client Events

#### esx:playerLoaded

Fired when player's character loads.

```lua
-- CLIENT
AddEventHandler('esx:playerLoaded', function(playerData)
    ESX.PlayerData = playerData
    print('Player loaded:', playerData.firstName, playerData.lastName)
    
    -- Initialize your resource
    startClientScripts()
end)
```

#### esx:updatePlayerData

Fired when any PlayerData is updated.

```lua
-- CLIENT
AddEventHandler('esx:updatePlayerData', function(key, value)
    ESX.PlayerData[key] = value
    
    if key == 'job' then
        print('Job changed to:', value.name)
    elseif key == 'money' then
        print('Money updated:', value)
    end
end)
```

#### esx:setJob

Fired when player's job changes.

```lua
-- CLIENT
AddEventHandler('esx:setJob', function(job)
    ESX.PlayerData.job = job
    print('New job:', job.name, 'Grade:', job.grade)
    
    -- Start/stop job-specific systems
    if job.name == 'police' then
        startPoliceBlips()
    else
        stopPoliceBlips()
    end
end)
```

#### esx:setAccountMoney

Fired when player's account money changes.

```lua
-- CLIENT
AddEventHandler('esx:setAccountMoney', function(account)
    print('Account updated:', account.name, account.money)
end)
```

#### esx:addInventoryItem

Fired when player receives an item.

```lua
-- CLIENT
AddEventHandler('esx:addInventoryItem', function(item, count)
    print('Received:', count, 'x', item.label)
end)
```

#### esx:removeInventoryItem

Fired when player loses an item.

```lua
-- CLIENT
AddEventHandler('esx:removeInventoryItem', function(item, count)
    print('Removed:', count, 'x', item.label)
end)
```

#### esx:onPlayerDeath

Fired when player dies.

```lua
-- CLIENT
AddEventHandler('esx:onPlayerDeath', function(data)
    print('Player died')
    print('Killer:', data.killerServerId)
    
    -- Respawn logic
end)
```

#### esx:onPlayerSpawn

Fired when player spawns.

```lua
-- CLIENT
AddEventHandler('esx:onPlayerSpawn', function()
    print('Player spawned')
end)
```

#### esx:playerPedChanged

Fired when player ped changes (e.g., after model change).

```lua
-- CLIENT
local playerPed = PlayerPedId()

AddEventHandler('esx:playerPedChanged', function(newPed)
    playerPed = newPed
    print('Ped changed:', newPed)
end)
```

### Server Events

#### esx:onPlayerJoined

Fired when player connects (before character selection).

```lua
-- SERVER
AddEventHandler('esx:onPlayerJoined', function()
    local _source = source
    print('Player connected:', _source)
end)
```

#### esx:playerLoaded

Fired when player's character loads.

```lua
-- SERVER
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    print('Player loaded:', xPlayer.getName())
    
    -- Give welcome bonus
    if xPlayer.getMeta('firstTime') == nil then
        xPlayer.addMoney(5000, 'Welcome bonus')
        xPlayer.setMeta('firstTime', false)
    end
end)
```

#### esx:playerDropped

Fired when player disconnects.

```lua
-- SERVER
AddEventHandler('esx:playerDropped', function(playerId, reason)
    print('Player ' .. playerId .. ' left:', reason)
end)
```

#### esx:setJob

Fired when player's job changes (server-side).

```lua
-- SERVER
AddEventHandler('esx:setJob', function(playerId, job, lastJob)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    print(xPlayer.getName() .. ' changed from ' .. lastJob.name .. ' to ' .. job.name)
    
    -- Log job change
    MySQL.Async.execute('INSERT INTO job_changes (identifier, old_job, new_job) VALUES (@identifier, @old, @new)', {
        ['@identifier'] = xPlayer.identifier,
        ['@old'] = lastJob.name,
        ['@new'] = job.name
    })
end)
```

## Secure Net Events

Use SecureNetEvent for client events that should only be triggered by server.

### Registering Secure Net Event

```lua
-- CLIENT
ESX.SecureNetEvent('myResource:giveReward', function(amount, reason)
    -- Only server can trigger this
    print('Received reward:', amount, reason)
    
    lib.notify({
        title = 'Reward',
        description = 'You received $' .. amount .. ' for ' .. reason,
        type = 'success'
    })
end)
```

### Triggering Secure Net Event

```lua
-- SERVER
local xPlayer = ESX.GetPlayerFromId(source)
xPlayer.triggerEvent('myResource:giveReward', 500, 'completing mission')
```

## Custom Events

### Triggering Client Event from Server

```lua
-- SERVER
local xPlayer = ESX.GetPlayerFromId(source)
xPlayer.triggerEvent('myResource:openMenu', menuData)

-- Or using TriggerClientEvent
TriggerClientEvent('myResource:openMenu', source, menuData)

-- Or for multiple players
local officers = ESX.GetExtendedPlayers('job', 'police')
for i, xPlayer in ipairs(officers) do
    xPlayer.triggerEvent('myResource:alert', 'Code 3 at Legion Square')
end
```

### Triggering Server Event from Client

```lua
-- CLIENT
TriggerServerEvent('myResource:buyItem', 'bread')
```

### Receiving Custom Events

```lua
-- CLIENT
RegisterNetEvent('myResource:openMenu')
AddEventHandler('myResource:openMenu', function(menuData)
    -- Open menu with data
end)

-- SERVER
RegisterNetEvent('myResource:buyItem')
AddEventHandler('myResource:buyItem', function(itemName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    -- Validate and process purchase
    local price = Config.Items[itemName].price
    if xPlayer.getMoney() >= price then
        xPlayer.removeMoney(price, 'Bought ' .. itemName)
        xPlayer.addInventoryItem(itemName, 1)
    end
end)
```

## Best Practices

1. **Always validate server-side**:
   ```lua
   -- BAD: Trust client data
   RegisterNetEvent('shop:buy')
   AddEventHandler('shop:buy', function(price)
       local xPlayer = ESX.GetPlayerFromId(source)
       xPlayer.removeMoney(price) -- Client controls price!
   end)
   
   -- GOOD: Server validates
   RegisterNetEvent('shop:buy')
   AddEventHandler('shop:buy', function(itemName)
       local xPlayer = ESX.GetPlayerFromId(source)
       if not xPlayer then return end
       
       local price = Config.Items[itemName].price
       if xPlayer.getMoney() >= price then
           xPlayer.removeMoney(price, 'Bought ' .. itemName)
           xPlayer.addInventoryItem(itemName, 1)
       end
   end)
   ```

2. **Use callbacks for data requests**:
   ```lua
   -- GOOD: Use callback
   ESX.TriggerServerCallback('shop:canAfford', function(canAfford)
       if canAfford then
           -- Do something
       end
   end, 'bread')
   
   -- BAD: Use event
   TriggerServerEvent('shop:checkAfford', 'bread')
   RegisterNetEvent('shop:affordResult')
   AddEventHandler('shop:affordResult', function(canAfford)
       -- Client can fake this event
   end)
   ```

3. **Use SecureNetEvent for important client events**:
   ```lua
   -- CLIENT
   ESX.SecureNetEvent('police:giveArmor', function()
       SetPedArmour(PlayerPedId(), 100)
   end)
   
   -- SERVER (validated)
   local xPlayer = ESX.GetPlayerFromId(source)
   if xPlayer.job.name == 'police' then
       xPlayer.triggerEvent('police:giveArmor')
   end
   ```

4. **Always check for nil**:
   ```lua
   RegisterNetEvent('myResource:action')
   AddEventHandler('myResource:action', function()
       local xPlayer = ESX.GetPlayerFromId(source)
       if not xPlayer then return end
       
       -- Safe to use xPlayer
   end)
   ```

5. **Use proper event naming**:
   ```lua
   -- GOOD: Descriptive names
   'myResource:openShopMenu'
   'myResource:buyItem'
   'myResource:sellItem'
   
   -- BAD: Vague names
   'myResource:event1'
   'myResource:action'
   'openMenu'
   ```

6. **Listen to ESX events for state changes**:
   ```lua
   -- CLIENT: React to job changes
   AddEventHandler('esx:setJob', function(job)
       if job.name == 'police' then
           startPoliceFeatures()
       else
           stopPoliceFeatures()
       end
   end)
   
   -- Check on resource start too
   CreateThread(function()
       while not ESX.IsPlayerLoaded() do Wait(100) end
       
       if ESX.PlayerData.job.name == 'police' then
           startPoliceFeatures()
       end
   end)
   ```
