# NUI Callbacks

NUI callbacks allow the browser (UI) to send data back to the game and receive responses. They work like HTTP endpoints that your UI can call.

## Registering callbacks in Lua

Use `RegisterNUICallback` to create a callback endpoint:

```lua
RegisterNUICallback('getPlayerData', function(data, cb)
    -- data contains the POST body parsed as JSON
    local requestedData = data.dataType
    
    -- Perform logic
    local playerData = {
        name = GetPlayerName(PlayerId()),
        health = GetEntityHealth(PlayerPedId()),
        position = GetEntityCoords(PlayerPedId())
    }
    
    -- ALWAYS call the callback (cb) to prevent request stalling
    cb(playerData)
end)
```

**Important:**
- The `data` parameter contains the POST body automatically parsed as JSON.
- The `cb` function must ALWAYS be called, even if just with `{}` or `{ok = true}`.
- Failing to call `cb` will cause the browser request to hang indefinitely.

## Calling callbacks from the browser

Use `fetch` to call a callback from your JavaScript:

```js
// Get the current resource name
function GetParentResourceName() {
    return window.location.hostname.replace('cfx-nui-', '');
}

// Call the callback
fetch(`https://${GetParentResourceName()}/getPlayerData`, {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify({
        dataType: 'basic'
    })
})
.then(resp => resp.json())
.then(data => {
    console.log('Player data:', data);
    // Use the data in your UI
    document.getElementById('player-name').textContent = data.name;
})
.catch(err => {
    console.error('Error fetching player data:', err);
});
```

## Callback naming

The callback name in the URL must match the name you registered:

```lua
-- Lua
RegisterNUICallback('buyItem', function(data, cb)
    -- ...
end)
```

```js
// Browser
fetch(`https://${GetParentResourceName()}/buyItem`, {
    method: 'POST',
    // ...
})
```

## Complete example: Item purchase

**Lua (client.lua):**
```lua
RegisterNUICallback('purchaseItem', function(data, cb)
    local itemId = data.itemId
    local quantity = data.quantity or 1
    
    -- Validate input
    if not itemId then
        cb({success = false, error = 'Item ID required'})
        return
    end
    
    -- Trigger server-side purchase
    TriggerServerEvent('shop:server:purchase', itemId, quantity)
    
    -- Wait for server response (you'd typically use a callback pattern)
    -- For this example, we'll return immediately
    cb({
        success = true,
        message = 'Purchase request sent',
        itemId = itemId,
        quantity = quantity
    })
end)

-- Handle server response
RegisterNetEvent('shop:client:purchaseResult')
AddEventHandler('shop:client:purchaseResult', function(success, message)
    SendNUIMessage({
        type = 'purchaseResult',
        success = success,
        message = message
    })
end)
```

**JavaScript (ui/shop.js):**
```js
function purchaseItem(itemId, quantity) {
    fetch(`https://${GetParentResourceName()}/purchaseItem`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            itemId: itemId,
            quantity: quantity
        })
    })
    .then(resp => resp.json())
    .then(data => {
        if (data.success) {
            showNotification(data.message, 'success');
        } else {
            showNotification(data.error, 'error');
        }
    })
    .catch(err => {
        console.error('Purchase error:', err);
        showNotification('Purchase failed', 'error');
    });
}

// Listen for server response
window.addEventListener('message', (event) => {
    if (event.data.type === 'purchaseResult') {
        if (event.data.success) {
            showNotification('Purchase successful!', 'success');
        } else {
            showNotification(event.data.message, 'error');
        }
    }
});
```

## Async/await pattern

For cleaner code, use async/await:

```js
async function getPlayerData() {
    try {
        const response = await fetch(`https://${GetParentResourceName()}/getPlayerData`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                dataType: 'full'
            })
        });
        
        const data = await response.json();
        return data;
    } catch (error) {
        console.error('Failed to get player data:', error);
        return null;
    }
}

// Usage
async function updateUI() {
    const playerData = await getPlayerData();
    if (playerData) {
        renderPlayerInfo(playerData);
    }
}
```

## Error handling

Always handle errors properly:

**Lua:**
```lua
RegisterNUICallback('risky_operation', function(data, cb)
    local success, result = pcall(function()
        -- Your risky operation
        return doSomethingRisky(data)
    end)
    
    if success then
        cb({success = true, data = result})
    else
        cb({success = false, error = 'Operation failed: ' .. tostring(result)})
    end
end)
```

**JavaScript:**
```js
async function performRiskyOperation() {
    try {
        const response = await fetch(`https://${GetParentResourceName()}/risky_operation`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({})
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        
        if (!data.success) {
            throw new Error(data.error || 'Operation failed');
        }
        
        return data.data;
    } catch (error) {
        console.error('Operation failed:', error);
        showNotification('Something went wrong', 'error');
        return null;
    }
}
```

## Security considerations

### Always validate data

```lua
RegisterNUICallback('setPlayerName', function(data, cb)
    -- Validate input
    if not data.name or type(data.name) ~= 'string' then
        cb({success = false, error = 'Invalid name'})
        return
    end
    
    -- Sanitize input
    local name = data.name:gsub('[^%w%s]', '') -- Remove special characters
    if #name < 3 or #name > 32 then
        cb({success = false, error = 'Name must be 3-32 characters'})
        return
    end
    
    -- Proceed with validated data
    TriggerServerEvent('player:server:setName', name)
    cb({success = true})
end)
```

### Don't trust client data

Always validate and verify on the server:

```lua
-- Client
RegisterNUICallback('buyItem', function(data, cb)
    TriggerServerEvent('shop:server:buyItem', data.itemId, data.quantity)
    cb({ok = true})
end)

-- Server
RegisterNetEvent('shop:server:buyItem')
AddEventHandler('shop:server:buyItem', function(itemId, quantity)
    local src = source
    
    -- Validate item exists
    if not Items[itemId] then
        return
    end
    
    -- Validate quantity
    if type(quantity) ~= 'number' or quantity < 1 or quantity > 100 then
        return
    end
    
    -- Check player has enough money
    local player = GetPlayer(src)
    local price = Items[itemId].price * quantity
    
    if player.getMoney() >= price then
        player.removeMoney(price)
        player.addItem(itemId, quantity)
        TriggerClientEvent('shop:client:purchaseResult', src, true, 'Purchase successful')
    else
        TriggerClientEvent('shop:client:purchaseResult', src, false, 'Not enough money')
    end
end)
```

## Reference

- NUI Callbacks: https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/
- RegisterNUICallback: https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/RegisterNUICallback/
