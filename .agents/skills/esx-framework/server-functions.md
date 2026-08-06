# ESX Server Functions

All functions available on **SERVER side** via `ESX` object.

## Player Retrieval

### ESX.GetPlayerFromId(source)

Returns xPlayer object for player.

```lua
local xPlayer = ESX.GetPlayerFromId(source)
if not xPlayer then return end

print('Player name:', xPlayer.getName())
```

### ESX.GetPlayerFromIdentifier(identifier)

Returns xPlayer object by identifier.

```lua
local xPlayer = ESX.GetPlayerFromIdentifier('license:abc123...')
if not xPlayer then return end
```

### ESX.GetExtendedPlayers(key, value)

Returns multiple players matching filter.

```lua
-- Get all police officers
local policeOfficers = ESX.GetExtendedPlayers('job', 'police')
for i, xPlayer in ipairs(policeOfficers) do
    print('Officer:', xPlayer.getName())
end

-- Get ALL players (no filter)
local allPlayers = ESX.GetExtendedPlayers()
for i, xPlayer in ipairs(allPlayers) do
    print(xPlayer.getName())
end
```

### ESX.GetNumPlayers(key, value)

Returns number of players matching filter.

```lua
local policeCount = ESX.GetNumPlayers('job', 'police')
print('Police online:', policeCount)

local totalPlayers = ESX.GetNumPlayers()
print('Total players:', totalPlayers)
```

## Player Identification

### ESX.GetIdentifier(playerId)

Returns player's identifier (license with char prefix).

```lua
local identifier = ESX.GetIdentifier(source)
print('Player identifier:', identifier)
-- Output: "char1:license:abc123..."
```

## Callbacks

### ESX.RegisterServerCallback(name, cb)

Registers a server callback that client can trigger.

```lua
ESX.RegisterServerCallback('myResource:getData', function(source, cb, param1)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(nil) end
    
    -- Do server logic
    local data = {
        money = xPlayer.getMoney(),
        job = xPlayer.job.name
    }
    
    cb(data)
end)

-- Client calls it:
-- ESX.TriggerServerCallback('myResource:getData', function(data)
--     print(data.money, data.job)
-- end, 'param1')
```

### ESX.TriggerClientCallback(playerId, name, cb, ...)

Triggers a client callback and waits for response.

**WARNING**: Never trust client data for sensitive operations!

```lua
ESX.TriggerClientCallback(source, 'esx:getVehicleType', function(vehicleType)
    print('Vehicle type:', vehicleType)
end, 'bati')
```

### ESX.AwaitClientCallback(playerId, name, ...)

Triggers client callback and waits (blocking).

**WARNING**: Never trust client data for sensitive operations!

```lua
local vehicleType = ESX.AwaitClientCallback(source, 'esx:getVehicleType', 'bati')
print('Vehicle type:', vehicleType)
```

## Commands

### ESX.RegisterCommand(name, group, cb, allowConsole, suggestion)

Registers a command with permission check.

```lua
ESX.RegisterCommand('heal', 'admin', function(xPlayer, args, showError)
    xPlayer.triggerEvent('esx_ambulancejob:heal', 'full')
end, false, {
    help = 'Heal yourself',
    arguments = {}
})

-- With arguments
ESX.RegisterCommand('givemoney', 'admin', function(xPlayer, args, showError)
    local targetPlayer = ESX.GetPlayerFromId(args.playerId)
    if not targetPlayer then
        return showError('Player not found')
    end
    
    targetPlayer.addMoney(args.amount, 'Admin gave money')
    xPlayer.showNotification('Gave $' .. args.amount .. ' to ' .. targetPlayer.getName())
end, false, {
    help = 'Give money to player',
    arguments = {
        {name = 'playerId', help = 'Player ID', type = 'playerId'},
        {name = 'amount', help = 'Amount', type = 'number'}
    }
})
```

## Jobs

### ESX.GetJobs()

Returns all registered jobs.

