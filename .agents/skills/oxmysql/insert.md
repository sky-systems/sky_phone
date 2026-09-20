# insert

MySQL.insert.await(sql, parameters) selects insertId from the result header. The callback form
delivers that value to the callback. It does not return a newly inserted row.

Do not treat every truthy number as proof of a new record: Lua zero is truthy, and SQL form,
keys and duplicate handling determine the meaning of an insert ID. For an operation that
requires a newly created record, verify the actual statement/result contract. SQL/await errors
may reject and raise; they do not universally return nil.

[Insert docs](https://overextended.dev/docs/oxmysql/Functions/insert), [source](sources.md).

## Examples

[Example setup](examples-setup.md). The forms below are alternatives, not three inserts
to run for one request. `owner_key` and `note_text` come from the authorized server operation.

```lua
local sql = "INSERT INTO example_notes (owner, note, state) VALUES (?, ?, ?)"
local insert_id = MySQL.insert.await(sql, { owner_key, note_text, "draft" })
print(("Inserted note id: %s"):format(insert_id))

-- Callback alternative.
MySQL.insert(sql, { owner_key, note_text, "draft" }, function(result)
    print(("Inserted note id: %s"):format(result))
end)
```

```js
const insertId = await MySQL.insert(
    "INSERT INTO example_notes (owner, note, state) VALUES (?, ?, ?)",
    [ownerKey, noteText, "draft"]
);
console.log("Inserted note id:", insertId);
```

## Bounded multi-row insert

When the rows belong to the same authorized operation and can share one statement, bind
each tuple rather than issuing one provider call per row:

```lua
local insert_id = MySQL.insert.await([[
    INSERT INTO example_notes (owner, note, state) VALUES (?, ?, ?), (?, ?, ?)
]], {
    owner_key, first_note, "draft",
    owner_key, second_note, "draft"
})
print(("Multi-row statement insertId: %s"):format(insert_id))
```

This is one SQL statement, unlike multiple prepare parameter sets. Bound the batch size
and preserve required ordering/constraints. The helper still returns one header `insertId`,
not a list of every created ID; do not infer all IDs by arithmetic or treat independent
provider side effects as automatically part of this statement.
