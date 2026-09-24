# prepare

MySQL.prepare uses prepared execution and can accept repeated parameter sets for one query.
Only ? value placeholders are supported; ?? column placeholders and named placeholders fail.
Keep identifiers fixed or choose them from an allowlist.

SELECT result shape varies with the number of rows/columns; it may be a scalar, row or rows.
Do not replace query/single/scalar blindly. At the pinned `typeCastExecute` implementation,
SQL `DATE`/`NEWDATE`, `DATETIME`/`DATETIME2` and `TIMESTAMP`/`TIMESTAMP2` fields become epoch
milliseconds or null; `TIME` falls through to the driver. Unlike the query converter, it does
not additionally map one-digit TINY / one-byte BIT values 0 and 1 to booleans. Verify the
consumed shape, driver types and timezone/null handling at the installed revision; do not
assume a universal FiveM date-string result.

Prepared execution may help repeated workloads; do not claim a gain without measuring that
workload. It does not make multiple parameter sets a business transaction.

[Prepare docs](https://overextended.dev/docs/oxmysql/Functions/prepare), [source](sources.md).

## Examples with an explicit result shape

[Example setup](examples-setup.md). Selecting two columns and at most one row yields a
row-or-nil on the inspected prepare path; adding more rows/columns changes that contract.

```lua
local sql = "SELECT id, note FROM example_notes WHERE id = ? AND owner = ? LIMIT 1"
local row = MySQL.prepare.await(sql, { note_id, owner_key })
if row then print(("Found note: %s"):format(row.id)) end

-- Callback alternative.
MySQL.prepare(sql, { note_id, owner_key }, function(result)
    if result then print(("Found note: %s"):format(result.id)) end
end)
```

```js
const row = await MySQL.prepare(
    "SELECT id, note FROM example_notes WHERE id = ? AND owner = ? LIMIT 1", [noteId, ownerKey]
);
if (row != null) console.log("Found note:", row.id);
```

## Upsert and repeated parameter sets

An actual unique key on `(owner, preference_key)` determines the conflict. This avoids a
separate existence read/race and does not delete/reinsert the row as `REPLACE` can do.

```lua
local sql = [[
    INSERT INTO example_preferences (owner, preference_key, value) VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE value = ?
]]
local result = MySQL.prepare.await(sql, { owner_key, "theme", "dark", "dark" })
print(("Preference statement completed: %s"):format(result ~= nil))

-- Separate illustration: two parameter sets for the same prepared statement.
local results = MySQL.prepare.await(sql, {
    { owner_key, "theme", "dark", "dark" },
    { owner_key, "compact", "1", "1" }
})
print(("Prepared parameter sets completed: %s"):format(results ~= nil))
```

These statements demonstrate syntax, not a multi-setting atomic save. For all-or-nothing
changes use a verified transaction design; do not infer insert versus update from Lua truthiness.
