# Bound values and identifiers

Bind untrusted values with positional ? parameters in SQL order; do not concatenate them.
Named @parameters are a legacy query compatibility feature, not a new-code default.
Parameters protect SQL syntax, not application permissions or valid business quantities.

Prepared execution accepts ? value placeholders only: ?? identifier placeholders and named
placeholders are unsupported. SQL identifiers cannot be bound as values. Keep table/column
names fixed or select from a server-owned allowlist; never interpolate arbitrary client names.

Distinguish SQL NULL, omitted parameters and Lua nil holes. Verify the wrapper's parameter
serialization rather than silently shifting positional values. Use [prepare](prepare.md) only
when its result/execute contract matches the task.

[Placeholder docs](https://overextended.dev/docs/oxmysql/placeholders), [source](sources.md).

## Ordered values and fixed identifiers

```lua
local note = MySQL.scalar.await(
    "SELECT note FROM example_notes WHERE owner = ? AND id = ? LIMIT 1",
    { owner_key, note_id }
)
```

The first value binds the first `?`. Quoting/interpolating a supplied owner into SQL would
discard that separation. For optional ordering, choose complete fixed fragments:

```lua
local allowed_order = { newest = "id DESC", oldest = "id ASC" }
local order_sql = allowed_order[requested_order]
if not order_sql then
    print("[notes] Rejected unknown sort order")
    return
end
local rows = MySQL.query.await(
    "SELECT id, note FROM example_notes WHERE owner = ? ORDER BY " .. order_sql .. " LIMIT 20",
    { owner_key }
)
```

Only server-owned SQL fragments are concatenated. `ORDER BY ?` binds a value, not a column
identifier, and `??` is not accepted by prepare/rawExecute. See [example setup](examples-setup.md).
