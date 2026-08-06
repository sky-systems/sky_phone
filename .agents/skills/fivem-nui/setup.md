# Setting up NUI in a Resource

This guide covers the basic setup for adding a NUI interface to your FiveM resource.

## Folder structure

Recommended folder structure for a resource with NUI:

```
my-resource/
├── fxmanifest.lua
├── client.lua
├── server.lua
└── ui/
    ├── index.html
    ├── css/
    │   └── style.css
    ├── js/
    │   └── app.js
    └── images/
        └── logo.png
```

## fxmanifest.lua configuration

You need to specify the `ui_page` and include all UI files in the `files` array:

```lua
fx_version 'cerulean'
game 'gta5'

author 'Your Name'
description 'Resource with NUI'
version '1.0.0'

-- Client-side Lua script
client_script 'client.lua'

-- Server-side Lua script
server_script 'server.lua'

-- Specify the root UI page
ui_page 'ui/index.html'

-- All UI files must be included in files array
files {
    'ui/index.html',
    'ui/css/style.css',
    'ui/js/app.js',
    'ui/images/logo.png'
}
```

### Using wildcards

You can use wildcards for convenience:

```lua
ui_page 'ui/index.html'

files {
    'ui/**/*.*'  -- Include all files recursively in ui folder
}
```

## External hosting

You can also host the UI externally:

```lua
ui_page 'https://ui-frontend.example.com/v1.0.0/index.html'

-- No files array needed for external hosting
```

**Benefits:**
- Faster updates without resource restart
- Can use modern build tools and CI/CD
- Reduces resource download size

**Considerations:**
- Requires external web hosting
- Players need internet connection
- Potential latency for initial load

## Basic HTML structure

**ui/index.html:**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My Resource UI</title>
    <link rel="stylesheet" href="https://cfx-nui-my-resource/ui/css/style.css">
</head>
<body>
    <div id="app">
        <!-- Your UI content here -->
    </div>
    
    <script src="https://cfx-nui-my-resource/ui/js/app.js"></script>
</body>
</html>
```

## Basic CSS

**ui/css/style.css:**
```css
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    overflow: hidden;
}

#app {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    display: none; /* Hidden by default */
}

#app.visible {
    display: flex;
    justify-content: center;
    align-items: center;
}
```

## Basic JavaScript

**ui/js/app.js:**
```js
// Helper to get resource name
function GetParentResourceName() {
    return window.location.hostname.replace('cfx-nui-', '');
}

// Listen for messages from Lua
window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch(data.type) {
        case 'show':
            showUI(data.data);
            break;
        case 'hide':
            hideUI();
            break;
        case 'update':
            updateUI(data.data);
            break;
    }
});

// Show the UI
function showUI(data) {
    const app = document.getElementById('app');
    app.classList.add('visible');
    
    // Populate UI with data
    if (data) {
        // Handle data...
    }
}

// Hide the UI
function hideUI() {
    const app = document.getElementById('app');
    app.classList.remove('visible');
}

// Update UI content
function updateUI(data) {
    // Update logic...
}

// Close UI and notify Lua
function closeUI() {
    hideUI();
    
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({})
    });
}

// ESC key to close
document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        closeUI();
    }
});
```

## Basic Lua client script

**client.lua:**
```lua
local uiOpen = false

-- Command to open UI
RegisterCommand('openui', function()
    openUI()
end)

-- Open the UI
function openUI()
    if uiOpen then return end
    
    uiOpen = true
    SetNUIFocus(true, true)
    
    SendNUIMessage({
        type = 'show',
        data = {
            title = 'My UI',
            content = 'Hello from FiveM!'
        }
    })
end

-- Close the UI
function closeUI()
    if not uiOpen then return end
    
    uiOpen = false
    SetNUIFocus(false, false)
    
    SendNUIMessage({
        type = 'hide'
    })
end

-- Handle close callback from NUI
RegisterNUICallback('close', function(data, cb)
    closeUI()
    cb('ok')
end)

-- Example: Update UI with server data
RegisterNetEvent('myresource:client:updateUI')
AddEventHandler('myresource:client:updateUI', function(newData)
    SendNUIMessage({
        type = 'update',
        data = newData
    })
end)
```

## Modern build tools

For production applications, consider using modern build tools:

### Using Vite

**package.json:**
```json
{
  "name": "my-resource-ui",
  "version": "1.0.0",
  "scripts": {
    "dev": "vite",
    "build": "vite build"
  },
  "devDependencies": {
    "vite": "^5.0.0"
  }
}
```

**vite.config.js:**
```js
import { defineConfig } from 'vite'

export default defineConfig({
  base: './',
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    assetsInlineLimit: 0
  }
})
```

**fxmanifest.lua:**
```lua
ui_page 'ui/dist/index.html'

files {
    'ui/dist/**/*'
}
```

### Using React

```bash
npm create vite@latest ui -- --template react
cd ui
npm install
npm run build
```

### Using Vue

```bash
npm create vite@latest ui -- --template vue
cd ui
npm install
npm run build
```

## Testing during development

1. **Browser testing:** Open `ui/index.html` directly in your browser for quick UI testing.
2. **Mock data:** Create mock data in your JavaScript for testing without running the game.
3. **Hot reload:** Use Vite or similar tools for hot module replacement during development.
4. **DevTools:** Use `http://localhost:13172/` while the game is running to debug the live NUI.

## Common mistakes

### Forgetting to add files to manifest

❌ **Wrong:**
```lua
ui_page 'ui/index.html'
-- Missing files array!
```

✅ **Correct:**
```lua
ui_page 'ui/index.html'
files {
    'ui/index.html',
    'ui/css/style.css',
    'ui/js/app.js'
}
```

### Wrong asset references

❌ **Wrong:**
```html
<script src="./app.js"></script>
<script src="/ui/app.js"></script>
<script src="nui://my-resource/ui/app.js"></script>
```

✅ **Correct:**
```html
<script src="https://cfx-nui-my-resource/ui/app.js"></script>
```

### Not disabling focus

❌ **Wrong:**
```lua
-- User closes UI but focus is still active
-- Now they can't move or shoot!
```

✅ **Correct:**
```lua
RegisterNUICallback('close', function(data, cb)
    SetNUIFocus(false, false) -- Always disable focus!
    cb('ok')
end)
```

## Reference

- Resource Manifest: https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/
- Fullscreen NUI: https://docs.fivem.net/docs/scripting-manual/nui-development/full-screen-nui/
