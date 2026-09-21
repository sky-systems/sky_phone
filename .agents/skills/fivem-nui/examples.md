# Worked NUI integration examples

Load the relevant example when implementing a route. These examples show the client/browser boundary; they do not grant server permissions. In an existing resource, adapt its transport, shared controls and locales rather than installing a second framework. The English labels below are demonstration text to replace with the resource's locale values.

## Complete local panel: package, open, hydrate and close

This small panel changes only its own visibility. It works without a server script. The three files below belong beside `client.lua` in `html/`; open it with the illustrative `nui_example` client command. Check the [pinned API/source contracts](reference-links.md) and test in the actual target client before shipping.

```text
resource/
  fxmanifest.lua
  client.lua
  html/
    index.html
    style.css
    app.js
```

```lua
-- fxmanifest.lua
fx_version "cerulean"
game "gta5"
client_script "client.lua"
ui_page "html/index.html"
files { "html/index.html", "html/style.css", "html/app.js" }
```

```html
<!-- html/index.html -->
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="./style.css">
    <script src="./app.js" defer></script>
    <title>NUI example</title>
</head>
<body>
    <section id="panel" role="dialog" aria-labelledby="title" hidden>
        <h1 id="title">Example panel</h1>
        <p id="status" role="status"></p>
        <button id="close" type="button">Close</button>
    </section>
</body>
</html>
```

```css
/* html/style.css */
* { box-sizing: border-box; }
html, body { margin: 0; width: 100%; height: 100%; background: transparent; }
body { overflow: hidden; pointer-events: none; font-family: sans-serif; }
#panel {
    position: absolute;
    right: 2rem;
    top: 2rem;
    width: min(24rem, calc(100vw - 4rem));
    max-height: calc(100vh - 4rem);
    overflow: auto;
    padding: 1rem;
    color: white;
    background: #20242b;
    pointer-events: auto;
}
#panel[hidden] { display: none; }
button { min-height: 44px; }
button:focus-visible { outline: 2px solid white; outline-offset: 3px; }
```

```lua
-- client.lua
local visible = false
local revision = 0

local function set_visible(next_visible)
    visible = next_visible
    revision = revision + 1
    SetNUIFocus(visible, visible)
    SendNUIMessage({ type = "state", visible = visible, revision = revision })
end

RegisterCommand("nui_example", function()
    set_visible(true)
end, false)

RegisterNUICallback("ready", function(data, cb)
    if type(data) ~= "table" or data.protocolVersion ~= 1 then
        print("[nui] ready rejected: unsupported protocol")
        cb({ ok = false, error = "unsupported_protocol" })
        return
    end
    cb({ ok = true, state = { type = "state", visible = visible, revision = revision } })
end)

RegisterNUICallback("close", function(_, cb)
    set_visible(false)
    cb({ ok = true })
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name == GetCurrentResourceName() then
        SetNUIFocus(false, false)
    end
end)
```

```js
// html/app.js
const panel = document.querySelector("#panel");
const closeButton = document.querySelector("#close");
const status = document.querySelector("#status");
const lifetime = new AbortController();
let revision = -1;
let closing = false;

async function postNui(route, data) {
    const response = await fetch(`https://${GetParentResourceName()}/${route}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data),
        signal: lifetime.signal,
    });
    if (!response.ok) throw new Error(`${route}: HTTP ${response.status}`);
    const result = await response.json();
    if (result.ok !== true) throw new Error(`${route}: ${result.error}`);
    return result;
}

function applyState(state) {
    if (!state || state.type !== "state" || typeof state.visible !== "boolean"
        || !Number.isInteger(state.revision) || state.revision <= revision) return;
    revision = state.revision;
    const opening = panel.hidden && state.visible;
    panel.hidden = !state.visible;
    if (opening) {
        status.textContent = "";
        closeButton.focus();
    }
}

async function closePanel() {
    if (closing || panel.hidden) return;
    closing = true;
    try {
        await postNui("close", {});
    } catch (error) {
        if (!lifetime.signal.aborted) {
            console.error("NUI close failed", error);
            status.textContent = "Could not close. Use the close button again.";
        }
    } finally {
        closing = false;
    }
}

