# Reference Links

Official documentation and useful resources for FiveM NUI development.

## Official FiveM Documentation

### NUI Development
- **NUI Overview**: https://docs.fivem.net/docs/scripting-manual/nui-development/
- **Fullscreen NUI**: https://docs.fivem.net/docs/scripting-manual/nui-development/full-screen-nui/
- **NUI Callbacks**: https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/
- **Loading Screens**: https://docs.fivem.net/docs/scripting-manual/nui-development/loading-screens/
- **Direct-rendered UI (DUI)**: https://docs.fivem.net/docs/scripting-manual/nui-development/dui/

### Natives Reference
- **SEND_NUI_MESSAGE**: https://docs.fivem.net/natives/?_0x78608ACB
- **SET_NUI_FOCUS**: https://docs.fivem.net/natives/?_0x5B98AE30
- **All Natives**: https://docs.fivem.net/natives/

### Scripting Manual
- **Creating Your First Script**: https://docs.fivem.net/docs/scripting-manual/introduction/creating-your-first-script/
- **Working with Events**: https://docs.fivem.net/docs/scripting-manual/working-with-events/
- **Resource Manifest**: https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/

### Lua Functions
- **RegisterNUICallback**: https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/RegisterNUICallback/
- **SendNUIMessage**: https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/SendNUIMessage/

## Security
- **Secure Your Events**: https://docs.fivem.net/docs/developers/server-security/

## Web Technologies

### HTML/CSS/JavaScript
- **MDN Web Docs**: https://developer.mozilla.org/
- **Fetch API**: https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API
- **Window.postMessage**: https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage

### Modern Frameworks
- **React**: https://react.dev/
- **Vue**: https://vuejs.org/
- **Svelte**: https://svelte.dev/
- **Vite**: https://vitejs.dev/

### CSS Frameworks
- **Tailwind CSS**: https://tailwindcss.com/
- **Bootstrap**: https://getbootstrap.com/

### TypeScript
- **TypeScript Documentation**: https://www.typescriptlang.org/docs/

## Build Tools
- **Vite**: https://vitejs.dev/
- **Webpack**: https://webpack.js.org/
- **npm**: https://www.npmjs.com/

## Community Resources

### Forums
- **FiveM Forums**: https://forum.cfx.re/
- **FiveM Discord**: https://discord.gg/fivem

### Code Examples
- **FiveM Cookbook**: https://docs.fivem.net/docs/cookbook/
- **GitHub - FiveM**: https://github.com/citizenfx/fivem

## Tools

### Debugging
- **Chrome DevTools**: http://localhost:13172/ (when game is running)
- **F8 Console**: In-game developer console

### Development
- **Visual Studio Code**: https://code.visualstudio.com/
- **Browser DevTools**: Built into Chrome, Firefox, Edge

## Additional Resources

### Performance
- **Web Performance**: https://web.dev/performance/
- **Chrome DevTools Performance**: https://developer.chrome.com/docs/devtools/performance/

### Accessibility
- **Web Accessibility**: https://www.w3.org/WAI/
- **ARIA**: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA

## Quick Reference Card

### Key Lua Functions
```lua
-- Send message to UI
SendNUIMessage({type = 'action', data = value})

-- Set focus
SetNUIFocus(hasKeyboardFocus, hasMouseFocus)

-- Register callback
RegisterNUICallback('callbackName', function(data, cb)
    cb(responseData)
end)
```

### Key JavaScript Patterns
```js
// Listen for messages
window.addEventListener('message', (event) => {
    // Handle event.data
});

// Call callback
fetch(`https://${GetParentResourceName()}/callbackName`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify(data)
});

// Get resource name
function GetParentResourceName() {
    return window.location.hostname.replace('cfx-nui-', '');
}
```

### Asset References
```html
<!-- Use https://cfx-nui-{resourceName}/ protocol -->
<script src="https://cfx-nui-my-resource/js/app.js"></script>
<link href="https://cfx-nui-my-resource/css/style.css" rel="stylesheet">
<img src="https://cfx-nui-my-resource/images/logo.png">
```
