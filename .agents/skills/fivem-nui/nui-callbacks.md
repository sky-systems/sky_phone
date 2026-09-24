# NUI Callbacks

Use the resource's established browser/client callback contract. A callback routes browser data to a client script; it does not itself authorize a server mutation.

## Browser request

The resource name API is injected by FiveM. Do not redefine it from the hostname or hardcode the name:

```js
// Inside the existing async UI action:
const response = await fetch(`https://${GetParentResourceName()}/getItemInfo`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify({ itemId }),
});
if (!response.ok) {
    throw new Error(`getItemInfo failed: HTTP ${response.status}`);
}
const result = await response.json();
```

Handle transport and application errors at the owning UI action, with localized user feedback. Use a separate explicit mock in desktop previews. Do not add production hostname fallbacks or blindly retry POSTs. A failed/aborted response does not prove that a mutation did not occur.

## Client registration

Current official docs use `RegisterNuiCallback` for a function-reference registration. Lua's legacy `RegisterNUICallback` also exists and routes through `__cfx_nui:` events. Preserve the existing resource contract unless a change is needed; these are different implementations, so a bulk spelling replacement is unnecessary.

```lua
RegisterNuiCallback("getItemInfo", function(data, cb)
    if type(data) ~= "table" or type(data.itemId) ~= "string" then
        print("[nui] getItemInfo rejected: payload must contain a string itemId")
        cb({ error = "invalid_item_id" })
        return
    end

    local item = item_cache[data.itemId]
    if not item then
        print(("[nui] getItemInfo rejected: unknown itemId '%s'"):format(data.itemId))
        cb({ error = "item_not_found" })
        return
    end

    cb(item)
end)
```

`item_cache` represents the resource's existing JSON-serializable lookup. This example provides no server authorization. Return error codes for UI localization; debug logs stay English. Complete the callback exactly once on every reachable path; otherwise the request can stall/fail. Do not rely on a universal timeout duration or runtime auto-completion.

For paired Lua and typed browser code with structured results, read [callback response shapes and errors](examples.md#callback-response-shapes-and-errors). The URL route must exactly match the registration name; request JSON is decoded into `data`, and the callback value is serialized into the HTTP response. Do not accidentally invoke both a callback and a separate success path for one request.

## Server mutations

Client checks improve interaction feedback; the server must independently validate identity, permissions/duty, distance, ownership, allowed state transitions, amounts and rate as relevant. Prices and other authoritative values come from the server.

An immediate callback after `TriggerServerEvent` only acknowledges dispatch. Do not render it as a successful purchase/payment. Reuse the repository's actual request/response bridge when the UI needs the final server result, or explicitly model pending and completed outcomes with correlation. No invented callback API or parallel transport is needed.

An error handler may translate a known boundary failure into one callback response, but should not hide root causes behind broad catches, fallback values or retries. Retrying a mutation requires a documented idempotency contract.

## Verification

Verify route spelling, HTTPS parent-resource URL, JSON shape, all response branches and final server result handling. For changed asynchronous behavior, check reload/close and stale responses. Verify strict-callback mode against the target edition/build and intended cross-resource use; it does not replace server authorization.

Sources: [official callback contract](https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/), [server security](https://docs.fivem.net/docs/developers/server-security/), and [source/binding map](reference-links.md).