window.addEventListener("message", event => applyState(event.data), { signal: lifetime.signal });
closeButton.addEventListener("click", closePanel, { signal: lifetime.signal });
document.addEventListener("keydown", event => {
    if (panel.hidden) return;
    if (event.key === "Escape") {
        event.preventDefault();
        void closePanel();
    } else if (event.key === "Tab") {
        // This demonstration panel has one control; a real modal uses its focus manager.
        event.preventDefault();
        closeButton.focus();
    }
}, { signal: lifetime.signal });
window.addEventListener("pagehide", () => lifetime.abort(), { once: true });

// Listener is installed before readiness. A newer message wins over an older ready reply.
postNui("ready", { protocolVersion: 1 }).then(result => applyState(result.state)).catch(error => {
    if (!lifetime.signal.aborted) console.error("NUI initialization failed", error);
});
```

The request helper performs transport/status/error work; it is not a one-line alias. Do not add automatic retries for arbitrary POSTs. A production transport should implement its established bounded timeout and localized error UI. A browser reload gets a fresh snapshot. This local example has no outstanding server requests; server-backed screens also need their existing session/generation checks after every await. If keep-input is used, clear that flag on close/stop as described in the CEF focus reference.

## Callback response shapes and errors

Prefer an explicit discriminated response for the existing route. TypeScript types document a shape; they do not validate received JSON or authorize input.

```ts
type ItemInfo = { id: string; label: string };
type ItemReply = { ok: true; data: ItemInfo } | { ok: false; error: string };

async function loadItem(itemId: string): Promise<ItemReply> {
    const response = await fetch(`https://${GetParentResourceName()}/itemInfo`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ itemId }),
    });
    if (!response.ok) throw new Error(`itemInfo: HTTP ${response.status}`);
    return await response.json() as ItemReply;
}
```

```lua
-- item_catalog is the existing client display catalogue, not authoritative inventory.
RegisterNUICallback("itemInfo", function(data, cb)
    if type(data) ~= "table" or type(data.itemId) ~= "string" then
        print("[nui] itemInfo rejected: invalid itemId")
        cb({ ok = false, error = "invalid_item_id" })
        return
    end
    local item = item_catalog[data.itemId]
    if not item then
        print("[nui] itemInfo rejected: item not in display catalogue")
        cb({ ok = false, error = "item_not_found" })
        return
    end
    cb({ ok = true, data = { id = data.itemId, label = item.label } })
end)
```

At the owning UI action, handle both a rejected promise and `{ ok = false }`, mapping the code to localized feedback. When adapting this to a mutation, return the real server result through the resource's existing bridge. A dispatch-only response must be `{ status = "accepted" }` (or the existing equivalent), followed by a correlated result; it must not say that payment or delivery succeeded. See [callback authority](nui-callbacks.md#server-mutations).

## Coherent updates and safe DOM rendering

Batch related values when they describe the same UI state:

```lua
SendNUIMessage({
    type = "stats",
    data = { health = health, armor = armor, stamina = stamina }
})
```

For sampled data, compare the relevant value/revision before emitting. The initial snapshot still needs a value even if it is zero. Choose cadence from interaction needs and profiling; the former example's 100 ms was not a universal rule. Prefer the existing owner event for values already updated by events.

```js
// rows have already passed the resource's display-schema validation.
const fragment = document.createDocumentFragment();
for (const row of rows) {
    const item = document.createElement("li");
    item.textContent = row.label; // Player-provided strings are text, not HTML.
    fragment.appendChild(item);
}
list.replaceChildren(fragment);
```

A fragment makes a coherent replacement; it does not prove exactly one reflow or a universal speedup. For large lists use the framework's stable keys/virtualization and profile the actual rendering path.

```css
.panel-enter { animation: panel-enter 150ms ease-out; }
@keyframes panel-enter { from { opacity: 0; } to { opacity: 1; } }
@media (prefers-reduced-motion: reduce) { .panel-enter { animation: none; } }
```

Use supported opacity/transform transitions for simple effects instead of adding an interval solely for a fade. Canvas/game timing may still require JavaScript; neither approach is automatically faster. Keyboard and focus behavior belong to shared controls where available.

## Explicit desktop preview

Keep browser fixtures in a development-only entrypoint or the existing preview transport. For example, after mounting the UI's listener, dispatch a deterministic state fixture rather than waiting an arbitrary second:

```js
window.dispatchEvent(new MessageEvent("message", {
    data: { type: "state", visible: true, revision: 1 },
}));
```

Mock both success and error results in that preview transport. Do not replace production `fetch`, invent `GetParentResourceName`, or infer an authorization mode from `window.invokeNative`. Browser mocks cover presentation/request shape only; final FiveM routing, focus and server outcomes need their own checks.
