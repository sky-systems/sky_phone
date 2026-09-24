# Client/server boundaries

Client code handles local presentation, input and client gameplay APIs. Server code owns
permissions, persistence and authoritative mutations. The server has CFX and OneSync world
APIs; it is incorrect to say it has no world access. A familiar native name may have different
client/server signatures. Verify the exact API set and binding before use.

| Code | Execution and typical responsibility |
| --- | --- |
| Client | Each connected game client has its own instance: input, local visuals and UI |
| Server | The server resource instance handles shared authoritative state and persistence |
| Shared | Each side executes its own copy: safe common constants/configuration and pure helpers |

Shared code executes separately on each side; it does not share in-memory tables across the
network. Do not place secrets there. Use [events](events.md) for remote requests and
[exports](exports.md) for cross-resource calls on the same side.

For example, `Config.DisplayDistance = 20` in a shared configuration makes that setting
available on both sides; assigning `Config.DisplayDistance = 30` on the client does not
update the server's table. Keep calls to side-specific APIs in the matching script, or
deliberately select the correct execution-side branch using the verified runtime contract.

State bags are replicated state, not permission grants. Check ownership and replication
direction: client-owned bags are untrusted unless the actual deployment enforces server-only
writes. Nested table mutation is not a replicated set; use direct assignments/granular keys.
Avoid repeated deserialization in hot paths. Choose state bags or events by data lifetime,
recipients and measured cost; neither is universally faster.

## Replicated presentation state

```lua
-- server.lua: entity is an existing server entity handle validated by the owning operation.
local state = Entity(entity).state
state:set("example:displayPhase", "ready", true)
local phase = state["example:displayPhase"]
print(("Server display phase: %s"):format(phase))
```

The explicit third argument requests replication; `false` keeps that set local. Ordinary
assignment replicates by default on the server and stays local by default on the client.
The Lua `state:set` wrapper provides no delivery receipt. On a receiving client, read the same
key through its local entity handle once that entity and state are available; do not transmit a
server handle as though it were a client handle. A read may be nil before a value exists.

Keep the authoritative workflow record separately under the server owner's control. The key
above is presentation state, not evidence that a job completed or a reward was claimed: an
owning client may write entity state unless the actual deployment restricts those writes.

[State bag docs](https://docs.fivem.net/docs/scripting-manual/networking/state-bags/),
[OneSync docs](https://docs.fivem.net/docs/scripting-reference/onesync/) and their
[pinned implementation paths](reference-links.md) describe the boundaries.
