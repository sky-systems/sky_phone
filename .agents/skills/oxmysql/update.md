# update

MySQL.update.await(sql, parameters) returns the affected-row count selected from the result
header; it does not return a header object. Zero is a valid number and is truthy in Lua.
Compare the expected count explicitly when a mutation must affect a row.

An optimistic conditional UPDATE can detect a stale transition only if the caller checks
the count and handles the failure. Interpret matched/changed rows using the actual driver,
connection flags and statement; do not assume every zero count is an SQL error.

[Update docs](https://overextended.dev/docs/oxmysql/Functions/update), [source](sources.md).

## Checked state transition

[Example setup](examples-setup.md). The predicate scopes the note to its owner and expected
old state; the caller still owns authorization. Choose one calling style.

```lua
local sql = "UPDATE example_notes SET state = ? WHERE id = ? AND owner = ? AND state = ?"
local parameters = { "archived", note_id, owner_key, "draft" }
local affected_rows = MySQL.update.await(sql, parameters)
if affected_rows ~= 1 then
    print("[notes] Expected one owned draft; no successful single-row transition")
    return
end
print("Owned note archived")
```

```lua
-- Callback alternative.
MySQL.update(sql, parameters, function(affected_rows)
    if affected_rows ~= 1 then
        print("[notes] Expected one owned draft; no successful single-row transition")
        return
    end
    print("Owned note archived")
end)
```

```js
const affectedRows = await MySQL.update(
    "UPDATE example_notes SET state = ? WHERE id = ? AND owner = ? AND state = ?",
    ["archived", noteId, ownerKey, "draft"]
);
if (affectedRows !== 1) console.log("[notes] No successful single-row transition");
else console.log("Owned note archived");
```
