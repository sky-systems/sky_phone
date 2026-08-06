# NUI Best Practices

Guidelines for building performant, secure, and maintainable NUI interfaces.

## Performance

### Minimize SendNUIMessage calls

❌ **Bad:**
```lua
-- Sending updates every frame (terrible for performance!)
CreateThread(function()
    while true do
        Wait(0)
        SendNUIMessage({
            type = 'updateSpeed',
            speed = GetEntitySpeed(PlayerPedId())
        })
    end
end)
```

✅ **Good:**
```lua
-- Only send when value changes significantly
local lastSpeed = 0
CreateThread(function()
    while true do
        Wait(100) -- Update every 100ms at most
        local currentSpeed = math.floor(GetEntitySpeed(PlayerPedId()) * 3.6) -- km/h
        
        if math.abs(currentSpeed - lastSpeed) >= 1 then
            lastSpeed = currentSpeed
            SendNUIMessage({
                type = 'updateSpeed',
                speed = currentSpeed
            })
        end
    end
end)
```

### Batch updates

❌ **Bad:**
```lua
SendNUIMessage({type = 'updateHealth', health = health})
SendNUIMessage({type = 'updateArmor', armor = armor})
SendNUIMessage({type = 'updateStamina', stamina = stamina})
```

✅ **Good:**
```lua
SendNUIMessage({
    type = 'updateStats',
    data = {
        health = health,
        armor = armor,
        stamina = stamina
    }
})
```

### Optimize DOM operations

❌ **Bad:**
```js
// Updating DOM on every message
window.addEventListener('message', (event) => {
    if (event.data.type === 'updateList') {
        const list = document.getElementById('list');
        list.innerHTML = ''; // Clears entire list
        
        event.data.items.forEach(item => {
            const div = document.createElement('div');
            div.textContent = item.name;
            list.appendChild(div); // Multiple reflows
        });
    }
});
```

✅ **Good:**
```js
// Using document fragment for batch DOM updates
window.addEventListener('message', (event) => {
    if (event.data.type === 'updateList') {
        const list = document.getElementById('list');
        const fragment = document.createDocumentFragment();
        
        event.data.items.forEach(item => {
            const div = document.createElement('div');
            div.textContent = item.name;
            fragment.appendChild(div);
        });
        
        list.innerHTML = '';
        list.appendChild(fragment); // Single reflow
    }
});
```

### Use CSS animations instead of JavaScript

❌ **Bad:**
```js
function fadeIn(element) {
    let opacity = 0;
    const interval = setInterval(() => {
        opacity += 0.1;
        element.style.opacity = opacity;
        if (opacity >= 1) clearInterval(interval);
    }, 50);
}
```

✅ **Good:**
```css
.fade-in {
    animation: fadeIn 0.5s ease-in;
}

@keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
}
```

```js
element.classList.add('fade-in');
```

## Security

### Always validate NUI callback data

❌ **Bad:**
```lua
RegisterNUICallback('transfer', function(data, cb)
    -- No validation!
    TriggerServerEvent('bank:server:transfer', data.target, data.amount)
    cb('ok')
end)
```

✅ **Good:**
```lua
RegisterNUICallback('transfer', function(data, cb)
    -- Validate all inputs
    if not data.target or type(data.target) ~= 'number' then
        cb({success = false, error = 'Invalid target'})
        return
    end
    
    if not data.amount or type(data.amount) ~= 'number' then
        cb({success = false, error = 'Invalid amount'})
        return
    end
    
    if data.amount <= 0 or data.amount > 1000000 then
        cb({success = false, error = 'Amount out of range'})
        return
    end
    
    -- Additional validation on server side
    TriggerServerEvent('bank:server:transfer', data.target, data.amount)
    cb({success = true})
end)
```

### Never trust client-side data on server

```lua
-- Server-side
RegisterNetEvent('shop:server:purchase')
AddEventHandler('shop:server:purchase', function(itemId, quantity, price)
    local src = source
    
    -- DON'T trust the price from client!
    -- Look it up server-side
    local actualPrice = Items[itemId].price
    local totalCost = actualPrice * quantity
    
    -- Validate and process...
end)
```

### Protect sensitive callbacks

```lua
RegisterNUICallback('adminAction', function(data, cb)
    -- Check if player has admin permissions server-side
    TriggerServerEvent('admin:server:checkPermission', data.action)
    cb('ok')
end)
```

## Communication patterns

### State management

Keep UI state synchronized:

```lua
-- client.lua
local currentUI = {
    visible = false,
    page = 'home',
    data = {}
}

function updateUI(updates)
    for k, v in pairs(updates) do
        currentUI[k] = v
    end
    
    SendNUIMessage({
        type = 'updateState',
        state = currentUI
    })
end

function openUI(page, data)
    updateUI({
        visible = true,
        page = page,
        data = data
    })
    SetNUIFocus(true, true)
end
```

