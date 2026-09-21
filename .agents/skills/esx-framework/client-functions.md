# Client state and presentation

At the inspected revision, ESX.IsPlayerLoaded() returns ESX.PlayerLoaded, and
ESX.GetPlayerData() returns the current ESX.PlayerData table. The returned table is not an
authoritative server permission record. Account/inventory UI may be stale; server mutations
must re-resolve their own state.

Use the resource's established lifecycle to initialize after load and clear/reinitialize on
character changes. Do not add an unconditional wait loop to every consumer. Verify specialized
APIs such as inventory search, spawn management or input helpers against the installed source
instead of copying a generic function catalog.

ESX.SecureNetEvent(name, callback) filters event origin on the client at the inspected version.
It cannot protect server economy state from a compromised client. See [event contracts](events-callbacks.md).

Preserve the chosen UI integration. When the applicable AGENTS.md requires Sky UI helpers and
shared tablet controls, use them and localize user-facing copy. In standalone resources,
ox_lib is an option where already adopted, not a mandatory replacement for all interfaces.

[Verified client implementation and docs entry](reference-links.md).

## State, accounts and inventory examples

Direct ESX calls are for the existing adapter/direct integration. If AGENTS requires the Sky bridge, keep its PlayerCache/framework/UI contracts instead.

```lua
if ESX.IsPlayerLoaded() then
    local player_data = ESX.GetPlayerData()
    local bank = ESX.GetAccount("bank")
    if bank then
        print(("[example] local bank display: %s"):format(bank.money))
    end
end

-- Presentation-only data; this is not a server persistence operation.
ESX.SetPlayerData("example_view", { page = "home" })
```

`SetPlayerData(key, value)` updates the local table and emits `esx:setPlayerData(key, value, old)` for changed scalar/table values, except `loadout`. Imports already own their data synchronization; prefer resource-owned UI state for unrelated screen settings.

```lua
local bread = ESX.SearchInventory("bread")
if bread and bread.count > 0 then
    print(("[example] bread display count: %s"):format(bread.count))
end

local bread_count = ESX.SearchInventory("bread", true) -- number or nil
local counts = ESX.SearchInventory({ "bread", "water" }, true)
for item_name, count in pairs(counts) do
    print(("[example] %s display count: %s"):format(item_name, count))
end
```

`SearchInventory(items, count?)` returns one record/count for a string, or a map for a list. **At the pinned revision it removes matched entries from the supplied list**, so pass a new list or copy when the caller must retain it. Missing items may be absent/nil. A custom inventory may replace this path entirely. Client counts remain unsuitable for granting or consuming items.

## Keybind and vehicle helpers

```lua
ESX.RegisterInput("example_panel", localized_open_label, "keyboard", "F2", function()
    print("[example] panel key pressed")
end, function()
    print("[example] panel key released")
end)

local control_token = ESX.HashString("example_panel")
local vehicle_type = ESX.GetVehicleTypeClient("t20")
```

`RegisterInput(command, label, mapper, key, on_press, on_release?)` delegates to xLib's keybind definition at this revision. Preserve existing input ownership and localization. `HashString` returns a formatted `~INPUT_...~` token, not a translated key label. `GetVehicleTypeClient(model)` accepts a model string/hash and returns a category string or `false` for unavailable/non-vehicle models; it does not accept a vehicle entity handle. Native model checks behind the helper are engine boundaries, not proven runtime compatibility for an arbitrary add-on model.

## Spawn management

```lua
-- Only within the resource that actually owns character spawning, in a yieldable context.
ESX.DisableSpawnManager()
ESX.SpawnPlayer(skin, { x = 100.0, y = 200.0, z = 50.0, heading = 90.0 }, function()
    print("[example] provider spawn callback completed")
end)
```

The pinned signature is `SpawnPlayer(skin, coords, cb)`, and `coords.heading` is read explicitly. The old `(coords, heading, cb)` description and `vector4 + callback` example were incompatible with it. It awaits the skin load, invokes collision/spawn natives, and calls its callback; inspect the installed character/spawn owner's additional freeze/loadout/fade lifecycle before using it. A sample callback completing is not evidence that every surrounding initialization step is done.

## UI integration options

The existing provider determines which UI to use. Relevant ESX calls remain available where their required resources are installed:

| API | Arguments / provider |
|---|---|
| `ESX.ShowNotification` | `(message, type?, length?, title?, position?)`, forwards to `esx_notify` |
| `ESX.ShowAdvancedNotification` | `(sender, subject, message, texture_dict, icon_type, flash?, save_to_brief?, hud_color?)` |
| `ESX.ShowHelpNotification` | `(message, this_frame?, beep?, duration?)` |
| `ESX.Progressbar`, `ESX.CancelProgressbar` | `(message, length?, options?)` / `()`, `esx_progressbar`; result is the provider's creation result, not automatically task completion |
| `ESX.TextUI`, `ESX.HideUI` | Provider-specific text UI arguments / `()`, `esx_textui` |
| `ESX.OpenContext`, `PreviewContext`, `CloseContext`, `RefreshContext` | Forwarded context contracts; inspect installed `esx_context` before relying on options |

```lua
ESX.ShowNotification(localized_message, "info", 3000, localized_title, "top-right")
```

If ox_lib is already the selected provider, [its UI reference](../oxlib/interface.md) covers notification, progress, context/menu and TextUI options. Do not replace an existing UI merely because a generic example uses ox_lib. Keep localization, cancellation, controls/animations and success-after-authoritative-completion behavior. For source/target/server event examples see [events and callbacks](events-callbacks.md).