```lua
local jobs = ESX.GetJobs()
for jobName, jobData in pairs(jobs) do
    print('Job:', jobName, jobData.label)
    for grade, gradeData in pairs(jobData.grades) do
        print('  Grade:', gradeData.label, 'Salary:', gradeData.salary)
    end
end
```

### ESX.DoesJobExist(job, grade)

Checks if job and grade exist.

```lua
if ESX.DoesJobExist('police', 4) then
    print('Police chief grade exists')
end
```

### ESX.CreateJob(name, label, grades)

Creates a new job and inserts into database.

```lua
ESX.CreateJob('baker', 'Baker', {
    {grade = 0, name = 'apprentice', label = 'Apprentice', salary = 320},
    {grade = 1, name = 'employee', label = 'Employee', salary = 470},
    {grade = 2, name = 'manager', label = 'Manager', salary = 610},
    {grade = 3, name = 'boss', label = 'Boss', salary = 910}
})
```

### ESX.RefreshJobs()

Reloads jobs from database.

```lua
-- After manually editing jobs in database
ESX.RefreshJobs()
```

## Items

### ESX.GetItems()

Returns all registered items.

```lua
local items = ESX.GetItems()
for itemName, itemData in pairs(items) do
    print('Item:', itemName, itemData.label, 'Weight:', itemData.weight)
end
```

### ESX.GetItemLabel(item)

Returns item label.

```lua
local label = ESX.GetItemLabel('bread')
print('Item label:', label) -- 'Bread'
```

### ESX.AddItems(items)

Adds new items to database and ESX.Items (only if using default inventory).

```lua
ESX.AddItems({
    {name = 'energy_drink', label = 'Energy Drink', weight = 1, rare = false, canRemove = true},
    {name = 'diamond_ring', label = 'Diamond Ring', weight = 2, rare = true}
})
```

### ESX.RefreshItems()

Reloads items from database (only if using default inventory).

```lua
ESX.RefreshItems()
```

### ESX.RegisterUsableItem(item, cb)

Registers an item as usable.

```lua
ESX.RegisterUsableItem('bread', function(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    xPlayer.removeInventoryItem('bread', 1)
    
    -- Heal player or do something
    TriggerClientEvent('esx_status:add', playerId, 'hunger', 200000)
    xPlayer.showNotification('You ate bread', 'success')
end)
```

### ESX.UseItem(source, item, ...)

Forces player to use item.

```lua
ESX.UseItem(source, 'bread')
```

### ESX.GetUsableItems()

Returns all usable items.

```lua
local usableItems = ESX.GetUsableItems()
for itemName, isUsable in pairs(usableItems) do
    if isUsable then
        print('Usable:', itemName)
    end
end
```

## Vehicle Functions

### ESX.GetVehicleType(model, playerId, cb)

Returns vehicle type (server must ask client).

```lua
-- With callback
ESX.GetVehicleType('t20', source, function(vehicleType)
    print('Vehicle type:', vehicleType)
end)

-- With promise (blocking)
local vehicleType = ESX.GetVehicleType('t20', source)
print('Vehicle type:', vehicleType)
```

## Pickups (Default Inventory Only)

### ESX.CreatePickup(type, name, count, label, playerId, components, tintIndex)

Creates a pickup at player's position.

```lua
-- Item pickup
ESX.CreatePickup('item_standard', 'bread', 5, 'Bread', source)

-- Money pickup
ESX.CreatePickup('item_money', 'money', 500, 'Cash', source)

-- Weapon pickup
ESX.CreatePickup('item_weapon', 'WEAPON_PISTOL', 50, 'Pistol', source, {}, 0)
```

## Events

### ESX.TriggerClientEvent(eventName, playerIds, ...)

Triggers event for one or multiple players.

```lua
-- Single player
ESX.TriggerClientEvent('myResource:notify', source, 'Hello!')

-- Multiple players
local officers = ESX.GetExtendedPlayers('job', 'police')
local officerIds = {}
for i, xPlayer in ipairs(officers) do
    table.insert(officerIds, xPlayer.source)
end

ESX.TriggerClientEvent('myResource:alert', officerIds, 'Code 3!')
```

