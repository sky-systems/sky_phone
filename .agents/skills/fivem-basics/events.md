# Events and asynchronous identity

Use a function for internal calls and `AddEventHandler(name, handler)` for same-side events.
`RegisterNetEvent(name, optionalHandler)` makes an event callable across the network;
registration does not authorize its caller. Use resource-prefixed names and preserve existing
contracts. Callbacks suit request/response flows; when AGENTS requires the Sky bridge, use its established `Sky.Cb`.

`TriggerServerEvent(name, ...)` sends client to server. Server `TriggerClientEvent(name,
playerId, ...)` targets a client; `-1` broadcasts. `TriggerEvent` stays on the current side.
Only send the required payload to the required recipients.

At a Lua network-event entry, capture `local src = source` before any yield or asynchronous
callback. The global source is valid only for the initial dispatch. If work outlives the
connection, recheck the stable identity/session before mutating a player or replying.
`Wait` and Await yield a scheduler coroutine; Await rejection can raise an error.

`GetInvokingResource()` identifies an invoking script resource when available. It is not a
player permission check. A nil result does not prove a trustworthy caller. For server
requests validate actor, bounded inputs, server-owned targets and permitted state transitions.
For client handlers intended only for server delivery, verify the runtime's event-origin
contract; origin filtering still cannot make a compromised client authoritative.

Keep local-only privileged operations off the network. Do not expose arbitrary item, amount,
price, SQL, model or target choices simply to make a helper reusable. Use an existing server
validation/serialization path and consume rewards once before a yielding mutation.

## Registration and notification examples

A same-side notification needs no network registration:

```lua
AddEventHandler("example_resource:cacheUpdated", function(revision)
    print(("[example_resource] Cache revision is %s"):format(revision))
end)

TriggerEvent("example_resource:cacheUpdated", 3)
```

For a server notification received by a client, register the client handler as networked:

```lua
-- client.lua
RegisterNetEvent("example_resource:catalogUpdated", function(revision)
    print(("[example_resource] Catalog revision is %s"):format(revision))
end)
```

```lua
-- In the server-owned update path, after the catalog changed:
TriggerClientEvent("example_resource:catalogUpdated", -1, 3)
```

The two-step spelling is also valid: `RegisterNetEvent("name")` followed by
`AddEventHandler("name", handler)`. Use exactly the same name. These examples only log
notifications; they do not authorize a grant or establish that a client is trustworthy.
For a client request, `TriggerServerEvent("example_resource:requestAction", action_id)`
sends arguments after the event name; the server obtains the actor from `source`, not a
submitted player ID. Put the actual validation at that existing server owner.

Resource prefixes prevent unrelated handlers from colliding. A `client`/`server` segment
can clarify an established naming scheme, but preserve public names. Name factual
notifications after what changed; name requests after the requested action. Do not force
every request into past tense. A notification may have several listeners; use a direct
function for internal single-consumer work and the existing callback bridge for a reply.

[Registration, dispatch, source lifetime and security evidence](reference-links.md).
