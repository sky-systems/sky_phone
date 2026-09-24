# Callback contracts

| Side | Call |
| --- | --- |
| Client invokes server | lib.callback(name, delay, callback, ...) or lib.callback.await(name, delay, ...) |
| Server registers request | lib.callback.register(name, handler); handler receives source, then request arguments |
| Server invokes client | lib.callback(name, playerId, callback, ...) or lib.callback.await(name, playerId, ...) |
| Client registers request | lib.callback.register(name, handler); handler receives the request arguments |

The second client argument is delay in milliseconds or false; on the server it is the target
player ID. Do not swap these signatures. Registered handlers return results; they do not use
ESX's compatibility reply-callback convention. Use unique names owned by the resource.

Await yields the current scheduler coroutine. At the inspected revision it can reject for an
invalid callback or timeout; handle the installed contract rather than assuming nil. Capture
raw event source before asynchronous work; callback handler parameters are already local.

The delay is stored client-side and can be bypassed. Server permissions, input bounds, rate
limits and once-only state transitions still belong to the authoritative operation. Responses
from a client cannot authorize money/items/ownership. Keep the resource's existing Sky.Cb
instead when its applicable AGENTS.md requires that bridge.

[Client docs](https://overextended.dev/docs/ox_lib/Callback/Lua/Client),
[server docs](https://overextended.dev/docs/ox_lib/Callback/Lua/Server), [source](sources.md).

## Complete client-to-server pair

Direct integration example: request a public catalog price. It intentionally performs no
purchase. A later purchase must independently validate the authoritative catalog/state.

```lua
-- server.lua
local catalog = { repair_kit = { price = 120 } }

lib.callback.register("example:catalogPrice", function(source, item_name)
    if type(item_name) ~= "string" or not catalog[item_name] then
        print(("[catalogPrice] Rejected invalid item from %s"):format(source))
        return { ok = false, error = "unknown_item" }
    end
    return { ok = true, price = catalog[item_name].price }
end)
```

```lua
-- client.lua, inside the resource's existing coroutine/action handler
local response = lib.callback.await("example:catalogPrice", 500, "repair_kit")
if response and response.ok then
    print(("Catalog price: %s"):format(response.price))
end

-- Alternative callback style; choose one form for the actual request.
lib.callback("example:catalogPrice", false, function(result)
    if result and result.ok then
        print(("Catalog price: %s"):format(result.price))
    end
end, "repair_kit")
```

The client delay may suppress a request; do not treat a missing result as a completed
operation. Invalid callback names/timeouts can raise through the provider's promise.

## Complete server-to-client pair

Use client replies only for untrusted presentation/diagnostic state:

```lua
-- client.lua; update this variable from the actual panel lifecycle.
local panel_open = false
lib.callback.register("example:panelStatus", function()
    return { open = panel_open }
end)
```

```lua
-- server.lua; player_id is the explicitly selected connected player.
local response = lib.callback.await("example:panelStatus", player_id)
print(("Client reported panel open: %s"):format(response and response.open))

-- Callback alternative: the second argument is player_id, not a delay.
lib.callback("example:panelStatus", player_id, function(result)
    print(("Client reported panel open: %s"):format(result and result.open))
end)
```