## Discord Logs

### ESX.DiscordLog(webhookName, title, color, message)

Sends simple Discord log.

```lua
ESX.DiscordLog('UserActions', 'Player Joined', 'green', 'John Doe joined the server')
```

### ESX.DiscordLogFields(webhookName, title, color, fields)

Sends Discord log with fields.

```lua
ESX.DiscordLogFields('AdminActions', '/givemoney Used', 'orange', {
    {name = 'Admin', value = xPlayer.getName(), inline = true},
    {name = 'Target', value = targetPlayer.getName(), inline = true},
    {name = 'Amount', value = '$5000', inline = true}
})
```

## Player Function Overrides

### ESX.RegisterPlayerFunctionOverrides(index, overrides)

Adds custom functions to xPlayer object.

```lua
local leoJobs = {'police', 'sheriff', 'fbi'}
local medicJobs = {'ambulance', 'doctor', 'firefighter'}

ESX.RegisterPlayerFunctionOverrides('customFunctions', {
    isLeo = function(self)
        return table.contains(leoJobs, self.job.name)
    end,
    isMedic = function(self)
        return table.contains(medicJobs, self.job.name)
    end
})

-- Now you can use:
-- if xPlayer.isLeo() then ... end
```

### ESX.SetPlayerFunctionOverride(index)

Switches active override set.

```lua
ESX.SetPlayerFunctionOverride('customFunctions')
```

## Debug

### ESX.Trace(msg)

Prints trace message when Debug is enabled in config.

```lua
ESX.Trace('Player ' .. xPlayer.getName() .. ' opened inventory')
```

## Best Practices

1. **Always check for nil**:
   ```lua
   local xPlayer = ESX.GetPlayerFromId(source)
   if not xPlayer then return end
   ```

2. **Use GetExtendedPlayers for filtered player lists**:
   ```lua
   -- GOOD - Get specific job
   local officers = ESX.GetExtendedPlayers('job', 'police')
   
   -- BAD - Loop through all then filter
   for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
       if xPlayer.job.name == 'police' then
           -- Less efficient
       end
   end
   ```

3. **Never trust client data**:
   ```lua
   -- BAD
   RegisterNetEvent('myResource:buyItem')
   AddEventHandler('myResource:buyItem', function(price)
       -- Client controls price! Bad!
       local xPlayer = ESX.GetPlayerFromId(source)
       xPlayer.removeMoney(price)
   end)
   
   -- GOOD
   RegisterNetEvent('myResource:buyItem')
   AddEventHandler('myResource:buyItem', function(itemName)
       local xPlayer = ESX.GetPlayerFromId(source)
       if not xPlayer then return end
       
       local price = Config.Items[itemName].price -- Server controls price
       if xPlayer.getMoney() >= price then
           xPlayer.removeMoney(price, 'Bought ' .. itemName)
           xPlayer.addInventoryItem(itemName, 1)
       end
   end)
   ```

4. **Use callbacks for client-to-server data requests**:
   ```lua
   ESX.RegisterServerCallback('myResource:canBuy', function(source, cb, itemName)
       local xPlayer = ESX.GetPlayerFromId(source)
       if not xPlayer then return cb(false) end
       
       local price = Config.Items[itemName].price
       cb(xPlayer.getMoney() >= price)
   end)
   ```

5. **Cache xPlayer when using multiple times**:
   ```lua
   -- GOOD
   local xPlayer = ESX.GetPlayerFromId(source)
   if not xPlayer then return end
   
   local money = xPlayer.getMoney()
   local job = xPlayer.job.name
   local inventory = xPlayer.inventory
   
   -- BAD (calls GetPlayerFromId 3 times)
   local money = ESX.GetPlayerFromId(source).getMoney()
   local job = ESX.GetPlayerFromId(source).job.name
   local inventory = ESX.GetPlayerFromId(source).inventory
   ```
