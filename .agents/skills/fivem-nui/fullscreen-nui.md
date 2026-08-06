# Fullscreen NUI

Fullscreen NUI pages are the most common type of user interface in FiveM. They overlay on top of the game and can have input focus for mouse/keyboard interaction.

## Natives

Key natives for fullscreen NUI:

- **SEND_NUI_MESSAGE** / **SendNUIMessage** — Send data from Lua to the browser (JSON).
- **SET_NUI_FOCUS** — Control keyboard and mouse focus for the NUI page.

## Sending messages to NUI

Use `SendNUIMessage` to send data to your UI:

```lua
-- Lua example
SendNUIMessage({
    type = 'openMenu',
    data = {
        title = 'Shop',
        items = shopItems
    }
})
```

## Receiving messages in the browser

In your HTML/JavaScript, listen for messages using the `message` event:

```js
window.addEventListener('message', (event) => {
    const data = event.data;
    
    if (data.type === 'openMenu') {
        showMenu(data.data.title, data.data.items);
    }
});
```

## NUI Focus

Control focus with `SetNUIFocus`:

```lua
-- Enable both keyboard and mouse
SetNUIFocus(true, true)

-- Enable keyboard only (no cursor)
SetNUIFocus(true, false)

-- Disable focus completely
SetNUIFocus(false, false)
```

**Important:**
- The first parameter controls **keyboard focus**.
- The second parameter controls **mouse cursor** visibility and focus.
- Always disable focus when closing the UI to prevent input issues.

## Focus stack

FiveM maintains a focus stack for NUI resources:
- The most recently focused resource is on top.
- Resources are rendered as full-screen iframes.
- There's no click-through across resources.
- Only the current resource can control its own focus.

## Referencing assets

Use the `https://cfx-nui-{resourceName}/` protocol to reference resource files:

```html
<!-- Reference a JavaScript file in your resource -->
<script type="text/javascript" src="https://cfx-nui-my-resource/build/app.js"></script>

<!-- Reference a CSS file -->
<link rel="stylesheet" href="https://cfx-nui-my-resource/styles/main.css">

<!-- Reference an image -->
<img src="https://cfx-nui-my-resource/images/logo.png">
```

**Note:** The old `nui://` protocol is deprecated and no longer works in newer browser versions. Always use `https://cfx-nui-`.

## Developer tools

### Chrome DevTools

Access CEF remote debugging tools at [http://localhost:13172/](http://localhost:13172/) while the game is running. Use any Chromium-based browser.

### Console command

Alternatively, use the `nui_devTools` command in the F8 console (requires developer mode enabled).

## Example: Simple menu

**Lua (client.lua):**
```lua
local menuOpen = false

RegisterCommand('openmenu', function()
    menuOpen = true
    SetNUIFocus(true, true)
    SendNUIMessage({
        type = 'show',
        items = {
            {id = 1, name = 'Item 1', price = 100},
            {id = 2, name = 'Item 2', price = 200}
        }
    })
end)

RegisterNUICallback('close', function(data, cb)
    menuOpen = false
    SetNUIFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('buyItem', function(data, cb)
    print('Buying item:', data.itemId)
    -- Handle purchase logic
    cb({success = true, message = 'Purchase successful'})
end)
```

**HTML (ui/index.html):**
```html
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial; }
        #menu { display: none; background: rgba(0,0,0,0.8); color: white; padding: 20px; }
        .item { padding: 10px; cursor: pointer; }
        .item:hover { background: rgba(255,255,255,0.1); }
    </style>
</head>
<body>
    <div id="menu">
        <h2>Shop</h2>
        <div id="items"></div>
        <button onclick="closeMenu()">Close</button>
    </div>
    
    <script src="https://cfx-nui-my-resource/ui/app.js"></script>
</body>
</html>
```

**JavaScript (ui/app.js):**
```js
window.addEventListener('message', (event) => {
    if (event.data.type === 'show') {
        showMenu(event.data.items);
    }
});

function showMenu(items) {
    const menu = document.getElementById('menu');
    const itemsDiv = document.getElementById('items');
    
    itemsDiv.innerHTML = '';
    items.forEach(item => {
        const div = document.createElement('div');
        div.className = 'item';
        div.textContent = `${item.name} - $${item.price}`;
        div.onclick = () => buyItem(item.id);
        itemsDiv.appendChild(div);
    });
    
    menu.style.display = 'block';
}

function closeMenu() {
    document.getElementById('menu').style.display = 'none';
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

function buyItem(itemId) {
    fetch(`https://${GetParentResourceName()}/buyItem`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ itemId: itemId })
    }).then(resp => resp.json()).then(resp => {
        if (resp.success) {
            alert(resp.message);
        }
    });
}

function GetParentResourceName() {
    return window.location.hostname.replace('cfx-nui-', '');
}
```

## Reference

- Fullscreen NUI: https://docs.fivem.net/docs/scripting-manual/nui-development/full-screen-nui/
- SEND_NUI_MESSAGE: https://docs.fivem.net/natives/?_0x78608ACB
- SET_NUI_FOCUS: https://docs.fivem.net/natives/?_0x5B98AE30
