# Exports

An export is a contract between resources on the same execution side. Prefer runtime
registration with `exports("name", implementation)` where the resource uses it; the argument
is the exported function name, not the resource name. Call it with
`exports["resource_name"]:name(arguments)`. Manifest `export`/`server_export` declarations
instead expose named global functions on the corresponding side.

Read the provider's manifest, export registration and implementation before using it. Confirm
arguments, return shape, whether it yields, and error behavior. Do not assume an export also
exists on the other side or that dependency ordering means asynchronous provider data is ready.

Keep payloads purposeful. Cross-resource serialization differs from ordinary Lua references;
there is no universal rule that many tiny export calls beat one batch. Measure the actual
call path before changing granularity. Do not retain stale function references across provider
restarts; follow the existing resource lifecycle.

When AGENTS requires the Sky bridge, use its documented facades directly without wrapper aliases.

## Provider and consumer example

For a resource-owned, server-side in-memory counter, runtime registration keeps the
implementation local to its provider. This demonstrates arguments, state and a return
value; it is not a money/reward endpoint and does not add a network event:

```lua
-- example_counter/server.lua
local total = 0

exports("AddToCount", function(amount)
    assert(type(amount) == "number" and amount == amount
        and amount > 0 and amount <= 100 and amount % 1 == 0,
        "AddToCount expects an integer from 1 to 100")
    total = total + amount
    return total
end)
```

```lua
-- Another resource's server script, with the provider dependency declared:
local new_total = exports["example_counter"]:AddToCount(2)
print(("[example_consumer] Counter is %s"):format(new_total))
```

For an existing manifest-declared export, the corresponding declaration is
`server_export "AddToCount"` and the provider must define a global
`function AddToCount(amount) ... end` containing the implementation. A local function
with that name is not exposed by manifest metadata. Use `export` on the client side.
Choose one registration form for a contract; do not add a duplicate alias merely to
demonstrate both. The getter/setter pattern uses the same provider-owned-state boundary.

[Manifest export docs](https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/#export)
and [scheduler export implementation](reference-links.md) provide the source trail.