### Event-driven updates

```lua
-- Update UI when game events happen
AddEventHandler('playerSpawned', function()
    SendNUIMessage({
        type = 'playerSpawned'
    })
end)

RegisterNetEvent('inventory:client:itemAdded')
AddEventHandler('inventory:client:itemAdded', function(item, count)
    SendNUIMessage({
        type = 'itemAdded',
        item = item,
        count = count
    })
end)
```

## Error handling

### Always handle callback responses

```lua
RegisterNUICallback('getData', function(data, cb)
    local success, result = pcall(function()
        return getSomeData(data.id)
    end)
    
    if success then
        cb({success = true, data = result})
    else
        print('Error in getData:', result)
        cb({success = false, error = 'Failed to get data'})
    end
end)
```

### Handle network errors in UI

```js
async function callbackWithRetry(name, data, maxRetries = 3) {
    for (let i = 0; i < maxRetries; i++) {
        try {
            const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify(data)
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }
            
            return await response.json();
        } catch (error) {
            console.error(`Attempt ${i + 1} failed:`, error);
            
            if (i === maxRetries - 1) {
                throw error; // Final attempt failed
            }
            
            // Wait before retry
            await new Promise(resolve => setTimeout(resolve, 1000));
        }
    }
}
```

## Code organization

### Separate concerns

**client.lua:**
```lua
-- UI management only
local UI = {}

function UI.open(page, data)
    SetNUIFocus(true, true)
    SendNUIMessage({type = 'open', page = page, data = data})
end

function UI.close()
    SetNUIFocus(false, false)
    SendNUIMessage({type = 'close'})
end

function UI.update(data)
    SendNUIMessage({type = 'update', data = data})
end

return UI
```

**main.lua:**
```lua
local UI = require('client')

-- Game logic
RegisterCommand('shop', function()
    local items = getShopItems()
    UI.open('shop', {items = items})
end)

RegisterNUICallback('buyItem', function(data, cb)
    local success = purchaseItem(data.itemId)
    cb({success = success})
end)
```

### Use TypeScript for complex UIs

**types.ts:**
```typescript
export interface PlayerData {
    name: string;
    id: number;
    health: number;
    armor: number;
}

export interface NUIMessage {
    type: 'show' | 'hide' | 'update';
    data?: any;
}

export interface NUICallback<T = any> {
    success: boolean;
    data?: T;
    error?: string;
}
```

**app.ts:**
```typescript
import { PlayerData, NUIMessage, NUICallback } from './types';

window.addEventListener('message', (event: MessageEvent<NUIMessage>) => {
    const { type, data } = event.data;
    
    switch (type) {
        case 'show':
            showUI(data as PlayerData);
            break;
        // ...
    }
});

async function getData<T>(endpoint: string, payload: any): Promise<NUICallback<T>> {
    const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(payload)
    });
    
    return response.json();
}
```

## Accessibility

### Keyboard navigation

```js
document.addEventListener('keydown', (event) => {
    switch(event.key) {
        case 'Escape':
            closeUI();
            break;
        case 'ArrowUp':
            navigateUp();
            break;
        case 'ArrowDown':
            navigateDown();
            break;
        case 'Enter':
            selectCurrent();
            break;
    }
});
```

### Focus management

```js
function showUI() {
    const ui = document.getElementById('ui');
    ui.classList.add('visible');
    
    // Focus first interactive element
    const firstInput = ui.querySelector('input, button, [tabindex]');
    if (firstInput) {
        firstInput.focus();
    }
}
```

## Testing

### Mock mode for browser testing

```js
// Check if running in game or browser
const isDevelopment = !window.invokeNative;

if (isDevelopment) {
    // Mock data for testing
    setTimeout(() => {
        window.dispatchEvent(new MessageEvent('message', {
            data: {
                type: 'show',
                data: {
                    items: [
                        { id: 1, name: 'Test Item 1', price: 100 },
                        { id: 2, name: 'Test Item 2', price: 200 }
                    ]
                }
            }
        }));
    }, 1000);
}

// Mock fetch for testing
function mockFetch(url, options) {
    console.log('Mock fetch:', url, options);
    return Promise.resolve({
        ok: true,
        json: () => Promise.resolve({ success: true, data: {} })
    });
}

const fetchFn = isDevelopment ? mockFetch : fetch;
```

## Reference

- Performance tips: https://docs.fivem.net/docs/scripting-manual/nui-development/
- Security guide: https://docs.fivem.net/docs/developers/server-security/
