# Messages and Fullscreen Focus

Read this for game-to-browser state, show/close behavior and focus ownership. Inspect the existing resource protocol before adding messages or another focus controller.

## Message contract

The Lua convenience wrapper encodes a table:

```lua
SendNUIMessage({
    type = "state",
    revision = revision,
    data = ui_state
})
```

The raw `SEND_NUI_MESSAGE` native takes a JSON string. The Lua wrapper does not return the native's result. Neither form acknowledges that the application's listener/store is ready. Register browser listeners first, signal readiness and hydrate a complete snapshot; rehydrate after reload. Retain revision/session ownership when asynchronous replies can arrive after a close/reopen or selection change.

Use a small explicit message protocol. Validate message shape before updating UI state. Keep authoritative identity, permissions, balances, inventory and prices on the game/server side. Browser state is a projection that can be rebuilt.

## Focus ownership

`SET_NUI_FOCUS` accepts keyboard-focus and cursor booleans. Manage open/close through the resource's existing focus owner, including error and resource-stop cleanup. FiveM maintains focus across resources, so avoid scattered independent focus toggles. Do not assume a lower resource receives click-through from another fullscreen UI.

```lua
SetNUIFocus(true, true)   -- Keyboard focus and cursor
SetNUIFocus(true, false)  -- Keyboard focus without cursor
SetNUIFocus(false, false) -- Release this resource's focus
```

The most recently focused resource is on top of the limited focus stack; resource pages are fullscreen frames. These calls control the invoking resource, not another resource's focus. DOM `element.focus()` selects a control within the page and does not replace game-side focus. The [complete panel example](examples.md#complete-local-panel-package-open-hydrate-and-close) shows both sides together.

Handle Escape in the DOM while NUI owns keyboard input, then call the close route. Complete that callback and release the resource's focus. A hidden fullscreen root must be transparent and noninteractive; scope pointer handling to the visible panel.

If a feature intentionally keeps game input, verify the target `SET_NUI_FOCUS_KEEP_INPUT` implementation and suppress only controls that would create unsafe gameplay actions during that interaction. Select mouse/controller/FPS/alt-tab cases according to the changed input path. A layout-only adjustment does not need every input mode retested.

## Lifecycle and verification

Own and dispose listeners, timers, observers, requests, media and framework subscriptions. Do not send unchanged full state every tick. Choose update rate/payload from the feature and measured behavior, not a universal delay constant.

Check open/close and affected routes; add reload/resource-stop and stale-response cases when lifecycle or transport changes. For full compatibility, phone scaling or media work, consult the relevant `fivem-cef-rules` reference when available. Distinguish browser preview, built/copy-verified files and actual FiveM tests.

Sources: [fullscreen NUI](https://docs.fivem.net/docs/scripting-manual/nui-development/full-screen-nui/) and [source/binding map](reference-links.md).

## Live developer tools

With FiveM running, inspect the intended resource frame through `http://localhost:13172/` in a Chromium browser, or `nui_devTools` in F8 with developer mode enabled. Use Console for boot/callback errors and Network for final asset URLs, status and MIME. Desktop DevTools on a preview page inspect a different runtime. The CEF testing reference keeps the full blank-page diagnostic sequence and release matrix.
