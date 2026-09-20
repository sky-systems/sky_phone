# Review an ESX integration

Trace the actual adapter and provider before changing behavior. Keep this review scoped to the
requested feature; unrelated framework migrations and UI replacement are separate work.

- Verify installed-version arguments, result shape, execution side and override registration.
- Resolve current actor/session, target ownership and job/permission from the authoritative owner.
- Keep money/items/jobs on the server, validate bounds and apply each completed operation once.
- Distinguish provider false results, thrown errors and void writes; check the required post-state.
- Invalidate cached player/job/entity state at the owning lifecycle boundary; avoid stale snapshots.
- Test relevant denial/success, repeat request and disconnect/provider-failure paths when material.

When the applicable AGENTS.md requires the Sky bridge, preserve Sky.FW, PlayerCache, localization,
no documented-API existence guards, no one-line aliases and snake_case locals. Otherwise preserve
the resource's own adapters and style. Follow its build/deployment rules for actual resource changes.

Do not add obsolete lua54 declarations, generic give-item network handlers, or loop/caching
changes with unsupported performance claims. Report static/build checks separately from a live
ESX/FiveM reproduction. [Source/version verification](reference-links.md).

## Language and lifecycle examples

Restore useful mechanics through the specialized examples: [restart-safe state hooks](events-callbacks.md#client-lifecycle-events-and-payloads), [player/cache shape](core-concepts.md#playerdata-and-xplayer-shape), [bounded provider mutations](xplayer-methods.md#money-and-account-representation) and [typed commands](server-functions.md#commands-with-typed-arguments). The examples keep a local player reference for one operation, invalidate it across session changes and avoid generic give-item endpoints.

Use descriptive locals, document non-obvious units/return values, and match repository indentation/naming. `<const>` and `<close>` are Lua 5.4 features; compound assignments such as `+=` belong to the inspected Cfx Lua extension, not standard Lua. Do not restore an obsolete `lua54` opt-in or replace every table operation as a supposed optimization. Assigning `items[index] = nil` leaves a hole; `table.remove` shifts a sequence. The right operation depends on data shape.

The [Lua skill](../lua-basics/SKILL.md) retains scope/table/coroutine examples and the pinned language-source evidence. Read its applicable topic instead of repeating the language tutorial in every ESX reference.

Cache stable work only while its assumptions hold. A cached ped must follow ped changes; position must be refreshed when used, not frozen once at startup. A long-lived `while true` scheduler loop with an appropriate yield can be correct. Keep one owner, stop or idle work when inactive and prevent duplicate loops across repeated job events. Do not create a thread for each job notification or assert that 100/1000 ms suits every interaction. Use the existing input/event system where possible, and profile before claiming a native or cache change is faster.

## Database batching and ownership

Batch related independent writes where the actual persistence contract permits it. For direct oxmysql integrations, one bound multi-row insert preserves the original batching lesson:

```lua
MySQL.query.await("INSERT INTO example_log (actor_id, action) VALUES (?, ?), (?, ?)", {
    first_actor_id, first_action, second_actor_id, second_action
})
```

Use the resource's real table and database adapter; where AGENTS requires Sky, retain the corresponding `Sky` facade. This is not a generic transaction: authorization, business atomicity, finite batch size and query-result handling still belong to the service. See [SQL result contracts](../oxmysql/query.md) and [transactions](../oxmysql/transaction.md). Do not perform a player mutation later using the global `source` captured implicitly by an async SQL callback, and do not automatically punish every failed lookup as cheating.
