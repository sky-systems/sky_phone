# ESX Client Functions

All functions available on **CLIENT side** via `ESX` object.

## Player State

### ESX.IsPlayerLoaded()

Returns if player has successfully loaded.

```lua
if ESX.IsPlayerLoaded() then
    print('Player is loaded and ready')
end

-- Common pattern: wait for load
while not ESX.IsPlayerLoaded() do
    Wait(250)
end
```

### ESX.GetPlayerData()

Returns `ESX.PlayerData` (same as accessing it directly).

```lua
local playerData = ESX.GetPlayerData()
print('Player job:', playerData.job.name)
```

### ESX.SetPlayerData(key, value)

Sets player data locally (will be overwritten by server updates).

```lua
ESX.SetPlayerData('customKey', 'customValue')
print(ESX.PlayerData.customKey) -- 'customValue'
```

## Secure Events

### ESX.SecureNetEvent(name, callback)

Registers a client event that can ONLY be triggered by server (prevents cheaters).

```lua
ESX.SecureNetEvent('myResource:giveReward', function(amount)
    -- Only server can trigger this
    print('Received reward:', amount)
end)

-- Server side:
TriggerClientEvent('myResource:giveReward', playerId, 1000)
```

## Inventory

### ESX.SearchInventory(items, count)

Searches player inventory for items.

```lua
-- Search single item
local breadItem = ESX.SearchInventory('bread')
if breadItem and breadItem.count > 0 then
    print('You have', breadItem.count, 'bread')
end

-- Search multiple items
local items = ESX.SearchInventory({'bread', 'water'}, true)
for itemName, itemData in pairs(items) do
    print(itemName, ':', itemData.count)
end
```

## Notifications

ESX has its own notification system, but **USE OX_LIB** for notifications instead:

```lua
-- Use ox_lib for notifications (preferred)
lib.notify({
    title = 'Bank',
    description = 'You received $500',
    type = 'success'
})
```

## Input & Controls

### ESX.RegisterInput(command, label, inputGroup, key, onPress, onRelease)

Registers a keybind.

```lua
ESX.RegisterInput('openInventory', 'Open Inventory', 'keyboard', 'f2', 
    function()
        -- Key pressed
        print('Opening inventory')
    end, 
    function()
        -- Key released (optional)
        print('Closed inventory')
    end
)
```

### ESX.HashString(str)

Gets input hash/mapping for display (wrongly named, returns input label).

```lua
local inputLabel = ESX.HashString('openInventory')
ESX.ShowHelpNotification('Press ' .. inputLabel .. ' to open inventory', false, true, 3000)
```

## Spawn Management

### ESX.DisableSpawnManager()

Disables FiveM's default spawn manager.

```lua
ESX.DisableSpawnManager()
```

### ESX.SpawnPlayer(coords, heading, cb)

Spawns player at coords with optional callback.

```lua
local spawnCoords = vector4(100.0, 200.0, 50.0, 90.0)
ESX.SpawnPlayer(spawnCoords, function()
    print('Player spawned')
end)
```

## Coords & Position

### ESX.GetAccount(accountName)

Returns player's account data.

```lua
local bankAccount = ESX.GetAccount('bank')
print('Bank balance:', bankAccount.money)
```

## Vehicle Functions

### ESX.GetVehicleTypeClient(model)

Returns vehicle type for model.

```lua
local vehicleType = ESX.GetVehicleTypeClient('t20')
print('Vehicle type:', vehicleType) -- 'automobile', 'bike', 'boat', 'heli', etc.
```

## UI Components (Use ox_lib)

ESX has its own UI resources, but **USE OX_LIB** for all UI components:

```lua
-- Progress bars
if lib.progressBar({
    duration = 5000,
    label = 'Repairing vehicle...',
    useWhileDead = false,
    canCancel = true,
    disable = {
        car = true,
        move = true
    },
    anim = {
        dict = 'mini@repair',
        clip = 'fixing_a_player'
    }
}) then
    print('Repair complete')
end

-- Context menus
lib.registerContext({
    id = 'player_menu',
    title = 'Player Menu',
    options = {
        {
            title = 'Give Money',
            icon = 'dollar-sign',
            onSelect = function()
                -- Handle give money
            end
        },
        {
            title = 'Check ID',
            icon = 'id-card',
            onSelect = function()
                -- Handle check ID
            end
        }
    }
})

lib.showContext('player_menu')

-- Text UI
lib.showTextUI('[E] - Interact', {
    position = "right-center"
})

lib.hideTextUI()
```

## Best Practices

1. **Always check player loaded before using PlayerData**:
   ```lua
   if not ESX.IsPlayerLoaded() then return end
   ```

2. **Cache PlayerData locally when needed**:
   ```lua
   local job = ESX.PlayerData.job
   if job.name == 'police' then
       -- Do something
   end
   ```

3. **Use SecureNetEvent for events that modify player state**:
   ```lua
   -- CLIENT
   ESX.SecureNetEvent('myResource:serverAction', function(data)
       -- Safe to use, only server can trigger
   end)
   ```

4. **Search inventory before assuming item exists**:
   ```lua
   local item = ESX.SearchInventory('bread')
   if item and item.count > 0 then
       -- Player has bread
   end
   ```

5. **Use ox_lib for all UI**:
   ```lua
   -- Notifications
   lib.notify({title = 'Success', description = 'Action completed', type = 'success'})
   
   -- Progress bars
   lib.progressBar({duration = 5000, label = 'Working...'})
   
   -- Context menus
   lib.showContext('my_menu')
   ```
