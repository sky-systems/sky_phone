# single

MySQL.single.await(sql, parameters) returns the first row or nil when no row matches.
Choose required columns; use a unique predicate or deterministic ordering when the specific
row matters. Do not assume the helper makes an ambiguous query unique.

Handle an expected missing row explicitly. Await errors can raise and are a different result
from no matching record. The callback form receives the row/nil asynchronously.

[Single docs](https://overextended.dev/docs/oxmysql/Functions/single), [source](sources.md).

## Examples

[Imports, server-owned variables and illustrative schema](examples-setup.md) apply.

```lua
local sql = "SELECT id, note FROM example_notes WHERE id = ? AND owner = ? LIMIT 1"
local row = MySQL.single.await(sql, { note_id, owner_key })
if row then
    print(("Found note: %s"):format(row.id))
else
    print("Owned note not found")
end

-- Callback alternative.
MySQL.single(sql, { note_id, owner_key }, function(result)
    if result then
        print(("Found note: %s"):format(result.id))
    else
        print("Owned note not found")
    end
end)
```

```js
const row = await MySQL.single(
    "SELECT id, note FROM example_notes WHERE id = ? AND owner = ? LIMIT 1",
    [noteId, ownerKey]
);
if (row == null) console.log("Owned note not found");
else console.log("Found note:", row.id);
```
